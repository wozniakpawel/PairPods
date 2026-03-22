import SwiftUI

// MARK: - Custom Switch (replaces Toggle with .switch style)

struct CustomSwitch: View {
    let isOn: Bool

    private let width: CGFloat = 38
    private let height: CGFloat = 22
    private let knobSize: CGFloat = 18

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255) : Color(red: 120 / 255, green: 120 / 255, blue: 128 / 255))
                .frame(width: width, height: height)

            Circle()
                .fill(Color.white)
                .frame(width: knobSize, height: knobSize)
                .padding(2)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Custom Checkbox (replaces Toggle with .checkbox style)

struct CustomCheckbox: View {
    let isChecked: Bool

    private let size: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isChecked ? Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255) : Color.clear)
                .frame(width: size, height: size)

            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    isChecked ? Color.clear : Color(white: 0.55),
                    lineWidth: 1.5
                )
                .frame(width: size, height: size)

            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Custom Volume Slider (matches MacControlCenterUI MenuVolumeSlider)

struct CustomVolumeSlider: View {
    let value: Double // 0.0 ... 1.0

    private let sliderHeight: CGFloat = 22

    private var speakerIcon: String {
        switch value {
        case 0.0: "speaker.slash.fill"
        case 0.00001 ... 0.33: "speaker.wave.1.fill"
        case 0.33 ... 0.66: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }

    /// Match MacControlCenterUI per-level icon widths
    private var speakerIconWidth: CGFloat {
        switch value {
        case 0.0: 10
        case 0.00001 ... 0.33: 9
        case 0.33 ... 0.66: 11
        default: 14
        }
    }

    private var speakerIconShouldCenter: Bool {
        value == 0.0
    }

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let progressWidth = sliderHeight + (value * (trackWidth - sliderHeight))
            let knobOffset = value * (trackWidth - sliderHeight)

            ZStack(alignment: .leading) {
                // Track background (unfilled portion)
                Capsule()
                    .fill(Color(white: 0.72))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(white: 0.6), lineWidth: 0.25)
                    )
                    .frame(height: sliderHeight)

                // Filled portion (white)
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(progressWidth, sliderHeight), height: sliderHeight)

                // Knob
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle()
                            .strokeBorder(Color(white: 0.5).opacity(0.4), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 2)
                    .frame(width: sliderHeight, height: sliderHeight)
                    .offset(x: knobOffset)

                // Speaker icon (sized per MacControlCenterUI)
                Image(systemName: speakerIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: speakerIconWidth, height: sliderHeight)
                    .foregroundColor(Color(NSColor.gray))
                    .frame(width: speakerIconShouldCenter ? sliderHeight : nil,
                           alignment: speakerIconShouldCenter ? .center : .leading)
                    .offset(x: speakerIconShouldCenter ? 0 : 4)
            }
            .frame(height: sliderHeight)
        }
        .frame(height: sliderHeight)
    }
}

// MARK: - Main Screenshot View

struct ScreenshotView: View {
    let preset: ScreenshotPreset

    var body: some View {
        VStack(spacing: 0) {
            // Share Audio toggle
            HStack {
                Text("Share Audio")
                Spacer()
                CustomSwitch(isOn: preset.isSharingAudio)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Section header
            SectionHeader(
                text: preset.devices.isEmpty
                    ? "No Connected Devices"
                    : preset.devices.count == 1
                    ? "Connected Device"
                    : "Connected Devices"
            )

            // Device rows
            VStack(spacing: 12) {
                ForEach(Array(preset.devices.enumerated()), id: \.offset) { _, device in
                    DeviceRow(device: device)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Divider()
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

            // Reconnect picker
            HStack {
                Text("Reconnect")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 0) {
                    SegmentButton(label: "Off", isSelected: false)
                    SegmentButton(label: "5s", isSelected: false)
                    SegmentButton(label: "10s", isSelected: true)
                    SegmentButton(label: "30s", isSelected: false)
                }
                .background(Color.black.opacity(0.06))
                .cornerRadius(5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)

            // Launch at Login
            HStack {
                Text("Launch at Login")
                    .font(.system(size: 13))
                Spacer()
                CustomCheckbox(isChecked: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)

            // Automatic Updates
            HStack {
                Text("Automatic Updates")
                    .font(.system(size: 13))
                Spacer()
                CustomCheckbox(isChecked: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)

            Divider()
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

            // About
            HStack {
                Text("About")
                    .font(.system(size: 13))
                Spacer()
                Text("⌘ A")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)

            // Quit
            HStack {
                Text("Quit")
                    .font(.system(size: 13))
                Spacer()
                Text("⌘ Q")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .padding(.bottom, 10)
        }
        .frame(width: 270)
        .background(Color(nsColor: NSColor(red: 0.91, green: 0.91, blue: 0.92, alpha: 1.0)))
        .cornerRadius(12)
        .preferredColorScheme(.light)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: MockDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row: checkbox, crown, icon, name
            HStack {
                CustomCheckbox(isChecked: device.isSelected)

                Image(systemName: device.isMaster ? "crown.fill" : "crown")
                    .font(.system(size: 11))
                    .foregroundColor(device.isMaster ? .orange : .secondary.opacity(0.4))

                Image(systemName: device.iconSymbol)
                    .foregroundColor(.secondary)

                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }

            // Info row: battery, sample rate, volume
            HStack(spacing: 6) {
                if let battery = device.batteryLevel {
                    BatteryBadge(level: battery)
                }

                Text(device.formattedSampleRate)
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
                Text("\(device.volumePercent)%")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Volume slider
            CustomVolumeSlider(value: Double(device.volume))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Battery Badge

struct BatteryBadge: View {
    let level: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: batteryIcon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text("\(level)%")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private var batteryIcon: String {
        switch level {
        case 0 ..< 13: "battery.0percent"
        case 13 ..< 38: "battery.25percent"
        case 38 ..< 63: "battery.50percent"
        case 63 ..< 88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

// MARK: - Segmented Picker Button

struct SegmentButton: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isSelected ? Color.black.opacity(0.1) : Color.clear)
            .cornerRadius(4)
    }
}
