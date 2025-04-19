//
//  DeviceVolumeView.swift
//  PairPods
//
//  Created by m6511 on 19.04.2025.
//

import SwiftUI
import MacControlCenterUI

struct DeviceVolumeView: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @ObservedObject var volumeManager: AudioVolumeManager
    
    var body: some View {
        VStack(spacing: 12) {
            if audioDeviceManager.compatibleDevices.isEmpty {
                NoDevicesView()
            } else {
                ForEach(audioDeviceManager.compatibleDevices, id: \.id) { device in
                    DeviceVolumeRowView(
                        device: device,
                        volume: Binding(
                            get: { volumeManager.deviceVolumes[device.id] ?? volumeManager.getDefaultVolume(for: device) },
                            set: { newValue in
                                Task {
                                    await volumeManager.setVolume(for: device.id, volume: newValue)
                                }
                            }
                        )
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: audioDeviceManager.compatibleDevices.count)
        .onAppear {
            Task {
                await audioDeviceManager.refreshCompatibleDevices()
                await volumeManager.refreshAllVolumes()
            }
        }
    }
}

struct DeviceVolumeRowView: View {
    let device: AudioDevice
    @Binding var volume: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Device icon based on type
                Image(systemName: deviceIcon)
                    .foregroundColor(.secondary)
                
                // Device name
                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                // Volume percentage indicator
                Text("\(Int(volume * 100))%")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            
            // Volume slider
            MenuVolumeSlider(
                value: Binding<CGFloat>(
                    get: { CGFloat(volume) },
                    set: { volume = Float($0) }
                )
            )
        }
        .padding(.vertical, 2)
    }
    
    // Determine icon based on device type
    private var deviceIcon: String {
        let name = device.name.lowercased()
        
        if name.contains("airpod") {
            if name.contains("max") {
                return "airpodsmax"
            } else if name.contains("pro") {
                return "airpodspro"
            } else {
                return "airpods"
            }
        } else if name.contains("bluetooth") || name.contains("wireless") {
            return "headphones"
        } else {
            return "speaker.wave.2"
        }
    }
}

struct NoDevicesView: View {
    var body: some View {
        MenuCommand("Open Bluetooth Settings...") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                NSWorkspace.shared.open(url)
            }
        }
        .padding(.horizontal, -14) // avoid unwanted padding
    }
}

#Preview {
    let deviceManager = AudioDeviceManager(shouldShowAlerts: false)
    let volumeManager = AudioVolumeManager(audioDeviceManager: deviceManager)
    
    return DeviceVolumeView(
        audioDeviceManager: deviceManager,
        volumeManager: volumeManager
    )
    .frame(width: 270)
    .padding()
}
