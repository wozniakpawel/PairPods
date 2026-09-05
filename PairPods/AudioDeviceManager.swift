//
//  AudioDeviceManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import CoreAudio
import Foundation
import SwiftUI

// MARK: - Audio Device Notifications

extension Notification.Name {
    static let audioDeviceConfigurationChanged = Notification.Name("audioDeviceConfigurationChanged")
    static let audioDeviceVolumeChanged = Notification.Name("audioDeviceVolumeChanged")
}

extension NotificationCenter {
    func postDeviceVolumeChanged(deviceID: AudioDeviceID, volume: Float) {
        post(
            name: .audioDeviceVolumeChanged,
            object: nil,
            userInfo: ["deviceID": deviceID, "volume": volume]
        )
    }

    func postDeviceConfigurationChanged() {
        post(name: .audioDeviceConfigurationChanged, object: nil)
    }
}

@MainActor
final class AudioDeviceManager: ObservableObject {
    private let multiOutputDeviceUID = "PairPodsOutputDevice"
    private static let excludedDeviceUIDsKey = "excludedDeviceUIDs"
    private static let deviceOrderKey = "PairPods.DeviceOrder"
    private var originalOutputDeviceID: AudioDeviceID?
    private var sharedDevices: [AudioDevice]?
    private var propertyListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerDeviceIDs: [AudioDeviceID] = []
    private var initTask: Task<Void, Never>?
    private var volumeListenerTask: Task<Void, Never>?
    private let monitorHardware: Bool
    private let shouldShowAlerts: Bool
    let audioSystem: AudioSystemQuerying & AudioSystemCommanding
    /// Injected for the same reason as userDefaults: NotificationCenter.default is
    /// process-wide, so a notification posted by one parallel test suite reaches every
    /// other suite's manager.
    let notificationCenter: NotificationCenter
    /// Injected so parallel tests do not share persisted state. Exclusions and device
    /// order both live here, and a test that wrote either could drop another test's
    /// selection below two devices, which is what made the reconnect tests flaky.
    private let userDefaults: UserDefaults
    /// Rate changes currently applied to hardware, so they can be undone on failure or
    /// when sharing stops. Nothing else in the app writes device nominal rates.
    private var appliedSampleRateChanges: [SampleRateChange] = []

    /// Outcome of the last alignment attempt, exposed so callers and tests can tell a
    /// clean setup from one running with mismatched sub-device rates.
    private(set) var lastAlignment: SampleRateAlignment?

    @Published private(set) var compatibleDevices: [AudioDevice] = []
    @Published var excludedDeviceUIDs: Set<String> = []

    var sharedDeviceUIDs: [String]? {
        sharedDevices?.map(\.uid)
    }

    var selectedDevices: [AudioDevice] {
        compatibleDevices.filter { !excludedDeviceUIDs.contains($0.uid) }
    }

    convenience init(shouldShowAlerts: Bool = true) {
        self.init(audioSystem: CoreAudioSystem(), shouldShowAlerts: shouldShowAlerts)
    }

    init(audioSystem: AudioSystemQuerying & AudioSystemCommanding,
         shouldShowAlerts: Bool = true,
         monitorHardware: Bool = true,
         userDefaults: UserDefaults = .standard,
         notificationCenter: NotificationCenter = .default)
    {
        self.audioSystem = audioSystem
        self.shouldShowAlerts = shouldShowAlerts
        self.monitorHardware = monitorHardware
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        excludedDeviceUIDs = Self.loadExcludedDeviceUIDs(from: userDefaults)
        logDebug("Initializing AudioDeviceManager")
        setupAudioDeviceMonitoring()
        initTask = Task {
            await removeMultiOutputDevice()
            await initializeDevices()
        }
    }

    // MARK: - Device Exclusion

    func setDeviceExcluded(_ uid: String, excluded: Bool) {
        if excluded {
            excludedDeviceUIDs.insert(uid)
        } else {
            excludedDeviceUIDs.remove(uid)
        }
        saveExcludedDeviceUIDs()
    }

    func isDeviceSelected(_ uid: String) -> Bool {
        !excludedDeviceUIDs.contains(uid)
    }

    private static func loadExcludedDeviceUIDs(from userDefaults: UserDefaults) -> Set<String> {
        let array = userDefaults.stringArray(forKey: excludedDeviceUIDsKey) ?? []
        return Set(array)
    }

    private func saveExcludedDeviceUIDs() {
        userDefaults.set(Array(excludedDeviceUIDs), forKey: Self.excludedDeviceUIDsKey)
    }

    // MARK: - Device Order

    func saveDeviceOrder(_ uids: [String]) {
        userDefaults.set(uids, forKey: Self.deviceOrderKey)
        objectWillChange.send()
        logDebug("Saved device order: \(uids)")
    }

    func loadDeviceOrder() -> [String] {
        userDefaults.stringArray(forKey: Self.deviceOrderKey) ?? []
    }

    /// Returns the UID of the device that would be master clock for the given devices,
    /// using the same logic as `selectDevicesForSharing`.
    func masterDeviceUID(for devices: [AudioDevice]) -> String? {
        let userOrder = loadDeviceOrder()
        if !userOrder.isEmpty {
            // User order: first device in saved order that's in the list
            return userOrder.first { uid in devices.contains { $0.uid == uid } }
        }
        // Fallback: same sample-rate logic as selectDevicesForSharing
        return selectDevicesForSharing(devices).first?.uid
    }

    // MARK: - Public Methods

    func setupMultiOutputDevice() async throws {
        logInfo("Starting setup of multi-output device")
        let (defaultDevice, originalID) = await audioSystem.fetchDefaultOutputDevice()
        originalOutputDeviceID = originalID
        await removeMultiOutputDevice()

        let devices = try await audioSystem.fetchAllAudioDevices()
        logDevices(allDevices: devices, defaultDevice: defaultDevice)

        let compatible = devices.filter(\.isCompatibleOutputDevice)
        let selected = compatible.filter { !excludedDeviceUIDs.contains($0.uid) }
        try validateSelectedDevices(selected)

        let sorted = selectDevicesForSharing(selected)
        sharedDevices = sorted

        let alignment = await alignSampleRates(sorted)
        lastAlignment = alignment
        appliedSampleRateChanges = alignment.appliedChanges
        if case let .degraded(reason) = alignment {
            // Sharing still proceeds: refusing outright would take a pairing that works
            // today, imperfectly, and make it not work at all. But this is a named,
            // observable state rather than a silent one.
            logWarning("Proceeding in degraded mode, sub-device rates differ (\(reason))")
        }

        do {
            let deviceID = try await createAggregate(masterUID: sorted[0].uid, subDeviceUIDs: sorted.map(\.uid))
            try await audioSystem.setDefaultOutputDevice(deviceID: deviceID)
        } catch {
            // Anything written to hardware before this point has to come back off it.
            await restoreSampleRates(appliedSampleRateChanges)
            appliedSampleRateChanges = []
            throw error
        }
        logInfo("Multi-output device setup completed successfully")
    }

    /// Builds the aggregate, preferring a standalone clock device over a Bluetooth master.
    ///
    /// Every advertised clock is tried before giving up: the first one may be stale or
    /// incompatible with the rate the aggregate needs, and falling straight back to a
    /// Bluetooth master would reintroduce the very problem this change removes.
    private func createAggregate(masterUID: String, subDeviceUIDs: [String]) async throws -> AudioDeviceID {
        for clockUID in await audioSystem.fetchClockDeviceUIDs() {
            do {
                return try await audioSystem.createAggregateDevice(
                    name: "PairPods Output Device",
                    uid: multiOutputDeviceUID,
                    masterUID: masterUID,
                    subDeviceUIDs: subDeviceUIDs,
                    clockUID: clockUID
                )
            } catch {
                logWarning("Clock device \(clockUID) rejected for the aggregate, trying the next candidate")
            }
        }

        logInfo("No usable clock device, falling back to a master sub-device")
        return try await audioSystem.createAggregateDevice(
            name: "PairPods Output Device",
            uid: multiOutputDeviceUID,
            masterUID: masterUID,
            subDeviceUIDs: subDeviceUIDs,
            clockUID: nil
        )
    }

    func restoreOutputDevice() async {
        logInfo("Restoring output device to previous state")
        do {
            let devices = try await audioSystem.fetchAllAudioDevices()
            var restored = false

            if let shared = sharedDevices {
                for sharedDevice in shared {
                    if let current = devices.first(where: { $0.uid == sharedDevice.uid }) {
                        try await audioSystem.setDefaultOutputDevice(deviceID: current.id)
                        logInfo("Restored to device: \(sharedDevice.name)")
                        restored = true
                        break
                    }
                }
            }

            if !restored {
                try await restoreToBuiltInSpeakers()
                logInfo("Restored to built-in speakers")
            }
        } catch {
            let appError = AppError.systemError(error)
            logError("Failed to restore output device", error: appError)
        }

        await restoreSampleRates(appliedSampleRateChanges)
        appliedSampleRateChanges = []
        originalOutputDeviceID = nil
        sharedDevices = nil
    }

    func removeMultiOutputDevice() async {
        logInfo("Attempting to remove existing multi-output device")
        if let deviceID = await audioSystem.fetchDeviceID(deviceUID: multiOutputDeviceUID) {
            do {
                try await audioSystem.destroyAggregateDevice(deviceID: deviceID)
                logInfo("Successfully removed multi-output device")
            } catch {
                let appError = AppError.systemError(error)
                logError("Failed to remove multi-output device", error: appError)
            }
        } else {
            logDebug("No existing multi-output device found")
        }
    }

    func isMultiOutputDeviceActive() async -> Bool {
        let (defaultDevice, _) = await audioSystem.fetchDefaultOutputDevice()
        return defaultDevice?.uid == multiOutputDeviceUID
    }

    func isMultiOutputDeviceValid() async -> Bool {
        guard let shared = sharedDevices, !shared.isEmpty else {
            return false
        }
        let devices: [AudioDevice]
        do {
            devices = try await audioSystem.fetchAllAudioDevices()
        } catch {
            logWarning("Failed to fetch audio devices for validation: \(error.localizedDescription)")
            devices = []
        }
        return shared.allSatisfy { sharedDevice in
            devices.contains(where: { $0.uid == sharedDevice.uid })
        }
    }

    /// Method to refresh the list of compatible devices
    func refreshCompatibleDevices() async {
        do {
            let devices = try await audioSystem.fetchAllAudioDevices()
            compatibleDevices = devices.filter(\.isCompatibleOutputDevice)
            logInfo("Found \(compatibleDevices.count) compatible audio devices")
        } catch {
            logError("Failed to refresh compatible devices", error: .systemError(error))
        }
    }

    /// Get volume for a specific device
    func getDeviceVolume(deviceID: AudioDeviceID) -> Float {
        if let device = compatibleDevices.first(where: { $0.id == deviceID }),
           let volume = device.getVolume()
        {
            return volume
        }
        return 0.0
    }

    /// Set volume for a specific device
    func setDeviceVolume(deviceID: AudioDeviceID, volume: Float) async {
        guard let device = compatibleDevices.first(where: { $0.id == deviceID }) else {
            logError("Failed to set volume for device", error: .operationError("Device with ID \(deviceID) not found"))
            return
        }

        logDebug("Setting volume for device: \(device.name) (ID: \(deviceID)) to \(volume)")

        do {
            try device.setVolume(volume)
            logInfo("Set volume for device \(device.name) to \(volume)")
        } catch {
            let appError = error as? AppError ?? AppError.systemError(error)
            logError("Failed to set volume for device \(device.name)", error: appError)
        }
    }

    /// Initialize devices on startup
    func initializeDevices() async {
        await refreshCompatibleDevices()
        // Setup listener for device property changes
        setupVolumeChangeListeners()
    }

    // MARK: - Internal Methods (exposed for testing)

    func validateSelectedDevices(_ devices: [AudioDevice]) throws {
        logInfo("Found \(devices.count) selected devices")
        guard devices.count >= 2 else {
            let error = AppError.operationError("Not enough compatible devices selected")
            logError("Device validation failed", error: error)
            showBluetoothSettingsAlert()
            throw error
        }
    }

    // MARK: - Private Methods

    private func setupAudioDeviceMonitoring() {
        guard monitorHardware else { return }
        logDebug("Setting up audio device monitoring")
        propertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                await self?.handleAudioDeviceChange()
            }
        }

        guard let propertyListenerBlock else { return }
        let status = addPropertyListener(propertyListenerBlock)
        if status != noErr {
            let error = AppError.operationError("Status code: \(status)")
            logError("Failed to add audio device change listener", error: error)
        }
    }

    private func handleAudioDeviceChange() async {
        // Reinitialize devices when configuration changes
        await initializeDevices()

        let isActive = await isMultiOutputDeviceActive()
        let isValid = await isMultiOutputDeviceValid()

        if isActive, !isValid {
            logWarning("Multi-output device configuration is no longer valid")
            notificationCenter.postDeviceConfigurationChanged()
        }
    }

    private func restoreToBuiltInSpeakers() async throws {
        logInfo("Attempting to restore to built-in speakers")
        let devices = try await audioSystem.fetchAllAudioDevices()
        if let builtInSpeakers = devices.first(where: { $0.transportType == kAudioDeviceTransportTypeBuiltIn && $0.isOutputDevice }) {
            try await audioSystem.setDefaultOutputDevice(deviceID: builtInSpeakers.id)
            logInfo("Successfully restored to built-in speakers")
        } else {
            throw AppError.operationError("No built-in speakers found")
        }
    }

    private func logDevices(allDevices: [AudioDevice], defaultDevice: AudioDevice?) {
        logDebug("Found \(allDevices.count) audio devices")
        for device in allDevices {
            logDebug(device.description)
        }

        if let defaultDevice {
            logInfo("Current default output device: \(defaultDevice.name)")
        }
    }

    private func showBluetoothSettingsAlert() {
        guard shouldShowAlerts else { return }

        let alert = NSAlert()
        alert.messageText = "Not enough devices connected"
        alert.informativeText = "Please make sure at least two Bluetooth audio devices are selected and connected to your Mac."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Open Bluetooth Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func addPropertyListener(_ listener: @escaping AudioObjectPropertyListenerBlock) -> OSStatus {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var address = systemObject.getPropertyAddress(selector: kAudioHardwarePropertyDevices)
        return AudioObjectAddPropertyListenerBlock(
            systemObject,
            &address,
            DispatchQueue.main,
            listener
        )
    }

    private func removePropertyListener() {
        guard let propertyListenerBlock else { return }
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var address = systemObject.getPropertyAddress(selector: kAudioHardwarePropertyDevices)
        let status = AudioObjectRemovePropertyListenerBlock(
            systemObject,
            &address,
            DispatchQueue.main,
            propertyListenerBlock
        )
        if status != noErr {
            logError("Failed to remove property listener", error: .operationError("Status: \(status)"))
        }
    }

    /// Handle a volume change event for a specific device
    private func handleVolumeChange(deviceID: AudioDeviceID, propertyAddress: AudioObjectPropertyAddress) {
        logInfo("Volume change detected for device ID: \(deviceID)")
        logDebug("Property address: selector=\(propertyAddress.mSelector), scope=\(propertyAddress.mScope), element=\(propertyAddress.mElement)")

        guard let device = compatibleDevices.first(where: { $0.id == deviceID }) else {
            logWarning("Device with ID \(deviceID) not found in compatible devices")
            return
        }

        if let newVolume = device.getVolume() {
            logInfo("Volume for \(device.name): \(newVolume)")
            notificationCenter.postDeviceVolumeChanged(deviceID: deviceID, volume: newVolume)
        } else {
            logWarning("Failed to get volume for device: \(device.name)")
        }
    }

    /// Remove previously registered volume/mute listeners and add them for the given devices.
    private func registerVolumeListeners(for devices: [AudioDevice], listener: @escaping AudioObjectPropertyListenerBlock) {
        // Remove old listeners first
        for oldDeviceID in volumeListenerDeviceIDs {
            oldDeviceID.removeVolumePropertyListener(listener: listener)
            oldDeviceID.removeMutePropertyListener(listener: listener)
        }
        volumeListenerDeviceIDs.removeAll()

        logDebug("Setting up volume listeners for \(devices.count) compatible devices")

        for device in devices {
            logDebug("Setting up volume listener for device: \(device.name) (ID: \(device.id))")

            if device.id.addVolumePropertyListener(listener: listener) {
                logDebug("Successfully added volume listener for device: \(device.name)")
            } else {
                logWarning("Device \(device.name) does not support volume control")
            }

            if device.id.addMutePropertyListener(listener: listener) {
                logDebug("Successfully added mute listener for device: \(device.name)")
            }

            volumeListenerDeviceIDs.append(device.id)
        }
    }

    /// Setup listeners for volume changes on all compatible devices
    private func setupVolumeChangeListeners() {
        guard monitorHardware else { return }
        logDebug("Setting up volume change listeners")

        if volumeListenerBlock == nil {
            volumeListenerBlock = { [weak self] inObjectID, propertyAddress in
                let address = propertyAddress.pointee
                Task { @MainActor in
                    self?.handleVolumeChange(deviceID: inObjectID, propertyAddress: address)
                }
            }
        }

        guard let volumeListenerBlock else { return }

        volumeListenerTask?.cancel()
        volumeListenerTask = Task {
            do {
                let devices = try await audioSystem.fetchAllAudioDevices()
                let compatible = devices.filter(\.isCompatibleOutputDevice)
                registerVolumeListeners(for: compatible, listener: volumeListenerBlock)
            } catch {
                logError("Failed to set up volume listeners", error: .systemError(error))
            }
        }
    }
}

// MARK: - Cleanup

extension AudioDeviceManager {
    func cleanup() async {
        logInfo("Cleaning up AudioDeviceManager")
        initTask?.cancel()
        volumeListenerTask?.cancel()
        await removeMultiOutputDevice()
        await restoreSampleRates(appliedSampleRateChanges)
        appliedSampleRateChanges = []
        removePropertyListener()
    }

    /// Synchronous cleanup for use during app termination where async work
    /// cannot be guaranteed to complete before the process exits.
    nonisolated func cleanupSync() {
        logInfo("Performing synchronous cleanup of multi-output device")
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var propertyAddress = systemObject.getPropertyAddress(selector: kAudioHardwarePropertyDevices)
        var propertySize: UInt32 = 0

        guard AudioObjectGetPropertyDataSize(systemObject, &propertyAddress, 0, nil, &propertySize) == noErr else {
            return
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(systemObject, &propertyAddress, 0, nil, &propertySize, &deviceIDs) == noErr else {
            return
        }

        for deviceID in deviceIDs {
            guard let uid = deviceID.getStringProperty(selector: kAudioDevicePropertyDeviceUID),
                  uid == multiOutputDeviceUID
            else { continue }
            AudioHardwareDestroyAggregateDevice(deviceID)
            logInfo("Synchronously destroyed aggregate device \(deviceID)")
            break
        }
    }
}
