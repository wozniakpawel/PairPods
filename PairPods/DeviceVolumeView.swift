//
//  DeviceVolumeView.swift
//  PairPods
//
//  Created by m6511 on 19.04.2025.
//

import MacControlCenterUI
import SwiftUI

struct DeviceVolumeView: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @ObservedObject var volumeManager: AudioVolumeManager
    var isSharingTransitioning: Bool = false

    var body: some View {
        let masterUID = audioDeviceManager.masterDeviceUID
        VStack(spacing: 12) {
            ForEach(audioDeviceManager.compatibleDevices, id: \.uid) { device in
                DeviceVolumeRowView(
                    device: device,
                    volume: Binding(
                        get: { volumeManager.deviceVolumes[device.id] ?? volumeManager.getDefaultVolume(for: device) },
                        set: { newValue in
                            Task {
                                await volumeManager.setVolume(for: device.id, volume: newValue)
                            }
                        }
                    ),
                    isSelected: Binding(
                        get: { audioDeviceManager.isDeviceSelected(device.uid) },
                        set: { audioDeviceManager.setDeviceExcluded(device.uid, excluded: !$0) }
                    ),
                    isMaster: device.uid == masterUID,
                    onSetMaster: { audioDeviceManager.setMasterDevice(device.uid) },
                    isConfiguring: isSharingTransitioning
                )
            }
            if audioDeviceManager.compatibleDevices.count < 2 {
                MenuCommand("Open Bluetooth Settings...") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .padding(.horizontal, -14)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: audioDeviceManager.compatibleDevices.count)
    }
}

// MARK: - Device Row

private struct DeviceVolumeRowView: View {
    let device: AudioDevice
    @Binding var volume: Float
    @Binding var isSelected: Bool
    let isMaster: Bool
    let onSetMaster: () -> Void
    let isConfiguring: Bool

    private var cgFloatVolume: Binding<CGFloat> {
        Binding(
            get: { CGFloat(volume) },
            set: { volume = Float($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("Include \(device.name)", isOn: $isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                Button(action: onSetMaster) {
                    Image(systemName: isMaster ? "crown.fill" : "crown")
                        .font(.system(size: 11))
                        .foregroundColor(isMaster ? .orange : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help(isMaster ? "Master clock device" : "Set as master clock")

                Image(systemName: deviceIcon)
                    .foregroundColor(.secondary)

                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .disabled(isConfiguring)

            HStack(spacing: 6) {
                if let battery = device.batteryInfo?.displayLevel {
                    BatteryLevelView(level: battery)
                }

                Text(formatSampleRate(device.sampleRate))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(3)

                Spacer()

                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("\(Int(volume * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            MenuVolumeSlider(value: cgFloatVolume)
        }
        .padding(.vertical, 2)
    }

    /// Determine icon based on device type
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

    private func formatSampleRate(_ rate: Double) -> String {
        String(format: "%.1f kHz", rate / 1000)
    }
}

struct BatteryLevelView: View {
    let level: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: batteryIconName)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text("\(level)%")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private var batteryIconName: String {
        switch level {
        case 0 ..< 13:
            "battery.0percent"
        case 13 ..< 38:
            "battery.25percent"
        case 38 ..< 63:
            "battery.50percent"
        case 63 ..< 88:
            "battery.75percent"
        default:
            "battery.100percent"
        }
    }
}

#Preview {
    let deviceManager = AudioDeviceManager(audioSystem: PreviewAudioSystem(), shouldShowAlerts: false)
    let volumeManager = AudioVolumeManager(audioDeviceManager: deviceManager)

    return DeviceVolumeView(
        audioDeviceManager: deviceManager,
        volumeManager: volumeManager
    )
    .frame(width: 270)
    .padding()
}
