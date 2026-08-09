//
//  AudioDeviceManagerRollbackTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

/// Rate alignment writes to the user's hardware, so the interesting cases are the ones
/// where something goes wrong afterwards and those writes have to come back off.
@Suite("Sample rate rollback and degraded mode")
struct AudioDeviceManagerRollbackTests {
    private let defaults = TestDefaults.make()

    @MainActor
    private func makeMockAndManager(_ devices: [AudioDevice]) -> (MockAudioSystem, AudioDeviceManager) {
        let mock = MockAudioSystem()
        mock.devicesToReturn = devices
        mock.nominalRates = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0.sampleRate) })
        mock.createAggregateResult = .success(999)
        let manager = AudioDeviceManager(audioSystem: mock, shouldShowAlerts: false, userDefaults: defaults)
        return (mock, manager)
    }

    private func mixedRatePair() -> [AudioDevice] {
        [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 44100, availableSampleRates: [44100, 48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000, availableSampleRates: [44100, 48000]),
        ]
    }

    @Test("A failed write rolls back the writes that already succeeded")
    @MainActor func partialWriteIsRolledBack() async {
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 44100, availableSampleRates: [44100, 48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 44100, availableSampleRates: [44100, 48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 3, uid: "c", sampleRate: 48000, availableSampleRates: [44100, 48000]),
        ]
        let (mock, manager) = makeMockAndManager(devices)
        // Target is 44100 (two devices already there); device 3 has to move and refuses.
        mock.rateWriteFailures = [3]

        let outcome = await manager.alignSampleRates(devices)

        #expect(outcome.isDegraded)
        #expect(mock.nominalRates[3] == 48000, "The device that refused must keep its own rate")
        #expect(mock.nominalRates[1] == 44100)
        #expect(mock.nominalRates[2] == 44100)
    }

    @Test("A device moved by alignment is put back when sharing stops")
    @MainActor func stoppingRestoresOriginalRates() async throws {
        let devices = mixedRatePair()
        let (mock, manager) = makeMockAndManager(devices)

        try await manager.setupMultiOutputDevice()
        // 48000 wins the tie on the higher rate, so device 1 moved.
        #expect(mock.nominalRates[1] == 48000)

        await manager.restoreOutputDevice()

        #expect(mock.nominalRates[1] == 44100, "Original rate must be restored on stop")
        #expect(mock.nominalRates[2] == 48000, "Untouched device must stay where it was")
    }

    @Test("Aggregate creation failure rolls the rates back")
    @MainActor func aggregateFailureRollsBack() async {
        let devices = mixedRatePair()
        let (mock, manager) = makeMockAndManager(devices)
        mock.createAggregateResult = .failure(AppError.operationError("boom"))

        let thrown = await errorThrown { try await manager.setupMultiOutputDevice() }
        #expect(thrown is AppError, "Expected an AppError, got \(String(describing: thrown))")

        #expect(mock.nominalRates[1] == 44100, "A failed setup must not leave hardware reconfigured")
    }

    @Test("Default output failure rolls the rates back")
    @MainActor func defaultOutputFailureRollsBack() async {
        let devices = mixedRatePair()
        let (mock, manager) = makeMockAndManager(devices)
        mock.setDefaultOutputError = AppError.operationError("boom")

        let thrown = await errorThrown { try await manager.setupMultiOutputDevice() }
        #expect(thrown is AppError, "Expected an AppError, got \(String(describing: thrown))")

        #expect(mock.nominalRates[1] == 44100)
    }

    @Test("A rate the user changed afterwards is left alone")
    @MainActor func doesNotClobberALaterChange() async throws {
        let devices = mixedRatePair()
        let (mock, manager) = makeMockAndManager(devices)

        try await manager.setupMultiOutputDevice()
        #expect(mock.nominalRates[1] == 48000)

        // Something outside PairPods moves the device after we aligned it.
        mock.nominalRates[1] = 96000

        await manager.restoreOutputDevice()

        #expect(mock.nominalRates[1] == 96000, "A later external change outranks our restore")
    }

    @Test("No common rate proceeds in a named degraded mode without writing anything")
    @MainActor func noCommonRateIsDegradedNotSilent() async throws {
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000, availableSampleRates: [48000]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 44100, availableSampleRates: [44100]),
        ]
        let (mock, manager) = makeMockAndManager(devices)

        try await manager.setupMultiOutputDevice()

        #expect(manager.lastAlignment?.isDegraded == true, "Mismatched rates must be reported, not hidden")
        #expect(mock.setSampleRateCalls.isEmpty, "Nothing is advertised by both devices, so nothing may be forced")
        // Sharing still happens: refusing would take a pairing that works imperfectly today
        // and make it not work at all.
        #expect(mock.createAggregateCalls.count == 1)
    }

    @Test("A device advertising a continuous range can be aligned within it")
    @MainActor func continuousRangeIsUsable() async {
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 96000,
                                                sampleRateRanges: [SampleRateRange(lower: 44100, upper: 96000)]),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000, availableSampleRates: [48000]),
        ]
        let (mock, manager) = makeMockAndManager(devices)

        let outcome = await manager.alignSampleRates(devices)

        #expect(outcome == .aligned(rate: 48000, changes: [
            SampleRateChange(deviceID: 1, deviceName: "BT Headphones", originalRate: 96000, appliedRate: 48000),
        ]))
        #expect(mock.nominalRates[1] == 48000)
    }

    @Test("A dead first clock does not prevent using a live second one")
    @MainActor func fallsForwardToTheSecondClock() async throws {
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000),
        ]
        let (mock, manager) = makeMockAndManager(devices)
        mock.clockDeviceUIDsToReturn = ["ATSAC:dead", "ATSAC:live"]
        mock.failAggregateForClockUIDs = ["ATSAC:dead"]

        try await manager.setupMultiOutputDevice()

        #expect(mock.createAggregateCalls.map(\.clockUID) == ["ATSAC:dead", "ATSAC:live"],
                "The second clock must be tried before giving up on external clocking")
        #expect(mock.createAggregateCalls.last?.clockUID == "ATSAC:live")
    }

    @Test("Every clock failing falls back to a master sub-device")
    @MainActor func fallsBackToMasterWhenAllClocksFail() async throws {
        let devices = [
            AudioDeviceFixtures.bluetoothDevice(id: 1, uid: "a", sampleRate: 48000),
            AudioDeviceFixtures.bluetoothDevice(id: 2, uid: "b", sampleRate: 48000),
        ]
        let (mock, manager) = makeMockAndManager(devices)
        mock.clockDeviceUIDsToReturn = ["ATSAC:dead1", "ATSAC:dead2"]
        mock.failAggregateForClockUIDs = ["ATSAC:dead1", "ATSAC:dead2"]

        try await manager.setupMultiOutputDevice()

        let last = try #require(mock.createAggregateCalls.last)
        #expect(last.clockUID == nil)
        #expect(last.subDeviceUIDs.contains(last.masterUID))
    }
}
