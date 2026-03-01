//
//  AudioSystemCommanding.swift
//  PairPods
//

import CoreAudio
import Foundation

protocol AudioSystemCommanding: Sendable {
    func createAggregateDevice(name: String, uid: String,
                               masterUID: String, secondUID: String) async throws -> AudioDeviceID
    func destroyAggregateDevice(deviceID: AudioDeviceID) async throws
    func setDefaultOutputDevice(deviceID: AudioDeviceID) async throws
    func setSampleRate(on deviceID: AudioDeviceID, to sampleRate: Double) -> Bool
}
