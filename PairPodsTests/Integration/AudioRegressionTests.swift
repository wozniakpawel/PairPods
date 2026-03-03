//
//  AudioRegressionTests.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods
import Testing

@Suite("Audio Regression Tests")
struct AudioRegressionTests {
    @Test("Same-rate BT Classic — AirPods Pro 2 + Sony XM5")
    @MainActor func sameRateBTClassic() async throws {
        try await runDevicePairTest(profileA: .airPodsPro2, profileB: .sonyXM5)
    }

    @Test("Mixed-rate BLE slave — AirPods Pro 2 + Generic BLE earbuds")
    @MainActor func mixedRateBLESlave() async throws {
        try await runDevicePairTest(profileA: .airPodsPro2, profileB: .genericBLEEarbuds)
    }

    @Test("Mixed-rate BLE master — AirPods 4 + Cheap BT earbuds")
    @MainActor func mixedRateBLEMaster() async throws {
        try await runDevicePairTest(profileA: .airPods4, profileB: .cheapBTEarbuds)
    }

    @Test("Both BLE same rate — AirPods 4 + AirPods 4")
    @MainActor func bothBLESameRate() async throws {
        try await runDevicePairTest(profileA: .airPods4, profileB: .airPods4)
    }

    @Test("Both BLE diff rate — AirPods 4 + Generic BLE earbuds")
    @MainActor func bothBLEDiffRate() async throws {
        try await runDevicePairTest(profileA: .airPods4, profileB: .genericBLEEarbuds)
    }

    @Test("BT Classic mixed rate — AirPods 1 + Cheap BT earbuds")
    @MainActor func btClassicMixedRate() async throws {
        try await runDevicePairTest(profileA: .airPods1, profileB: .cheapBTEarbuds)
    }

    @Test("Three devices — Pro 2 + AirPods 4 + Generic BLE")
    @MainActor func threeDevices() async throws {
        // Limited by having only 2 BlackHole drivers — test the most critical pair
        try await runDevicePairTest(profileA: .airPodsPro2, profileB: .airPods4)
    }

    // MARK: - Test Helper

    @MainActor
    private func runDevicePairTest(profileA: DeviceProfile, profileB: DeviceProfile) async throws {
        // 1. Skip if BlackHole unavailable
        let blackHoleDevices = try #require(
            await BlackHoleHelper.discoverDevices(),
            "BlackHole 2ch and 16ch must be installed (brew install --cask blackhole-2ch blackhole-16ch)"
        )

        // 2. Configure BlackHole devices to match profile sample rates
        let rateSetA = BlackHoleHelper.setSampleRate(on: blackHoleDevices.device2ch.id, to: profileA.nominalSampleRate)
        let rateSetB = BlackHoleHelper.setSampleRate(on: blackHoleDevices.device16ch.id, to: profileB.nominalSampleRate)
        #expect(rateSetA, "Failed to set BlackHole 2ch sample rate to \(profileA.nominalSampleRate)")
        #expect(rateSetB, "Failed to set BlackHole 16ch sample rate to \(profileB.nominalSampleRate)")

        // Brief pause for CoreAudio to settle after rate change
        try await Task.sleep(for: .milliseconds(500))

        // 3. Create SimulatedAudioSystem
        let simulatedSystem = SimulatedAudioSystem(
            profileA: profileA,
            profileB: profileB,
            blackHoleA: blackHoleDevices.device2ch,
            blackHoleB: blackHoleDevices.device16ch
        )

        // 4. Save current default output to restore later
        let (_, originalDefaultID) = await CoreAudioSystem().fetchDefaultOutputDevice()

        // 5. Create AudioDeviceManager and set up multi-output device
        let manager = AudioDeviceManager(audioSystem: simulatedSystem, shouldShowAlerts: false)
        defer {
            Task { @MainActor in
                await manager.cleanup()
                // Restore original output device
                if let originalID = originalDefaultID {
                    try? await CoreAudioSystem().setDefaultOutputDevice(deviceID: originalID)
                }
            }
        }

        do {
            try await manager.setupMultiOutputDevice()
        } catch {
            Issue.record("setupMultiOutputDevice() failed: \(error)")
            return
        }

        // 6. Check for BLE rate change violations
        if simulatedSystem.attemptedRateChangeOnIntolerantDevice {
            for violation in simulatedSystem.rateChangeViolations {
                Issue.record(Comment(rawValue: violation))
            }
            // Clean up before returning
            await manager.removeMultiOutputDevice()
            if let originalID = originalDefaultID {
                try? await CoreAudioSystem().setDefaultOutputDevice(deviceID: originalID)
            }
            return
        }

        // 7. Find the aggregate device to use as output for validation
        guard let aggregateDeviceID = await simulatedSystem.fetchDeviceID(deviceUID: "PairPodsOutputDevice") else {
            Issue.record("Could not find aggregate device after setup")
            return
        }

        // 8. Run AudioLoopbackValidator
        let validator = AudioLoopbackValidator(
            outputDeviceID: aggregateDeviceID,
            captureDeviceName: "BlackHole 2ch",
            durationSeconds: 30
        )

        let result: ValidationResult
        do {
            result = try await validator.validate()
        } catch {
            Issue.record("AudioLoopbackValidator threw: \(error)")
            return
        }

        // 9. Assert validation passed
        if !result.passed {
            var message = "Audio regression test failed for \(profileA.name) + \(profileB.name)"
            if let desc = result.failureDescription {
                message += ": \(desc)"
            }
            if let artifact = result.artifactPath {
                message += "\nArtifact saved to: \(artifact)"
            }
            if let freq = result.detectedFrequency {
                message += "\nDetected frequency: \(String(format: "%.1f", freq)) Hz"
            }
            if !result.silenceIntervals.isEmpty {
                message += "\nSilence intervals:"
                for interval in result.silenceIntervals {
                    message += "\n  \(String(format: "%.2f", interval.startSeconds))s - \(String(format: "%.2f", interval.startSeconds + interval.durationSeconds))s (\(String(format: "%.2f", interval.durationSeconds))s)"
                }
            }
            Issue.record(Comment(rawValue: message))
        }

        #expect(result.passed, "Audio validation failed for \(profileA.name) + \(profileB.name)")
    }
}
