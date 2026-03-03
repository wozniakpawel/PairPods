//
//  SimulatedAudioSystem.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods

final class SimulatedAudioSystem: AudioSystemQuerying, AudioSystemCommanding, @unchecked Sendable {
    let realSystem = CoreAudioSystem()
    let profileA: DeviceProfile
    let profileB: DeviceProfile
    let blackHoleA: AudioDevice // real BlackHole 2ch device
    let blackHoleB: AudioDevice // real BlackHole 16ch device

    /// Simulated AudioDevice values using BlackHole UIDs but profile metadata
    var simulatedDeviceA: AudioDevice {
        AudioDevice(
            id: blackHoleA.id,
            uid: blackHoleA.uid,
            name: profileA.name,
            transportType: profileA.transportType,
            isOutputDevice: true,
            sampleRate: profileA.nominalSampleRate
        )
    }

    var simulatedDeviceB: AudioDevice {
        AudioDevice(
            id: blackHoleB.id,
            uid: blackHoleB.uid,
            name: profileB.name,
            transportType: profileB.transportType,
            isOutputDevice: true,
            sampleRate: profileB.nominalSampleRate
        )
    }

    /// Call tracking
    struct SetSampleRateCall {
        let deviceID: AudioDeviceID
        let sampleRate: Double
        let profile: DeviceProfile
    }

    struct CreateAggregateCall {
        let masterUID: String
        let subDeviceUIDs: [String]
    }

    var setSampleRateCalls: [SetSampleRateCall] = []
    var createAggregateCalls: [CreateAggregateCall] = []

    init(profileA: DeviceProfile, profileB: DeviceProfile, blackHoleA: AudioDevice, blackHoleB: AudioDevice) {
        self.profileA = profileA
        self.profileB = profileB
        self.blackHoleA = blackHoleA
        self.blackHoleB = blackHoleB
    }

    // MARK: - AudioSystemQuerying

    func fetchAllAudioDevices() async throws -> [AudioDevice] {
        [simulatedDeviceA, simulatedDeviceB]
    }

    func fetchDefaultOutputDevice() async -> (AudioDevice?, AudioDeviceID?) {
        await realSystem.fetchDefaultOutputDevice()
    }

    func fetchDeviceID(deviceUID: String) async -> AudioDeviceID? {
        await realSystem.fetchDeviceID(deviceUID: deviceUID)
    }

    // MARK: - AudioSystemCommanding

    func createAggregateDevice(name: String, uid: String,
                               masterUID: String, subDeviceUIDs: [String]) async throws -> AudioDeviceID
    {
        createAggregateCalls.append(CreateAggregateCall(masterUID: masterUID, subDeviceUIDs: subDeviceUIDs))
        return try await realSystem.createAggregateDevice(name: name, uid: uid, masterUID: masterUID, subDeviceUIDs: subDeviceUIDs)
    }

    func destroyAggregateDevice(deviceID: AudioDeviceID) async throws {
        try await realSystem.destroyAggregateDevice(deviceID: deviceID)
    }

    func setDefaultOutputDevice(deviceID: AudioDeviceID) async throws {
        try await realSystem.setDefaultOutputDevice(deviceID: deviceID)
    }

    func setSampleRate(on deviceID: AudioDeviceID, to sampleRate: Double) -> Bool {
        let profile = (deviceID == blackHoleA.id) ? profileA : profileB
        setSampleRateCalls.append(SetSampleRateCall(deviceID: deviceID, sampleRate: sampleRate, profile: profile))
        guard profile.toleratesRateChange else { return false }
        return realSystem.setSampleRate(on: deviceID, to: sampleRate)
    }

    // MARK: - Helpers

    /// Returns true if any setSampleRate call targeted a profile that doesn't tolerate rate changes.
    var attemptedRateChangeOnIntolerantDevice: Bool {
        setSampleRateCalls.contains { !$0.profile.toleratesRateChange }
    }

    /// Descriptive messages for rate change violations.
    var rateChangeViolations: [String] {
        setSampleRateCalls
            .filter { !$0.profile.toleratesRateChange }
            .map { "Code attempted setSampleRate on BLE device '\($0.profile.name)' which does not tolerate rate changes" }
    }
}
