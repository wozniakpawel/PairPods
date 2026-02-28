//
//  AudioDeviceTests.swift
//  PairPodsTests
//

import CoreAudio
import Testing
@testable import PairPods

@Suite("AudioDevice")
struct AudioDeviceTests {
    @Test("Bluetooth output device is compatible")
    func bluetoothOutputIsCompatible() {
        let device = AudioDeviceFixtures.bluetoothDevice()
        #expect(device.isCompatibleOutputDevice)
    }

    @Test("Bluetooth LE output device is compatible")
    func bluetoothLEOutputIsCompatible() {
        let device = AudioDeviceFixtures.bluetoothLEDevice()
        #expect(device.isCompatibleOutputDevice)
    }

    @Test("Built-in speaker is not compatible")
    func builtInSpeakerNotCompatible() {
        let device = AudioDeviceFixtures.builtInSpeaker()
        #expect(!device.isCompatibleOutputDevice)
    }

    @Test("USB output device is not compatible")
    func usbOutputNotCompatible() {
        let device = AudioDeviceFixtures.usbOutputDevice()
        #expect(!device.isCompatibleOutputDevice)
    }

    @Test("USB input-only device is not compatible")
    func usbInputOnlyNotCompatible() {
        let device = AudioDeviceFixtures.usbMicrophone()
        #expect(!device.isCompatibleOutputDevice)
    }

    @Test("Bluetooth input-only device is not compatible")
    func bluetoothInputOnlyNotCompatible() {
        let device = AudioDevice(
            id: 600,
            uid: "bt-mic",
            name: "BT Mic",
            transportType: kAudioDeviceTransportTypeBluetooth,
            isOutputDevice: false,
            sampleRate: 48000
        )
        #expect(!device.isCompatibleOutputDevice)
    }

    @Test("Transport type descriptions", arguments: [
        (kAudioDeviceTransportTypeBluetooth, "Bluetooth"),
        (kAudioDeviceTransportTypeBluetoothLE, "Bluetooth LE"),
        (kAudioDeviceTransportTypeBuiltIn, "Built-in"),
        (kAudioDeviceTransportTypeUSB, "USB"),
    ])
    func transportTypeDescription(transportType: UInt32, expected: String) {
        let device = AudioDevice(
            id: 1,
            uid: "test",
            name: "Test",
            transportType: transportType,
            isOutputDevice: true,
            sampleRate: 48000
        )
        #expect(device.description.contains(expected))
    }
}
