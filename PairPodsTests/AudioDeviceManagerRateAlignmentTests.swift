//
//  AudioDeviceManagerRateAlignmentTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

/// Covers the rate alignment introduced to address the pitch shifting in #35, and the
/// guard that keeps it from repeating the v0.4 dropout regression (#39): a device is
/// only ever written a rate it advertises.
@Suite("Sample rate alignment")
struct AudioDeviceManagerRateAlignmentTests {
    private func makeManager(_ mock: MockAudioSystem) async -> AudioDeviceManager {
        let manager = await AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false)
        await manager.cleanup()
        return manager
    }

    @Test("Devices already at the same rate are never written to")
    @MainActor func sameRateWritesNothing() async {
        let mock = MockAudioSystem()
        let manager = await makeManager(mock)

        await manager.alignSampleRates([
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000, availableSampleRates: [44100, 48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000, availableSampleRates: [44100, 48000]),
        ])

        #expect(mock.setSampleRateCalls.isEmpty)
    }

    @Test("Mixed rates align onto the rate the majority already runs")
    @MainActor func alignsToMajorityRate() async {
        let mock = MockAudioSystem()
        let manager = await makeManager(mock)

        // Two devices already at 48k, one straggler at 44.1k that can reach 48k.
        await manager.alignSampleRates([
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000, availableSampleRates: [44100, 48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000, availableSampleRates: [44100, 48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 44100, availableSampleRates: [44100, 48000]),
        ])

        // Only the straggler moves. The majority is left alone.
        #expect(mock.setSampleRateCalls.count == 1)
        #expect(mock.setSampleRateCalls.first?.deviceID == 3)
        #expect(mock.setSampleRateCalls.first?.sampleRate == 48000)
    }

    @Test("Aligns onto the only rate both devices advertise, even if neither runs it")
    @MainActor func alignsToTheOnlySharedRate() async {
        let mock = MockAudioSystem()
        let manager = await makeManager(mock)

        await manager.alignSampleRates([
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000, availableSampleRates: [48000, 88200]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 44100, availableSampleRates: [44100, 48000]),
        ])

        // 48000 is the only rate in common, and device 1 already has it.
        #expect(mock.setSampleRateCalls.count == 1)
        #expect(mock.setSampleRateCalls.first?.deviceID == 2)
        #expect(mock.setSampleRateCalls.first?.sampleRate == 48000)
    }

    @Test("No common rate means nothing is written, the mismatch is left to be logged")
    @MainActor func noCommonRateWritesNothing() async {
        let mock = MockAudioSystem()
        let manager = await makeManager(mock)

        // The pair that only a software resampler could fix: each locked to its own rate.
        await manager.alignSampleRates([
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000, availableSampleRates: [48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 44100, availableSampleRates: [44100]),
        ])

        #expect(mock.setSampleRateCalls.isEmpty, "Forcing a rate here is exactly the v0.4 regression")
    }

    @Test("Devices reporting no advertised rates are never written to")
    @MainActor func unknownAvailableRatesWritesNothing() async {
        let mock = MockAudioSystem()
        let manager = await makeManager(mock)

        await manager.alignSampleRates([
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 44100),
        ])

        #expect(mock.setSampleRateCalls.isEmpty)
    }

    @Test("Every written rate is one the target device advertises")
    @MainActor func neverWritesAnUnadvertisedRate() async {
        let mock = MockAudioSystem()
        let manager = await makeManager(mock)

        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 96000, availableSampleRates: [44100, 48000, 96000]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 44100, availableSampleRates: [44100, 48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 48000, availableSampleRates: [48000]),
        ]
        await manager.alignSampleRates(devices)

        for call in mock.setSampleRateCalls {
            let target = devices.first { $0.id == call.deviceID }
            #expect(target?.availableSampleRates.contains(call.sampleRate) == true,
                    "Wrote \(call.sampleRate)Hz to a device advertising \(target?.availableSampleRates ?? [])")
        }
    }
}
