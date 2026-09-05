//
//  MockAudioSystem.swift
//  PairPodsTests
//

import CoreAudio
import Foundation
@testable import PairPods

/// Thread-safe test double.
///
/// The lock is not decoration. `AudioDeviceManager.init` starts a `Task` that calls
/// `fetchAllAudioDevices()` while the test body is calling `setupMultiOutputDevice()`,
/// which calls it too, so both the configuration and the call counters are touched
/// from two threads at once. ThreadSanitizer catches this and aborts the whole test
/// process; before the lock, `@unchecked Sendable` was simply an unchecked lie.
final class MockAudioSystem: AudioSystemQuerying, AudioSystemCommanding, @unchecked Sendable {
    // MARK: - Call tracking types

    struct CreateAggregateCall {
        let name: String
        let uid: String
        let masterUID: String
        let subDeviceUIDs: [String]
        let clockUID: String?
    }

    struct SetSampleRateCall {
        let deviceID: AudioDeviceID
        let sampleRate: Double
    }

    /// Everything mutable lives here so one lock covers all of it.
    private struct State {
        var devicesToReturn: [AudioDevice] = []
        var defaultDevice: (AudioDevice?, AudioDeviceID?) = (nil, nil)
        var deviceIDToReturn: AudioDeviceID?
        var clockDeviceUIDsToReturn: [String] = []
        /// Nominal rate per device, so restore can be observed rather than assumed.
        var nominalRates: [AudioDeviceID: Double] = [:]
        /// Device IDs whose rate writes should fail, for partial-failure coverage.
        var rateWriteFailures: Set<AudioDeviceID> = []
        /// Clock UIDs for which aggregate creation should fail, so clock fallback is testable.
        var failAggregateForClockUIDs: Set<String> = []
        var createAggregateResult: Result<AudioDeviceID, Error> = .success(999)
        var destroyAggregateError: Error?
        var setDefaultOutputError: Error?
        var setSampleRateResult = true

        var createAggregateCalls: [CreateAggregateCall] = []
        var destroyAggregateCalls: [AudioDeviceID] = []
        var setDefaultOutputCalls: [AudioDeviceID] = []
        var setSampleRateCalls: [SetSampleRateCall] = []
        var fetchAllDevicesCalls = 0
        var fetchDefaultOutputCalls = 0
    }

    private let lock = NSLock()
    private var state = State()

    private func withState<T>(_ body: (inout State) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&state)
    }

    // MARK: - Configurable return values

    var devicesToReturn: [AudioDevice] {
        get { withState { $0.devicesToReturn } }
        set { withState { $0.devicesToReturn = newValue } }
    }

    var defaultDevice: (AudioDevice?, AudioDeviceID?) {
        get { withState { $0.defaultDevice } }
        set { withState { $0.defaultDevice = newValue } }
    }

    var deviceIDToReturn: AudioDeviceID? {
        get { withState { $0.deviceIDToReturn } }
        set { withState { $0.deviceIDToReturn = newValue } }
    }

    var clockDeviceUIDsToReturn: [String] {
        get { withState { $0.clockDeviceUIDsToReturn } }
        set { withState { $0.clockDeviceUIDsToReturn = newValue } }
    }

    var nominalRates: [AudioDeviceID: Double] {
        get { withState { $0.nominalRates } }
        set { withState { $0.nominalRates = newValue } }
    }

    var rateWriteFailures: Set<AudioDeviceID> {
        get { withState { $0.rateWriteFailures } }
        set { withState { $0.rateWriteFailures = newValue } }
    }

    var failAggregateForClockUIDs: Set<String> {
        get { withState { $0.failAggregateForClockUIDs } }
        set { withState { $0.failAggregateForClockUIDs = newValue } }
    }

    var createAggregateResult: Result<AudioDeviceID, Error> {
        get { withState { $0.createAggregateResult } }
        set { withState { $0.createAggregateResult = newValue } }
    }

    var destroyAggregateError: Error? {
        get { withState { $0.destroyAggregateError } }
        set { withState { $0.destroyAggregateError = newValue } }
    }

    var setDefaultOutputError: Error? {
        get { withState { $0.setDefaultOutputError } }
        set { withState { $0.setDefaultOutputError = newValue } }
    }

    var setSampleRateResult: Bool {
        get { withState { $0.setSampleRateResult } }
        set { withState { $0.setSampleRateResult = newValue } }
    }

    // MARK: - Call tracking

    var createAggregateCalls: [CreateAggregateCall] {
        withState { $0.createAggregateCalls }
    }

    var destroyAggregateCalls: [AudioDeviceID] {
        withState { $0.destroyAggregateCalls }
    }

    var setDefaultOutputCalls: [AudioDeviceID] {
        withState { $0.setDefaultOutputCalls }
    }

    var setSampleRateCalls: [SetSampleRateCall] {
        withState { $0.setSampleRateCalls }
    }

    var fetchAllDevicesCalls: Int {
        withState { $0.fetchAllDevicesCalls }
    }

    var fetchDefaultOutputCalls: Int {
        withState { $0.fetchDefaultOutputCalls }
    }

    /// The tracking arrays are read-only so nothing can mutate them off-lock; tests
    /// that need a clean slate mid-scenario clear them through here.
    func clearRecordedCalls() {
        withState {
            $0.createAggregateCalls.removeAll()
            $0.destroyAggregateCalls.removeAll()
            $0.setDefaultOutputCalls.removeAll()
            $0.setSampleRateCalls.removeAll()
        }
    }

    // MARK: - AudioSystemQuerying

    func fetchAllAudioDevices() async throws -> [AudioDevice] {
        withState {
            $0.fetchAllDevicesCalls += 1
            return $0.devicesToReturn
        }
    }

    func fetchDefaultOutputDevice() async -> (AudioDevice?, AudioDeviceID?) {
        withState {
            $0.fetchDefaultOutputCalls += 1
            return $0.defaultDevice
        }
    }

    func fetchDeviceID(deviceUID _: String) async -> AudioDeviceID? {
        withState { $0.deviceIDToReturn }
    }

    func fetchClockDeviceUIDs() async -> [String] {
        withState { $0.clockDeviceUIDsToReturn }
    }

    func fetchNominalSampleRate(on deviceID: AudioDeviceID) async -> Double? {
        withState { $0.nominalRates[deviceID] }
    }

    // MARK: - AudioSystemCommanding

    func createAggregateDevice(name: String, uid: String, masterUID: String,
                               subDeviceUIDs: [String], clockUID: String?) async throws -> AudioDeviceID
    {
        let result: Result<AudioDeviceID, Error> = withState {
            $0.createAggregateCalls.append(CreateAggregateCall(
                name: name, uid: uid, masterUID: masterUID, subDeviceUIDs: subDeviceUIDs, clockUID: clockUID
            ))
            if let clockUID, $0.failAggregateForClockUIDs.contains(clockUID) {
                return .failure(AppError.operationError("Clock \(clockUID) rejected"))
            }
            return $0.createAggregateResult
        }
        return try result.get()
    }

    func destroyAggregateDevice(deviceID: AudioDeviceID) async throws {
        let error = withState {
            $0.destroyAggregateCalls.append(deviceID)
            return $0.destroyAggregateError
        }
        if let error {
            throw error
        }
    }

    func setDefaultOutputDevice(deviceID: AudioDeviceID) async throws {
        let error = withState {
            $0.setDefaultOutputCalls.append(deviceID)
            return $0.setDefaultOutputError
        }
        if let error {
            throw error
        }
    }

    func setSampleRate(on deviceID: AudioDeviceID, to sampleRate: Double) async -> Bool {
        withState {
            $0.setSampleRateCalls.append(SetSampleRateCall(deviceID: deviceID, sampleRate: sampleRate))
            guard $0.setSampleRateResult, !$0.rateWriteFailures.contains(deviceID) else { return false }
            $0.nominalRates[deviceID] = sampleRate
            return true
        }
    }
}
