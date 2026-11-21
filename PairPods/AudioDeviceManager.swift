//
//  AudioDeviceManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import AppKit
import Combine
import CoreAudio

// MARK: - Audio Device Notifications

extension Notification.Name {
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
}

@MainActor
final class AudioDeviceManager: ObservableObject {
    private let multiOutputDeviceUID = "PairPodsOutputDevice"
    private static let excludedDeviceUIDsKey = "excludedDeviceUIDs"
    private static let deviceOrderKey = "PairPods.DeviceOrder"

    private struct Output {
        let id: AudioDeviceID
        let devices: [AudioDevice]
    }

    private var output: Output?
    var configurationDidChange: (() -> Void)?
    private var monitor: AudioDeviceMonitor?
    private var initTask: Task<Void, Never>?
    private let shouldShowAlerts: Bool
    private let userDefaults: UserDefaults
    let notificationCenter: NotificationCenter
    private let audioSystem: AudioSystemQuerying & AudioSystemCommanding

    @Published private(set) var compatibleDevices: [AudioDevice] = []
    @Published private(set) var excludedDeviceUIDs: Set<String> = []
    var isOutputConnected: Bool {
        guard let output else { return true }
        return output.devices.allSatisfy { device in
            compatibleDevices.contains { $0.id == device.id && $0.uid == device.uid }
        }
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
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        excludedDeviceUIDs = Set(userDefaults.stringArray(forKey: Self.excludedDeviceUIDsKey) ?? [])
        logDebug("Initializing AudioDeviceManager")
        if monitorHardware {
            monitor = AudioDeviceMonitor(
                onDevicesChanged: { [weak self] in await self?.handleAudioDeviceChange() },
                onVolumeChanged: { [weak self] id in self?.handleVolumeChange(id) }
            )
        }
        initTask = Task {
            guard !Task.isCancelled else { return }
            await removeStaleAggregate()
            guard !Task.isCancelled else { return }
            await refreshCompatibleDevices()
        }
    }

    // MARK: - Device Exclusion

    func setDeviceExcluded(_ uid: String, excluded: Bool) {
        guard excluded != excludedDeviceUIDs.contains(uid) else { return }
        if excluded {
            excludedDeviceUIDs.insert(uid)
        } else {
            excludedDeviceUIDs.remove(uid)
        }
        saveExcludedDeviceUIDs()
        configurationDidChange?()
    }

    func isDeviceSelected(_ uid: String) -> Bool {
        !excludedDeviceUIDs.contains(uid)
    }

    private func saveExcludedDeviceUIDs() {
        userDefaults.set(Array(excludedDeviceUIDs), forKey: Self.excludedDeviceUIDsKey)
    }

    // MARK: - Device Order

    func setMasterDevice(_ uid: String) {
        saveDeviceOrder([uid] + compatibleDevices.map(\.uid).filter { $0 != uid })
        configurationDidChange?()
    }

    func saveDeviceOrder(_ uids: [String]) {
        userDefaults.set(uids, forKey: Self.deviceOrderKey)
        objectWillChange.send()
        logDebug("Saved device order: \(uids)")
    }

    func loadDeviceOrder() -> [String] {
        userDefaults.stringArray(forKey: Self.deviceOrderKey) ?? []
    }

    var masterDeviceUID: String? {
        masterDeviceUID(for: selectedDevices)
    }

    func masterDeviceUID(for devices: [AudioDevice]) -> String? {
        selectDevicesForSharing(devices).first?.uid
    }

    // MARK: - Public Methods

    func cleanup() async {
        monitor = nil
        initTask?.cancel()
        await initTask?.value
        await stopOutput()
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
        await initTask?.value
        await stopOutput()
        let devices = try await audioSystem.fetchAllAudioDevices()
        try Task.checkCancellation()
        updateCompatibleDevices(devices)
        let selected = selectedDevices
        try validateSelectedDevices(selected)

        let sorted = selectDevicesForSharing(selected)
        let id = try await audioSystem.createAggregateDevice(
            name: "PairPods Output Device",
            uid: multiOutputDeviceUID,
            masterUID: sorted[0].uid,
            subDeviceUIDs: sorted.map(\.uid)
        )
        do {
            try Task.checkCancellation()
            try await audioSystem.setDefaultOutputDevice(deviceID: id)
        } catch {
            await destroyAggregate(id)
            throw error
        }
        output = Output(id: id, devices: sorted)
    }

    func stopOutput() async {
        guard let output else { return }
        self.output = nil
        let (_, defaultID) = await audioSystem.fetchDefaultOutputDevice()
        if defaultID == nil || defaultID == output.id {
            await restoreOutput(from: output.devices)
        }
        await destroyAggregate(output.id)
    }

    private func restoreOutput(from sharedDevices: [AudioDevice]) async {
        do {
            let devices = try await audioSystem.fetchAllAudioDevices()
            let fallback = sharedDevices.lazy.compactMap { shared in
                devices.first { $0.uid == shared.uid }
            }.first ?? devices.first {
                $0.transportType == kAudioDeviceTransportTypeBuiltIn && $0.isOutputDevice
            }
            if let fallback {
                try await audioSystem.setDefaultOutputDevice(deviceID: fallback.id)
            }
        } catch {
            logError("Failed to restore output device", error: .systemError(error))
        }
    }

    private func removeStaleAggregate() async {
        if let id = await audioSystem.fetchDeviceID(deviceUID: multiOutputDeviceUID) {
            await destroyAggregate(id)
        }
    }

    private func destroyAggregate(_ id: AudioDeviceID) async {
        do {
            try await audioSystem.destroyAggregateDevice(deviceID: id)
        } catch {
            logError("Failed to remove aggregate device", error: .systemError(error))
        }
    }

    func refreshCompatibleDevices() async {
        do {
            try await updateCompatibleDevices(audioSystem.fetchAllAudioDevices())
        } catch {
            logError("Failed to refresh compatible devices", error: .systemError(error))
        }
    }

    private func updateCompatibleDevices(_ devices: [AudioDevice]) {
        compatibleDevices = devices.filter(\.isCompatibleOutputDevice).sorted(by: Self.deviceNameOrder)
        monitor?.observeVolume(of: Set(compatibleDevices.map(\.id)))
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

    // MARK: - Private Methods

    private static func deviceNameOrder(_ a: AudioDevice, _ b: AudioDevice) -> Bool {
        (a.name, a.uid) < (b.name, b.uid)
    }

    func handleAudioDeviceChange() async {
        await refreshCompatibleDevices()
        if !isOutputConnected {
            configurationDidChange?()
        }
    }

    private func showBluetoothSettingsAlert() {
        guard shouldShowAlerts else { return }

        let alert = NSAlert()
        alert.messageText = "Not enough devices connected"
        alert.informativeText = "Select at least two connected Bluetooth audio devices."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Open Bluetooth Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
    }

    private func handleVolumeChange(_ id: AudioDeviceID) {
        if let device = compatibleDevices.first(where: { $0.id == id }), let volume = device.getVolume() {
            notificationCenter.postDeviceVolumeChanged(deviceID: id, volume: volume)
        }
    }
}

// MARK: - Internal Methods (exposed for testing)

extension AudioDeviceManager {
    func validateSelectedDevices(_ devices: [AudioDevice]) throws {
        guard devices.count >= 2 else {
            showBluetoothSettingsAlert()
            throw AppError.operationError("Select at least two connected Bluetooth audio devices.")
        }
    }

    func selectDevicesForSharing(_ devices: [AudioDevice]) -> [AudioDevice] {
        // If user has defined a preferred order, use it (first device = master clock)
        let userOrder = loadDeviceOrder()
        if devices.contains(where: { userOrder.contains($0.uid) }) {
            return devices.sorted { a, b in
                let ai = userOrder.firstIndex(of: a.uid) ?? Int.max
                let bi = userOrder.firstIndex(of: b.uid) ?? Int.max
                if ai != bi {
                    return ai < bi
                }
                return Self.deviceNameOrder(a, b)
            }
        }

        // Fallback: find the most common sample rate among the devices
        var rateCount: [Double: Int] = [:]
        for device in devices {
            rateCount[device.sampleRate, default: 0] += 1
        }
        let maxCount = rateCount.values.max() ?? 0
        let hasClearMajority = rateCount.values.count(where: { $0 == maxCount }) == 1
        let majorityRate = hasClearMajority ? rateCount.first(where: { $0.value == maxCount })?.key : nil

        // Sort: when a clear majority exists, those devices go first; otherwise sort descending by rate
        return devices.sorted { a, b in
            if let majorityRate {
                let aMatches = a.sampleRate == majorityRate
                let bMatches = b.sampleRate == majorityRate
                if aMatches != bMatches {
                    return aMatches
                }
            }
            if a.sampleRate != b.sampleRate {
                return a.sampleRate > b.sampleRate
            }
            return Self.deviceNameOrder(a, b)
        }
    }
}
