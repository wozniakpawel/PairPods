//
//  DeviceProfile.swift
//  PairPodsTests
//

import CoreAudio

struct DeviceProfile {
    let name: String
    let transportType: UInt32
    let nominalSampleRate: Double
    let toleratesRateChange: Bool
}

extension DeviceProfile {
    // Apple
    static let airPods1 = DeviceProfile(name: "AirPods 1st Gen", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let airPods2 = DeviceProfile(name: "AirPods 2nd Gen", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let airPods3 = DeviceProfile(name: "AirPods 3rd Gen", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let airPods4 = DeviceProfile(name: "AirPods 4", transportType: kAudioDeviceTransportTypeBluetoothLE, nominalSampleRate: 48000, toleratesRateChange: false)
    static let airPodsPro1 = DeviceProfile(name: "AirPods Pro 1", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let airPodsPro2 = DeviceProfile(name: "AirPods Pro 2", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let airPodsPro3 = DeviceProfile(name: "AirPods Pro 3", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let airPodsMax = DeviceProfile(name: "AirPods Max", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    // Third-party
    static let sonyXM5 = DeviceProfile(name: "Sony WH-1000XM5", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let galaxyBudsPro = DeviceProfile(name: "Samsung Galaxy Buds Pro", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let boseQCUltra = DeviceProfile(name: "Bose QC Ultra", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 48000, toleratesRateChange: true)
    static let genericBLEEarbuds = DeviceProfile(name: "Generic BLE Earbuds", transportType: kAudioDeviceTransportTypeBluetoothLE, nominalSampleRate: 44100, toleratesRateChange: false)
    static let genericBLESpeaker = DeviceProfile(name: "Generic BLE Speaker", transportType: kAudioDeviceTransportTypeBluetoothLE, nominalSampleRate: 44100, toleratesRateChange: false)
    static let cheapBTEarbuds = DeviceProfile(name: "Cheap BT Earbuds", transportType: kAudioDeviceTransportTypeBluetooth, nominalSampleRate: 44100, toleratesRateChange: false)
}
