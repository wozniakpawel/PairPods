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
    private var originalOutputDeviceID: AudioDeviceID?
    private var sharedDevices: [AudioDevice]?
    private var propertyListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerDeviceIDs: [AudioDeviceID] = []
    private var initTask: Task<Void, Never>?
    private var volumeListenerTask: Task<Void, Never>?
    private let shouldShowAlerts: Bool
    private let audioSystem: AudioSystemQuerying & AudioSystemCommanding

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

    init(audioSystem: AudioSystemQuerying & AudioSystemCommanding, shouldShowAlerts: Bool = true) {
        self.audioSystem = audioSystem
        self.shouldShowAlerts = shouldShowAlerts
        excludedDeviceUIDs = Self.loadExcludedDeviceUIDs()
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

    private static func loadExcludedDeviceUIDs() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: excludedDeviceUIDsKey) ?? []
        return Set(array)
    }

    private func saveExcludedDeviceUIDs() {
        UserDefaults.standard.set(Array(excludedDeviceUIDs), forKey: Self.excludedDeviceUIDsKey)
    }

    // MARK: - Public Methods

    func cleanup() async {
        logInfo("Cleaning up AudioDeviceManager")
        initTask?.cancel()
        volumeListenerTask?.cancel()
        await removeMultiOutputDevice()
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

        let masterDevice = sorted[0]

        let deviceID = try await audioSystem.createAggregateDevice(
            name: "PairPods Output Device",
            uid: multiOutputDeviceUID,
            masterUID: masterDevice.uid,
            subDeviceUIDs: sorted.map(\.uid)
        )
        try await audioSystem.setDefaultOutputDevice(deviceID: deviceID)
        logInfo("Multi-output device setup completed successfully")
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
    func getDeviceVolume(deviceID: AudioDeviceID) async -> Float {
        if let device = compatibleDevices.first(where: { $0.id == deviceID }),
           let volume = await device.getVolume()
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

    func selectDevicesForSharing(_ devices: [AudioDevice]) -> [AudioDevice] {
        // Find the most common sample rate among the devices
        var rateCount: [Double: Int] = [:]
        for device in devices {
            rateCount[device.sampleRate, default: 0] += 1
        }
        let maxCount = rateCount.values.max() ?? 0
        let hasClearMajority = rateCount.values.count(where: { $0 == maxCount }) == 1
        let majorityRate = hasClearMajority ? rateCount.first(where: { $0.value == maxCount })?.key : nil

        // Sort: when a clear majority exists, those devices go first; otherwise sort descending by rate
        let sorted = devices.sorted { a, b in
            if let majorityRate {
                let aMatches = a.sampleRate == majorityRate
                let bMatches = b.sampleRate == majorityRate
                if aMatches != bMatches {
                    return aMatches
                }
            }
            return a.sampleRate > b.sampleRate
        }

        let names = sorted.map { "\($0.name) (\($0.sampleRate)Hz)" }.joined(separator: ", ")
        logInfo("Selected devices for sharing - \(names)")
        return sorted
    }

    // MARK: - Private Methods

    private func setupAudioDeviceMonitoring() {
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
            NotificationCenter.default.postDeviceConfigurationChanged()
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
    private func handleVolumeChange(deviceID: AudioDeviceID, propertyAddress: AudioObjectPropertyAddress) async {
        logInfo("Volume change detected for device ID: \(deviceID)")
        logDebug("Property address: selector=\(propertyAddress.mSelector), scope=\(propertyAddress.mScope), element=\(propertyAddress.mElement)")

        guard let device = compatibleDevices.first(where: { $0.id == deviceID }) else {
            logWarning("Device with ID \(deviceID) not found in compatible devices")
            return
        }

        if let newVolume = await device.getVolume() {
            logInfo("Volume for \(device.name): \(newVolume)")
            NotificationCenter.default.postDeviceVolumeChanged(deviceID: deviceID, volume: newVolume)
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
        logDebug("Setting up volume change listeners")

        if volumeListenerBlock == nil {
            volumeListenerBlock = { [weak self] inObjectID, propertyAddress in
                let address = propertyAddress.pointee
                Task { @MainActor in
                    await self?.handleVolumeChange(deviceID: inObjectID, propertyAddress: address)
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
