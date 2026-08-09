//
//  SampleRateAlignment.swift
//  PairPods
//

import CoreAudio
import Foundation

// MARK: - Sample Rate Alignment Types

/// One nominal rate change this app applied, kept so it can be undone.
struct SampleRateChange: Equatable, Sendable {
    let deviceID: AudioDeviceID
    let deviceName: String
    let originalRate: Double
    let appliedRate: Double
}

/// What happened when the selected devices were brought onto a common nominal rate.
///
/// `degraded` is a first-class outcome rather than a silent fallback: CoreAudio expects
/// an aggregate's sub-devices to share a nominal rate, so a pairing that cannot be
/// aligned still shares audio but with artefacts that no amount of drift compensation
/// removes. Naming it lets the caller log it, surface it, and test it.
enum SampleRateAlignment: Equatable {
    case alreadyAligned(Double)
    case aligned(rate: Double, changes: [SampleRateChange])
    case degraded(reason: String)

    /// Changes that are currently applied to hardware and would need undoing.
    var appliedChanges: [SampleRateChange] {
        if case let .aligned(_, changes) = self {
            return changes
        }
        return []
    }

    var isDegraded: Bool {
        if case .degraded = self {
            return true
        }
        return false
    }
}

// MARK: - Device Selection and Sample Rate Alignment

/// Kept in an extension so it stays out of the main class body, which is already
/// at the size the linter is willing to accept.
extension AudioDeviceManager {
    /// Brings every selected device onto one nominal rate, transactionally.
    ///
    /// Every write is recorded so it can be undone, and a failure part-way through rolls
    /// back the writes already applied rather than leaving the user's devices in a state
    /// nobody chose. Devices that already agree are never written to at all.
    ///
    /// The outcome is returned rather than swallowed: an aggregate whose sub-devices run
    /// at different rates is a degraded configuration, not a normal one, and the caller
    /// has to be able to say so.
    func alignSampleRates(_ devices: [AudioDevice]) async -> SampleRateAlignment {
        let currentRates = Set(devices.map(\.sampleRate))
        let summary = devices
            .map { "\($0.name): \($0.sampleRate)Hz of \($0.supportedSampleRates)" }
            .joined(separator: " | ")

        if let single = currentRates.first, currentRates.count == 1 {
            return .alreadyAligned(single)
        }

        guard let target = bestTargetRate(for: devices, currentRates: currentRates) else {
            let reason = "no rate is supported by every selected device"
            logWarning("Cannot align sample rates: \(reason). Pitch artefacts are unavoidable for this pairing. \(summary)")
            return .degraded(reason: reason)
        }

        logInfo("Aligning selected devices to \(target)Hz. \(summary)")
        var applied: [SampleRateChange] = []
        for device in devices where device.sampleRate != target {
            guard await audioSystem.setSampleRate(on: device.id, to: target) else {
                let reason = "'\(device.name)' did not accept \(target)Hz"
                logWarning("Alignment failed: \(reason). Rolling back \(applied.count) earlier change(s).")
                await restoreSampleRates(applied)
                return .degraded(reason: reason)
            }
            applied.append(SampleRateChange(
                deviceID: device.id,
                deviceName: device.name,
                originalRate: device.sampleRate,
                appliedRate: target
            ))
            logInfo("Aligned '\(device.name)' from \(device.sampleRate)Hz to \(target)Hz")
        }
        return .aligned(rate: target, changes: applied)
    }

    /// Puts back the nominal rates this app changed.
    ///
    /// A device is only restored when it still reads back the value we wrote. Anything
    /// else means the user or the system moved it since, and their choice wins.
    func restoreSampleRates(_ changes: [SampleRateChange]) async {
        for change in changes.reversed() {
            let current = await audioSystem.fetchNominalSampleRate(on: change.deviceID)
            guard current == change.appliedRate else {
                let observed = current.map { "\($0)Hz" } ?? "an unreadable rate"
                logInfo("Not restoring '\(change.deviceName)': it is at \(observed), not the \(change.appliedRate)Hz we set")
                continue
            }
            if await audioSystem.setSampleRate(on: change.deviceID, to: change.originalRate) {
                logInfo("Restored '\(change.deviceName)' to \(change.originalRate)Hz")
            } else {
                logWarning("Could not restore '\(change.deviceName)' to \(change.originalRate)Hz")
            }
        }
    }

    /// Picks the rate that moves the fewest devices, breaking ties on the highest rate.
    ///
    /// Candidates are the rates the devices already run plus every discrete rate any of
    /// them advertises; a device advertising a continuous range contributes no candidate
    /// of its own but can satisfy anyone else's.
    private func bestTargetRate(for devices: [AudioDevice], currentRates: Set<Double>) -> Double? {
        var candidates = currentRates
        for device in devices {
            for range in device.supportedSampleRates where range.isDiscrete {
                candidates.insert(range.lower)
            }
        }

        let viable = candidates.filter { candidate in
            devices.allSatisfy { device in
                device.supportedSampleRates.contains { $0.contains(candidate) }
            }
        }

        return viable.max { a, b in
            let countA = devices.count(where: { $0.sampleRate == a })
            let countB = devices.count(where: { $0.sampleRate == b })
            return countA == countB ? a < b : countA < countB
        }
    }

    func selectDevicesForSharing(_ devices: [AudioDevice]) -> [AudioDevice] {
        // If user has defined a preferred order, use it (first device = master clock)
        let userOrder = loadDeviceOrder()
        if !userOrder.isEmpty {
            let sorted = devices.sorted { a, b in
                let ai = userOrder.firstIndex(of: a.uid) ?? Int.max
                let bi = userOrder.firstIndex(of: b.uid) ?? Int.max
                if ai != bi {
                    return ai < bi
                }
                return a.name < b.name
            }
            let names = sorted.map { "\($0.name) (\($0.sampleRate)Hz)" }.joined(separator: ", ")
            logInfo("Selected devices for sharing (user order) - \(names)")
            return sorted
        }

        // Fallback: find the most common sample rate among the devices
        var rateCount: [Double: Int] = [:]
        for device in devices {
            rateCount[device.sampleRate, default: 0] += 1
        }
        let maxCount = rateCount.values.max() ?? 0
        let hasClearMajority = rateCount.values.count(where: { $0 == maxCount }) == 1
        let majorityRate = hasClearMajority ? rateCount.first(where: { $0.value == maxCount })?.key : nil

        // Sort: when a clear majority exists, those devices go first; otherwise sort descending by rate
        let sorted = devices.sorted { a, b in
            if let majorityRate {
                let aMatches = a.sampleRate == majorityRate
                let bMatches = b.sampleRate == majorityRate
                if aMatches != bMatches {
                    return aMatches
                }
            }
            return a.sampleRate > b.sampleRate
        }

        let names = sorted.map { "\($0.name) (\($0.sampleRate)Hz)" }.joined(separator: ", ")
        logInfo("Selected devices for sharing - \(names)")
        return sorted
    }
}
