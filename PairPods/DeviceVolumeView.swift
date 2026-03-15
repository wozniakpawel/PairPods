//
//  DeviceVolumeView.swift
//  PairPods
//
//  Created by m6511 on 19.04.2025.
//

import MacControlCenterUI
import SwiftUI
import UniformTypeIdentifiers

struct DeviceVolumeView: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @ObservedObject var volumeManager: AudioVolumeManager
    var isSharingActive: Bool = false

    @State private var draggingUID: String? = nil

    private var sortedDevices: [AudioDevice] {
        let order = audioDeviceManager.loadDeviceOrder()
        return audioDeviceManager.compatibleDevices.sorted { a, b in
            let ai = order.firstIndex(of: a.uid) ?? Int.max
            let bi = order.firstIndex(of: b.uid) ?? Int.max
            if ai != bi { return ai < bi }
            return a.name < b.name
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if audioDeviceManager.compatibleDevices.isEmpty {
                NoDevicesView()
            } else {
                ForEach(sortedDevices) { device in
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
                            set: { newValue in
                                audioDeviceManager.setDeviceExcluded(device.uid, excluded: !newValue)
                                if isSharingActive {
                                    NotificationCenter.default.postDeviceConfigurationChanged()
                                }
                            }
                        ),
                        isDragging: draggingUID == device.uid
                    )
                    .onDrag {
                        draggingUID = device.uid
                        return NSItemProvider(object: device.uid as NSString)
                    }
                    .onDrop(
                        of: [.plainText],
                        delegate: DeviceDropDelegate(
                            targetUID: device.uid,
                            draggingUID: $draggingUID,
                            devices: sortedDevices,
                            onReorder: { newOrder in
                                audioDeviceManager.saveDeviceOrder(newOrder.map(\.uid))
                                if isSharingActive {
                                    NotificationCenter.default.postDeviceConfigurationChanged()
                                }
                            }
                        )
                    )
                }
                if audioDeviceManager.compatibleDevices.count == 1 {
                    MenuCommand("Open Bluetooth Settings...") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .padding(.horizontal, -14)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: audioDeviceManager.compatibleDevices.count)
    }
}

// MARK: - Drop Delegate

private struct DeviceDropDelegate: DropDelegate {
    let targetUID: String
    @Binding var draggingUID: String?
    let devices: [AudioDevice]
    let onReorder: ([AudioDevice]) -> Void

    func performDrop(info _: DropInfo) -> Bool {
        guard let dragging = draggingUID, dragging != targetUID else {
            draggingUID = nil
            return false
        }
        var reordered = devices
        guard
            let fromIndex = reordered.firstIndex(where: { $0.uid == dragging }),
            let toIndex = reordered.firstIndex(where: { $0.uid == targetUID })
        else {
            draggingUID = nil
            return false
        }
        let item = reordered.remove(at: fromIndex)
        reordered.insert(item, at: toIndex)
        onReorder(reordered)
        draggingUID = nil
        return true
    }

    func dropEntered(info _: DropInfo) {}

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info _: DropInfo) -> Bool {
        draggingUID != nil
    }
}

// MARK: - Device Row

struct DeviceVolumeRowView: View {
    let device: AudioDevice
    @Binding var volume: Float
    @Binding var isSelected: Bool
    var isDragging: Bool = false

    private var cgFloatVolume: Binding<CGFloat> {
        Binding(
            get: { CGFloat(volume) },
            set: { volume = Float($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.trailing, 2)

                Toggle("", isOn: $isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                Image(systemName: deviceIcon)
                    .foregroundColor(.secondary)

                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let battery = device.batteryLevel {
                    BatteryLevelView(level: battery)
                }

                Spacer()

                Text(formatSampleRate(device.sampleRate))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(3)

                Text("\(Int(volume * 100))%")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            MenuVolumeSlider(value: cgFloatVolume)
        }
        .padding(.vertical, 2)
        .opacity(isDragging ? 0.5 : 1.0)
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
    let deviceManager = AudioDeviceManager(audioSystem: PreviewAudioSystem(), shouldShowAlerts: false)
    let volumeManager = AudioVolumeManager(audioDeviceManager: deviceManager)

    return DeviceVolumeView(
        audioDeviceManager: deviceManager,
        volumeManager: volumeManager,
        isSharingActive: false
    )
    .frame(width: 270)
    .padding()
}
