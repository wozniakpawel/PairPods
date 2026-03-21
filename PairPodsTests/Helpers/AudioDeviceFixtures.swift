//
//  AudioDeviceFixtures.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods

enum AudioDeviceFixtures {
    static func bluetoothDevice(
        id: AudioDeviceID = 100,
        uid: String = "bt-device-1",
        name: String = "BT Headphones",
        sampleRate: Double = 48000,
        batteryInfo: BatteryInfo? = nil
    ) -> AudioDevice {
        AudioDevice(
            id: id,
            uid: uid,
            name: name,
            transportType: kAudioDeviceTransportTypeBluetooth,
            isOutputDevice: true,
            sampleRate: sampleRate,
            batteryInfo: batteryInfo
        )
    }

    static func bluetoothLEDevice(
        id: AudioDeviceID = 200,
        uid: String = "btle-device-1",
        name: String = "BT LE Speaker",
        sampleRate: Double = 44100,
        batteryInfo: BatteryInfo? = nil
    ) -> AudioDevice {
        AudioDevice(
            id: id,
            uid: uid,
            name: name,
            transportType: kAudioDeviceTransportTypeBluetoothLE,
            isOutputDevice: true,
            sampleRate: sampleRate,
            batteryInfo: batteryInfo
        )
    }

    static func builtInSpeaker(
        id: AudioDeviceID = 300,
        uid: String = "builtin-speaker",
        name: String = "MacBook Pro Speakers",
        sampleRate: Double = 48000
    ) -> AudioDevice {
        AudioDevice(
            id: id,
            uid: uid,
            name: name,
            transportType: kAudioDeviceTransportTypeBuiltIn,
            isOutputDevice: true,
            sampleRate: sampleRate
        )
    }

    static func usbMicrophone(
        id: AudioDeviceID = 400,
        uid: String = "usb-mic-1",
        name: String = "USB Microphone",
        sampleRate: Double = 48000
    ) -> AudioDevice {
        AudioDevice(
            id: id,
            uid: uid,
            name: name,
            transportType: kAudioDeviceTransportTypeUSB,
            isOutputDevice: false,
            sampleRate: sampleRate
        )
    }

    static func usbOutputDevice(
        id: AudioDeviceID = 500,
        uid: String = "usb-output-1",
        name: String = "USB DAC",
        sampleRate: Double = 96000
    ) -> AudioDevice {
        AudioDevice(
            id: id,
            uid: uid,
            name: name,
            transportType: kAudioDeviceTransportTypeUSB,
            isOutputDevice: true,
            sampleRate: sampleRate
        )
    }
}
