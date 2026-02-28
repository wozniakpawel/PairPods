//
//  MockAudioSystem.swift
//  PairPodsTests
//

import CoreAudio
@testable import PairPods

final class MockAudioSystem: AudioSystemQuerying, AudioSystemCommanding, @unchecked Sendable {
    // MARK: - Configurable return values

    var devicesToReturn: [AudioDevice] = []
    var defaultDevice: (AudioDevice?, AudioDeviceID?) = (nil, nil)
    var deviceIDToReturn: AudioDeviceID?
    var createAggregateResult: Result<AudioDeviceID, Error> = .success(999)
    var destroyAggregateError: Error?
    var setDefaultOutputError: Error?
    var setSampleRateResult: Bool = true

    // MARK: - Call tracking

    struct CreateAggregateCall {
        let name: String
        let uid: String
        let masterUID: String
        let secondUID: String
    }

    struct SetSampleRateCall {
        let deviceID: AudioDeviceID
        let sampleRate: Double
    }

    var createAggregateCalls: [CreateAggregateCall] = []
    var destroyAggregateCalls: [AudioDeviceID] = []
    var setDefaultOutputCalls: [AudioDeviceID] = []
    var setSampleRateCalls: [SetSampleRateCall] = []
    var fetchAllDevicesCalls = 0
    var fetchDefaultOutputCalls = 0

    // MARK: - AudioSystemQuerying

    func fetchAllAudioDevices() async throws -> [AudioDevice] {
        fetchAllDevicesCalls += 1
        return devicesToReturn
    }

    func fetchDefaultOutputDevice() async -> (AudioDevice?, AudioDeviceID?) {
        fetchDefaultOutputCalls += 1
        return defaultDevice
    }

    func fetchDeviceID(deviceUID: String) async -> AudioDeviceID? {
        deviceIDToReturn
    }

    // MARK: - AudioSystemCommanding

    func createAggregateDevice(name: String, uid: String,
                               masterUID: String, secondUID: String) async throws -> AudioDeviceID
    {
        createAggregateCalls.append(CreateAggregateCall(
            name: name, uid: uid, masterUID: masterUID, secondUID: secondUID
        ))
        return try createAggregateResult.get()
    }

    func destroyAggregateDevice(deviceID: AudioDeviceID) async throws {
        destroyAggregateCalls.append(deviceID)
        if let error = destroyAggregateError {
            throw error
        }
    }

    func setDefaultOutputDevice(deviceID: AudioDeviceID) async throws {
        setDefaultOutputCalls.append(deviceID)
        if let error = setDefaultOutputError {
            throw error
        }
    }

    func setSampleRate(on deviceID: AudioDeviceID, to sampleRate: Double) -> Bool {
        setSampleRateCalls.append(SetSampleRateCall(deviceID: deviceID, sampleRate: sampleRate))
        return setSampleRateResult
    }
}
