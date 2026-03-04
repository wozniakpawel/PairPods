//
//  AudioRegressionTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

private let blackHoleRequired = ConditionTrait.enabled(
    if: BlackHoleHelper.isAvailable,
    "BlackHole 2ch and 16ch must be installed (brew install --cask blackhole-2ch blackhole-16ch)"
)

@Suite("Audio Regression Tests", .serialized)
struct AudioRegressionTests {
    @Test("Same-rate BT Classic — AirPods Pro 2 + Sony XM5", blackHoleRequired)
    @MainActor func sameRateBTClassic() async throws {
        try await runDevicePairTest(profileA: .airPodsPro2, profileB: .sonyXM5)
    }

    @Test("Mixed-rate BLE slave — AirPods Pro 2 + Generic BLE earbuds", blackHoleRequired)
    @MainActor func mixedRateBLESlave() async throws {
        try await runDevicePairTest(profileA: .airPodsPro2, profileB: .genericBLEEarbuds)
    }

    @Test("Mixed-rate BLE master — AirPods 4 + Cheap BT earbuds", blackHoleRequired)
    @MainActor func mixedRateBLEMaster() async throws {
        try await runDevicePairTest(profileA: .airPods4, profileB: .cheapBTEarbuds)
    }

    @Test("Both BLE same rate — AirPods 4 + AirPods 4", blackHoleRequired)
    @MainActor func bothBLESameRate() async throws {
        try await runDevicePairTest(profileA: .airPods4, profileB: .airPods4)
    }

    @Test("Both BLE diff rate — AirPods 4 + Generic BLE earbuds", blackHoleRequired)
    @MainActor func bothBLEDiffRate() async throws {
        try await runDevicePairTest(profileA: .airPods4, profileB: .genericBLEEarbuds)
    }

    @Test("BT Classic mixed rate — AirPods 1 + Cheap BT earbuds", blackHoleRequired)
    @MainActor func btClassicMixedRate() async throws {
        try await runDevicePairTest(profileA: .airPods1, profileB: .cheapBTEarbuds)
    }

    @Test("Three devices — Pro 2 + AirPods 4 + Generic BLE", blackHoleRequired)
    @MainActor func threeDevices() async throws {
        try await runDevicePairTest(profileA: .airPodsPro2, profileB: .airPods4)
    }

    // MARK: - Test Helper

    @MainActor
    private func runDevicePairTest(profileA: DeviceProfile, profileB: DeviceProfile) async throws {
        // 1. Discover BlackHole devices
        let blackHoleDevices = try #require(await BlackHoleHelper.discoverDevices())

        // 2. Configure BlackHole devices to match profile sample rates
        let rateSetA = BlackHoleHelper.setSampleRate(on: blackHoleDevices.device2ch.id, to: profileA.nominalSampleRate)
        let rateSetB = BlackHoleHelper.setSampleRate(on: blackHoleDevices.device16ch.id, to: profileB.nominalSampleRate)
        #expect(rateSetA, "Failed to set BlackHole 2ch sample rate to \(profileA.nominalSampleRate)")
        #expect(rateSetB, "Failed to set BlackHole 16ch sample rate to \(profileB.nominalSampleRate)")

        // Brief pause for CoreAudio to settle after rate change
        try await Task.sleep(for: .milliseconds(200))

        // 3. Create SimulatedAudioSystem
        let simulatedSystem = SimulatedAudioSystem(
            profileA: profileA,
            profileB: profileB,
            blackHoleA: blackHoleDevices.device2ch,
            blackHoleB: blackHoleDevices.device16ch
        )

        // 4. Save current default output to restore later
        let (_, originalDefaultID) = await CoreAudioSystem().fetchDefaultOutputDevice()

        // 5. Create AudioDeviceManager.
        //    The init launches an async task that calls removeMultiOutputDevice().
        //    We immediately call cleanup() to cancel that task and remove the
        //    property listener so it cannot race with our test setup.
        let manager = AudioDeviceManager(audioSystem: simulatedSystem, shouldShowAlerts: false)
        await manager.cleanup()

        do {
            try await manager.setupMultiOutputDevice()
        } catch {
            Issue.record("setupMultiOutputDevice() failed: \(error)")
            return
        }

        // 6. REGRESSION CHECK: No setSampleRate calls should have been made
        //    The v0.5.1 fix removed all setSampleRate forcing. If this fires,
        //    someone re-introduced the regression.
        #expect(
            simulatedSystem.setSampleRateCalls.isEmpty,
            "Code called setSampleRate \(simulatedSystem.setSampleRateCalls.count) time(s) — this is the v0.5.1 regression"
        )

        if simulatedSystem.attemptedRateChangeOnIntolerantDevice {
            for violation in simulatedSystem.rateChangeViolations {
                Issue.record(Comment(rawValue: violation))
            }
        }

        // 7. Verify aggregate was created with correct sub-device UIDs
        #expect(simulatedSystem.createAggregateCalls.count == 1, "Expected exactly 1 createAggregateDevice call")
        if let call = simulatedSystem.createAggregateCalls.first {
            let expectedUIDs = Set([blackHoleDevices.device2ch.uid, blackHoleDevices.device16ch.uid])
            let actualUIDs = Set(call.subDeviceUIDs)
            #expect(actualUIDs == expectedUIDs, "Sub-device UIDs mismatch: expected \(expectedUIDs), got \(actualUIDs)")

            // 8. Verify master device is the highest-sample-rate device
            let expectedMasterUID = profileA.nominalSampleRate >= profileB.nominalSampleRate
                ? blackHoleDevices.device2ch.uid
                : blackHoleDevices.device16ch.uid
            #expect(call.masterUID == expectedMasterUID,
                    "Master UID mismatch: expected \(expectedMasterUID), got \(call.masterUID)")
        }

        // 9. Cleanup: destroy aggregate and restore the original default output device.
        await manager.removeMultiOutputDevice()
        if let originalID = originalDefaultID {
            try? await CoreAudioSystem().setDefaultOutputDevice(deviceID: originalID)
        }
    }
}
