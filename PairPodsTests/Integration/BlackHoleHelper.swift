//
//  BlackHoleHelper.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods

enum BlackHoleHelper {
    struct BlackHoleDevices {
        let device2ch: AudioDevice
        let device16ch: AudioDevice
    }

    /// Synchronous check for use with Swift Testing `.enabled(if:)` trait.
    static var isAvailable: Bool {
        let deviceNames = fetchAllDeviceNames()
        return deviceNames.contains("BlackHole 2ch") && deviceNames.contains("BlackHole 16ch")
    }

    static func discoverDevices() async -> BlackHoleDevices? {
        let system = CoreAudioSystem()
        guard let devices = try? await system.fetchAllAudioDevices() else { return nil }
        guard let dev2ch = devices.first(where: { $0.name == "BlackHole 2ch" }),
              let dev16ch = devices.first(where: { $0.name == "BlackHole 16ch" })
        else { return nil }
        return BlackHoleDevices(device2ch: dev2ch, device16ch: dev16ch)
    }

    static func setSampleRate(on deviceID: AudioDeviceID, to rate: Double) -> Bool {
        deviceID.setSampleRate(rate)
    }

    // MARK: - Private

    private static func fetchAllDeviceNames() -> [String] {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &propSize) == noErr else {
            return []
        }

        let deviceCount = Int(propSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &propSize, &deviceIDs) == noErr else {
            return []
        }

        return deviceIDs.compactMap { $0.getStringProperty(selector: kAudioDevicePropertyDeviceNameCFString) }
    }
}
