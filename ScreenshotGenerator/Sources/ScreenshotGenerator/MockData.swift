import SwiftUI

struct MockDevice {
    let name: String
    let sampleRate: Double
    let batteryLevel: Int?
    let volume: Float
    let isSelected: Bool
    let isMaster: Bool

    var iconSymbol: String {
        let lowered = name.lowercased()
        if lowered.contains("airpod") {
            if lowered.contains("max") {
                return "airpodsmax"
            } else if lowered.contains("pro") {
                return "airpodspro"
            } else {
                return "airpods"
            }
        } else if lowered.contains("bluetooth") || lowered.contains("wireless") {
            return "headphones"
        }
        return "speaker.wave.2"
    }

    var formattedSampleRate: String {
        String(format: "%.1f kHz", sampleRate / 1000)
    }

    var volumePercent: Int {
        Int(volume * 100)
    }
}

struct ScreenshotPreset {
    let devices: [MockDevice]
    let isSharingAudio: Bool
}

/// Step 1: Connect your devices — all connected, default state
let step1Preset = ScreenshotPreset(
    devices: [
        MockDevice(name: "Your AirPods Pro", sampleRate: 48000, batteryLevel: 80, volume: 0.5, isSelected: true, isMaster: true),
        MockDevice(name: "Friend's AirPods", sampleRate: 48000, batteryLevel: 60, volume: 0.5, isSelected: true, isMaster: false),
        MockDevice(name: "Living Room HomePod", sampleRate: 48000, batteryLevel: nil, volume: 0.5, isSelected: true, isMaster: false),
    ],
    isSharingAudio: false
)

/// Step 2: Customize — change master, adjust volumes, deselect a device
let step2Preset = ScreenshotPreset(
    devices: [
        MockDevice(name: "Your AirPods Pro", sampleRate: 48000, batteryLevel: 80, volume: 0.75, isSelected: true, isMaster: false),
        MockDevice(name: "Friend's AirPods", sampleRate: 48000, batteryLevel: 60, volume: 0.4, isSelected: true, isMaster: true),
        MockDevice(name: "Living Room HomePod", sampleRate: 48000, batteryLevel: nil, volume: 0.5, isSelected: false, isMaster: false),
    ],
    isSharingAudio: false
)

/// Step 3: Share — toggle sharing on
let step3Preset = ScreenshotPreset(
    devices: [
        MockDevice(name: "Your AirPods Pro", sampleRate: 48000, batteryLevel: 80, volume: 0.75, isSelected: true, isMaster: false),
        MockDevice(name: "Friend's AirPods", sampleRate: 48000, batteryLevel: 60, volume: 0.4, isSelected: true, isMaster: true),
        MockDevice(name: "Living Room HomePod", sampleRate: 48000, batteryLevel: nil, volume: 0.5, isSelected: false, isMaster: false),
    ],
    isSharingAudio: true
)
