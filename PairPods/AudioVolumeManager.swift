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
class AudioVolumeManager: ObservableObject {
    // AudioDeviceManager reference for device access
    private let audioDeviceManager: AudioDeviceManager
    private var cancellables = Set<AnyCancellable>()
    private let defaultVolume: Float = 0.5
    private let volumeCacheKey = "PairPods.DeviceVolumes"
    private let userDefaults: UserDefaults

    // Published properties for UI binding
    @Published private(set) var deviceVolumes: [AudioDeviceID: Float] = [:]
    @Published private(set) var lastKnownVolumes: [String: Float] = [:] // Cache by device UID

    init(audioDeviceManager: AudioDeviceManager, userDefaults: UserDefaults = .standard) {
        self.audioDeviceManager = audioDeviceManager
        self.userDefaults = userDefaults

        // Load cached volumes from UserDefaults
        loadCachedVolumes()

        // Subscribe to changes in compatible devices
        audioDeviceManager.$compatibleDevices
            .receive(on: RunLoop.main)
            .sink { [weak self] devices in
                Task {
                    await self?.refreshVolumesForDevices(devices)
                }
            }
            .store(in: &cancellables)

        // Listen for device volume changes (from device buttons)
        NotificationCenter.default.publisher(for: .audioDeviceVolumeChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                logDebug("AudioVolumeManager received volume change notification")
                if let deviceID = notification.userInfo?["deviceID"] as? AudioDeviceID,
                   let volume = notification.userInfo?["volume"] as? Float
                {
                    logDebug("AudioVolumeManager updating volume for device ID: \(deviceID) to \(volume)")

                    // Update the volume in our state
                    self?.deviceVolumes[deviceID] = volume

                    // Update persisted volume data if we have the device
                    if let self,
                       let device = self.audioDeviceManager.compatibleDevices.first(where: { $0.id == deviceID })
                    {
                        logDebug("AudioVolumeManager caching volume: \(volume) for device: \(device.name)")
                        lastKnownVolumes[device.uid] = volume
                        saveCachedVolumes()
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
        await refreshVolumesForDevices(audioDeviceManager.compatibleDevices)
    }

    /// Set volume for a specific device
    func setVolume(for deviceID: AudioDeviceID, volume: Float) async {
        // Update the local state immediately for responsive UI
        deviceVolumes[deviceID] = volume

        // Find the device to get its UID for caching
        if let device = audioDeviceManager.compatibleDevices.first(where: { $0.id == deviceID }) {
            // Cache the volume by device UID (persistent identifier)
            lastKnownVolumes[device.uid] = volume
            saveCachedVolumes()
        }

        // Update the actual device volume
        await audioDeviceManager.setDeviceVolume(deviceID: deviceID, volume: volume)
    }

    /// Get default volume for a device (either cached or 50% as fallback)
    func getDefaultVolume(for device: AudioDevice) -> Float {
        if let cachedVolume = lastKnownVolumes[device.uid] {
            return cachedVolume
        }
        return defaultVolume
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
                // If volume can't be read, show cached/default in UI but don't
                // write it to the device — the real volume is unknown
                let fallbackVolume = getDefaultVolume(for: device)
                deviceVolumes[device.id] = fallbackVolume
                logWarning("Could not read volume for \(device.name), using fallback \(fallbackVolume)")
            }
        }

        // Save updated volumes to persistent storage
        saveCachedVolumes()
    }

    /// Save volume cache to UserDefaults
    private func saveCachedVolumes() {
        userDefaults.set(lastKnownVolumes, forKey: volumeCacheKey)
    }

    /// Load volume cache from UserDefaults
    private func loadCachedVolumes() {
        if let savedVolumes = userDefaults.dictionary(forKey: volumeCacheKey) as? [String: Float] {
            lastKnownVolumes = savedVolumes
        }
    }
}
