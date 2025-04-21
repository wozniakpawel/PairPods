//
//  AudioVolumeManager.swift
//  PairPods
//
//  Created by m6511 on 19.04.2025.
//

import Combine
import CoreAudio
import Foundation
import SwiftUI

@MainActor
class AudioVolumeManager: ObservableObject, AudioVolumeManaging {
    // AudioDeviceManager reference for device access
    private let audioDeviceManager: AudioDeviceManager
    private var cancellables = Set<AnyCancellable>()

    // Published properties for UI binding
    @Published private(set) var deviceVolumes: [AudioDeviceID: Float] = [:]
    @Published private(set) var lastKnownVolumes: [String: Float] = [:] // Cache by device UID

    init(audioDeviceManager: AudioDeviceManager) {
        self.audioDeviceManager = audioDeviceManager

        // Load cached volumes from UserDefaults
        loadCachedVolumes()

        // Subscribe to changes in compatible devices
        if let concreteManager = audioDeviceManager as? AudioDeviceManager {
            concreteManager.$compatibleDevices
                .receive(on: RunLoop.main)
                .sink { [weak self] devices in
                    Task {
                        await self?.refreshVolumesForDevices(devices)
                    }
                }
                .store(in: &cancellables)
        }

        // Listen for device volume changes (from device buttons)
        NotificationCenter.default.publisher(for: .audioDeviceVolumeChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                logInfo("AudioVolumeManager received volume change notification")
                if let deviceID = notification.userInfo?["deviceID"] as? AudioDeviceID,
                   let volume = notification.userInfo?["volume"] as? Float
                {
                    logInfo("AudioVolumeManager updating volume for device ID: \(deviceID) to \(volume)")

                    // Update the volume in our state
                    self?.deviceVolumes[deviceID] = volume

                    // Update persisted volume data if we have the device
                    if let concreteManager = self?.audioDeviceManager as? AudioDeviceManager,
                       let device = concreteManager.compatibleDevices.first(where: { $0.id == deviceID })
                    {
                        logInfo("AudioVolumeManager caching volume: \(volume) for device: \(device.name)")
                        self?.lastKnownVolumes[device.uid] = volume
                        self?.saveCachedVolumes()
                    } else {
                        logWarning("AudioVolumeManager could not find device with ID: \(deviceID)")
                    }
                } else {
                    logWarning("AudioVolumeManager received invalid volume change notification")
                }
            }
            .store(in: &cancellables)

        // Initial volume refresh
        Task {
            await refreshAllVolumes()
        }
    }

    // MARK: - Public Methods

    /// Refresh volumes for all compatible devices
    func refreshAllVolumes() async {
        if let concreteManager = audioDeviceManager as? AudioDeviceManager {
            await refreshVolumesForDevices(concreteManager.compatibleDevices)
        }
    }

    /// Set volume for a specific device
    func setVolume(for deviceID: AudioDeviceID, volume: Float) async {
        // Update the local state immediately for responsive UI
        deviceVolumes[deviceID] = volume

        // Find the device to get its UID for caching
        if let concreteManager = audioDeviceManager as? AudioDeviceManager,
           let device = concreteManager.compatibleDevices.first(where: { $0.id == deviceID })
        {
            // Cache the volume by device UID (persistent identifier)
            lastKnownVolumes[device.uid] = volume
            saveCachedVolumes()
        }

        // Update the actual device volume
        if let concreteManager = audioDeviceManager as? AudioDeviceManager {
            await concreteManager.setDeviceVolume(deviceID: deviceID, volume: volume)
        }
    }

    /// Get default volume for a device (either cached or 0.75 as fallback)
    func getDefaultVolume(for device: AudioDevice) -> Float {
        // Try to return cached volume by device UID
        if let cachedVolume = lastKnownVolumes[device.uid] {
            return cachedVolume
        }

        // Default to 75% volume if no cached value
        return 0.75
    }

    // MARK: - Private Methods

    /// Refresh volumes for a specific set of devices
    private func refreshVolumesForDevices(_ devices: [AudioDevice]) async {
        for device in devices {
            if let volume = await device.getVolume() {
                // Update the in-memory volume map
                deviceVolumes[device.id] = volume

                // Update the persistent cache
                lastKnownVolumes[device.uid] = volume
            } else {
                // If volume can't be read, use cached/default value
                let defaultVolume = getDefaultVolume(for: device)
                deviceVolumes[device.id] = defaultVolume

                // Try to set this default volume
                try? await device.setVolume(defaultVolume)
            }
        }

        // Save updated volumes to persistent storage
        saveCachedVolumes()
    }

    /// Save volume cache to UserDefaults
    private func saveCachedVolumes() {
        UserDefaults.standard.set(lastKnownVolumes, forKey: "PairPods.DeviceVolumes")
    }

    /// Load volume cache from UserDefaults
    private func loadCachedVolumes() {
        if let savedVolumes = UserDefaults.standard.dictionary(forKey: "PairPods.DeviceVolumes") as? [String: Float] {
            lastKnownVolumes = savedVolumes
        }
    }
}
