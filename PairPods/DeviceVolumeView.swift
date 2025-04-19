//
//  DeviceVolumeView.swift
//  PairPods
//
//  Created by M on 19.04.2025.
//
import SwiftUI
import AppKit
import CompactSlider

struct DeviceVolumeView: View {
    @StateObject var viewModel: DeviceVolumeViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.compatibleDevices, id: \.id) { device in
                DeviceVolumeRowView(
                    deviceName: device.name,
                    volume: Binding(
                        get: { viewModel.deviceVolumes[device.id] ?? 0.0 },
                        set: { newValue in
                            Task {
                                await viewModel.setVolume(for: device.id, volume: newValue)
                            }
                        }
                    )
                )
            }
            
            if viewModel.compatibleDevices.isEmpty {
                Text("No Bluetooth audio devices connected")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            Task {
                await viewModel.refreshDevices()
                await viewModel.refreshAllVolumes()
            }
        }
    }
}
struct DeviceVolumeRowView: View {
    let deviceName: String
    @Binding var volume: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(deviceName)
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
                
                // Volume percentage indicator
                Text("\(Int(volume * 100))%")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                // Volume low icon
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                CompactSlider(value: $volume)
                    .frame(height: 16)
                
                // Volume high icon
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
#Preview(body: {
    DeviceVolumeView(viewModel: DeviceVolumeViewModel(audioDeviceManager: AudioDeviceManager()))
})
