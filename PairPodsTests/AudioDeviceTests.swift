//
//  AudioDeviceTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

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

struct BatteryInfoTests {
    @Test("displayLevel returns min of left and right when both present")
    func bothEarbuds() {
        let info = BatteryInfo(left: 80, right: 90, case_: nil, single: nil)
        #expect(info.displayLevel == 80)
    }

    @Test("displayLevel returns single when only single is present")
    func singleBattery() {
        let info = BatteryInfo(left: nil, right: nil, case_: nil, single: 75)
        #expect(info.displayLevel == 75)
    }

    @Test("displayLevel returns left when only left is reporting")
    func onlyLeftEarbud() {
        let info = BatteryInfo(left: 60, right: nil, case_: nil, single: nil)
        #expect(info.displayLevel == 60)
    }

    @Test("displayLevel returns right when only right is reporting")
    func onlyRightEarbud() {
        let info = BatteryInfo(left: nil, right: 55, case_: nil, single: nil)
        #expect(info.displayLevel == 55)
    }

    @Test("displayLevel returns nil when nothing is reporting")
    func nothingReporting() {
        let info = BatteryInfo(left: nil, right: nil, case_: nil, single: nil)
        #expect(info.displayLevel == nil)
    }

    @Test("displayLevel excludes case — only case reporting returns nil")
    func onlyCaseReporting() {
        let info = BatteryInfo(left: nil, right: nil, case_: 85, single: nil)
        #expect(info.displayLevel == nil)
    }

    @Test("BatteryInfo is Equatable")
    func equatable() {
        let a = BatteryInfo(left: 80, right: 90, case_: 50, single: nil)
        let b = BatteryInfo(left: 80, right: 90, case_: 50, single: nil)
        #expect(a == b)
    }
}
