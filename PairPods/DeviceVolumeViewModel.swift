//
//  DeviceVolumeViewModel.swift
//  PairPods
//
//  Created by M on 19.04.2025.
//


import Foundation
import SwiftUI
import Combine
import CoreAudio

@MainActor
class DeviceVolumeViewModel: ObservableObject {
    private let audioDeviceManager: AudioDeviceManager
    private var cancellables = Set<AnyCancellable>()
    
    @Published var deviceVolumes: [AudioDeviceID: Float] = [:]
    @Published var compatibleDevices: [AudioDevice] = []
    
    init(audioDeviceManager: AudioDeviceManager) {
        self.audioDeviceManager = audioDeviceManager
        
        // Subscribe to changes in compatible devices
        audioDeviceManager.$compatibleDevices
            .sink { [weak self] devices in
                self?.compatibleDevices = devices
                Task { await self?.refreshAllVolumes() }
            }
            .store(in: &cancellables)
    }
    
    func refreshAllVolumes() async {
        for device in compatibleDevices {
            if let volume = await device.getVolume() {
                deviceVolumes[device.id] = volume
            }
        }
    }
    
    func setVolume(for deviceID: AudioDeviceID, volume: Float) async {
        // Update the local state immediately for a responsive UI
        deviceVolumes[deviceID] = volume
        
        // Then update the actual device volume
        await audioDeviceManager.setDeviceVolume(deviceID: deviceID, volume: volume)
    }
    
    func refreshDevices() async {
        await audioDeviceManager.refreshCompatibleDevices()
    }
}
