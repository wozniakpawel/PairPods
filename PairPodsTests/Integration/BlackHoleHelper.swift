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

    static var isAvailable: Bool {
        get async {
            await discoverDevices() != nil
        }
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
}
