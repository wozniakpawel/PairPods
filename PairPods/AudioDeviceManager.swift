//
//  AudioDeviceManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import CoreAudio
import Foundation
import SwiftUI

public enum AudioDeviceState {
    case active
    case inactive
    case error(Error)
}

@MainActor
final class AudioDeviceManager: AudioDeviceManaging {
    private let multiOutputDeviceUID = "PairPodsOutputDevice"
    private var originalOutputDeviceID: AudioDeviceID?
    private var sharedDevices: (master: AudioDevice, second: AudioDevice)?
    private var propertyListenerBlock: AudioObjectPropertyListenerBlock?
    private let shouldShowAlerts: Bool
    
    @Published private(set) var compatibleDevices: [AudioDevice] = []

    var deviceStateDidChange: ((AudioDeviceState) -> Void)?

    init(shouldShowAlerts: Bool = true) {
        self.shouldShowAlerts = shouldShowAlerts
        logDebug("Initializing AudioDeviceManager")
        setupAudioDeviceMonitoring()
        Task {
            await removeMultiOutputDevice()
            await initializeDevices()
        }
    }

    // MARK: - Public Methods
    

    public func cleanup() async {
        logInfo("Cleaning up AudioDeviceManager")
        await removeMultiOutputDevice()
        removePropertyListener()
    }

    public func setupMultiOutputDevice() async throws {
        logInfo("Starting setup of multi-output device")
        let (defaultDevice, originalID) = await fetchDefaultOutputDevice()
        originalOutputDeviceID = originalID
        await removeMultiOutputDevice()

        let devices = try await fetchAllAudioDevices()
        logDevices(allDevices: devices, defaultDevice: defaultDevice)

        let compatibleDevices = devices.filter(\.isCompatibleOutputDevice)
        try validateCompatibleDevices(compatibleDevices)

        let (masterDevice, secondDevice) = selectDevicesForSharing(compatibleDevices)
        sharedDevices = (master: masterDevice, second: secondDevice)

        let deviceID = try await createMultiOutputDevice(masterDevice: masterDevice, secondDevice: secondDevice)
        try await setDefaultOutputDevice(deviceID: deviceID)
        deviceStateDidChange?(.active)
        logInfo("Multi-output device setup completed successfully")
    }

    public func restoreOutputDevice() async {
        logInfo("Restoring output device to previous state")
        do {
            let devices = try await fetchAllAudioDevices()
            let masterDevice = sharedDevices?.master
            let secondDevice = sharedDevices?.second

            if let master = masterDevice, devices.contains(where: { $0.id == master.id }) {
                try await setDefaultOutputDevice(deviceID: master.id)
                deviceStateDidChange?(.inactive)
                logInfo("Restored to master device: \(master.name)")
            } else if let second = secondDevice, devices.contains(where: { $0.id == second.id }) {
                try await setDefaultOutputDevice(deviceID: second.id)
                deviceStateDidChange?(.inactive)
                logInfo("Restored to second device: \(second.name)")
            } else {
                try await restoreToBuiltInSpeakers()
                deviceStateDidChange?(.inactive)
                logInfo("Restored to built-in speakers")
            }
        } catch {
            let appError = AppError.systemError(error)
            deviceStateDidChange?(.error(appError))
            logError("Failed to restore output device", error: appError)
        }

        originalOutputDeviceID = nil
        sharedDevices = nil
    }

    public func removeMultiOutputDevice() async {
        logInfo("Attempting to remove existing multi-output device")
        if let deviceID = await fetchDeviceID(deviceUID: multiOutputDeviceUID as CFString) {
            do {
                try await destroyAggregateDevice(deviceID: deviceID)
                deviceStateDidChange?(.inactive)
                logInfo("Successfully removed multi-output device")
            } catch {
                let appError = AppError.systemError(error)
                deviceStateDidChange?(.error(appError))
                logError("Failed to remove multi-output device", error: appError)
            }
        } else {
            logDebug("No existing multi-output device found")
        }
    }

    public func isMultiOutputDeviceActive() async -> Bool {
        let (defaultDevice, _) = await fetchDefaultOutputDevice()
        return defaultDevice?.uid == multiOutputDeviceUID
    }

    public func isMultiOutputDeviceValid() async -> Bool {
        guard let masterDevice = sharedDevices?.master,
              let secondDevice = sharedDevices?.second
        else {
            return false
        }
        let devices = await (try? fetchAllAudioDevices()) ?? []
        return devices.contains(where: { $0.id == masterDevice.id }) &&
            devices.contains(where: { $0.id == secondDevice.id })
    }
    
    // Method to refresh the list of compatible devices
    public func refreshCompatibleDevices() async {
        do {
            let devices = try await fetchAllAudioDevices()
            compatibleDevices = devices.filter(\.isCompatibleOutputDevice)
            logInfo("Found \(compatibleDevices.count) compatible audio devices")
        } catch {
            logError("Failed to refresh compatible devices", error: .systemError(error))
        }
    }
    
    // Get volume for a specific device
    public func getDeviceVolume(deviceID: AudioDeviceID) async -> Float {
        if let device = compatibleDevices.first(where: { $0.id == deviceID }),
           let volume = await device.getVolume() {
            return volume
        }
        return 0.0
    }
    
    // Set volume for a specific device
    public func setDeviceVolume(deviceID: AudioDeviceID, volume: Float) async {
        guard let device = compatibleDevices.first(where: { $0.id == deviceID }) else {
            logError("Failed to set volume for device", error: .operationError("Device with ID \(deviceID) not found"))
            return
        }
        
        logDebug("Setting volume for device: \(device.name) (ID: \(deviceID)) to \(volume)")
        
        do {
            try await device.setVolume(volume)
            logInfo("Set volume for device \(device.name) to \(volume)")
        } catch let error as AppError {
            logError("Failed to set volume for device \(device.name)", error: error)
        } catch {
            let appError = AppError.systemError(error)
            logError("Failed to set volume for device \(device.name)", error: appError)
        }
    }
      
      // Initialize devices on startup
      func initializeDevices() async {
          await refreshCompatibleDevices()
          // Setup listener for device property changes
          setupVolumeChangeListener()
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
            deviceStateDidChange?(.error(error))
            logError("Failed to add audio device change listener", error: error)
        }
    }

    private func handleAudioDeviceChange() async {
        let isActive = await isMultiOutputDeviceActive()
        let isValid = await isMultiOutputDeviceValid()

        if isActive, !isValid {
            logWarning("Multi-output device configuration is no longer valid")
            deviceStateDidChange?(.inactive)
            NotificationCenter.default.post(name: .audioDeviceConfigurationChanged, object: nil)
        }
    }

    private func restoreToBuiltInSpeakers() async throws {
        logInfo("Attempting to restore to built-in speakers")
        let devices = try await fetchAllAudioDevices()
        if let builtInSpeakers = devices.first(where: { $0.transportType == kAudioDeviceTransportTypeBuiltIn && $0.isOutputDevice }) {
            try await setDefaultOutputDevice(deviceID: builtInSpeakers.id)
            logInfo("Successfully restored to built-in speakers")
        } else {
            throw AppError.operationError("No built-in speakers found")
        }
    }

    private func fetchAllAudioDevices() async throws -> [AudioDevice] {
        let deviceIDs = try await fetchAllAudioDeviceIDs()
        return await withTaskGroup(of: AudioDevice?.self) { group in
            for deviceID in deviceIDs {
                group.addTask {
                    await AudioDevice(deviceID: deviceID)
                }
            }
            var devices: [AudioDevice] = []
            for await device in group {
                if let device {
                    devices.append(device)
                }
            }
            return devices
        }
    }

    private func fetchAllAudioDeviceIDs() async throws -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize)
        guard status == noErr else {
            throw AppError.operationError("Unable to get property data size for audio devices. Status: \(status)")
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        let getStatus = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceIDs)
        guard getStatus == noErr else {
            throw AppError.operationError("Unable to get audio device IDs. Status: \(getStatus)")
        }

        return deviceIDs
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
        alert.informativeText = "Please make sure at least two Bluetooth audio devices are paired and connected to your Mac."
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

    private func validateCompatibleDevices(_ devices: [AudioDevice]) throws {
        logInfo("Found \(devices.count) compatible devices")
        guard devices.count >= 2 else {
            let error = AppError.operationError("Not enough compatible devices connected")
            logError("Device validation failed", error: error)
            showBluetoothSettingsAlert()
            throw error
        }
    }

    private func selectDevicesForSharing(_ devices: [AudioDevice]) -> (AudioDevice, AudioDevice) {
        let sortedDevices = devices.sorted { $0.sampleRate > $1.sampleRate }
        let masterDevice = sortedDevices[0]
        let secondDevice = sortedDevices[1]
        logInfo("Selected devices for sharing - Master: \(masterDevice.name) (\(masterDevice.sampleRate)Hz), Second: \(secondDevice.name) (\(secondDevice.sampleRate)Hz)")
        return (masterDevice, secondDevice)
    }

    private func fetchDefaultOutputDevice() async -> (AudioDevice?, AudioDeviceID?) {
        guard let defaultDeviceID = await findDefaultAudioDeviceID() else {
            return (nil, nil)
        }
        let device = await AudioDevice(deviceID: defaultDeviceID)
        return (device, defaultDeviceID)
    }

    private func createMultiOutputDevice(masterDevice: AudioDevice, secondDevice: AudioDevice) async throws -> AudioDeviceID {
        logDebug("Creating multi-output device")
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "PairPods Output Device",
            kAudioAggregateDeviceUIDKey: multiOutputDeviceUID,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: masterDevice.uid],
                [kAudioSubDeviceUIDKey: secondDevice.uid, kAudioSubDeviceDriftCompensationKey as String: 1],
            ],
            kAudioAggregateDeviceMasterSubDeviceKey: masterDevice.uid,
            kAudioAggregateDeviceIsStackedKey: 1,
        ]

        var aggregateDevice: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggregateDevice)
        guard status == noErr else {
            throw AppError.operationError("Failed to create multi-output device. Status: \(status)")
        }

        logInfo("Created multi-output device with ID: \(aggregateDevice)")
        return aggregateDevice
    }

    private func setDefaultOutputDevice(deviceID: AudioDeviceID) async throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var mutableDeviceID = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
        guard status == noErr else {
            throw AppError.operationError("Failed to set default output device. Status: \(status)")
        }
    }

    private func destroyAggregateDevice(deviceID: AudioDeviceID) async throws {
        let status = AudioHardwareDestroyAggregateDevice(deviceID)
        guard status == noErr else {
            throw AppError.operationError("Failed to destroy aggregate device. Status: \(status)")
        }
    }

    private func findDefaultAudioDeviceID() async -> AudioDeviceID? {
        var defaultDeviceID = AudioDeviceID()
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultDeviceID)
        return status == noErr ? defaultDeviceID : nil
    }

    private func fetchDeviceID(deviceUID: CFString) async -> AudioDeviceID? {
        do {
            let devices = try await fetchAllAudioDevices()
            return devices.first { $0.uid as CFString == deviceUID }?.id
        } catch {
            logError("Failed to fetch device ID", error: .systemError(error))
            return nil
        }
    }

    private func audioObjectPropertyAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func addPropertyListener(_ listener: @escaping AudioObjectPropertyListenerBlock) -> OSStatus {
        var address = audioObjectPropertyAddress()
        return AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            listener
        )
    }

    private func removePropertyListener() {
        guard let propertyListenerBlock else { return }
        var address = audioObjectPropertyAddress()
        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            propertyListenerBlock
        )
        if status != noErr {
            logError("Failed to remove property listener", error: .operationError("Status: \(status)"))
        }
    }
    
    // Setup a listener for volume changes
        private func setupVolumeChangeListener() {
            // Implementation would track volume changes from system
            logDebug("Volume change listener would be set up here")
        }
}

extension Notification.Name {
    static let audioDeviceConfigurationChanged = Notification.Name("audioDeviceConfigurationChanged")
}
