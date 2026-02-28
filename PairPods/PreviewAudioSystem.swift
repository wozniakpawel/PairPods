//
//  PreviewAudioSystem.swift
//  PairPods
//

import CoreAudio
import Foundation

/// A no-op audio system for SwiftUI previews that avoids calling into CoreAudio.
struct PreviewAudioSystem: AudioSystemQuerying, AudioSystemCommanding {
    func fetchAllAudioDevices() async throws -> [AudioDevice] { [] }
    func fetchDefaultOutputDevice() async -> (AudioDevice?, AudioDeviceID?) { (nil, nil) }
    func fetchDeviceID(deviceUID _: String) async -> AudioDeviceID? { nil }
    func createAggregateDevice(name _: String, uid _: String,
                               masterUID _: String, secondUID _: String) async throws -> AudioDeviceID { 0 }
    func destroyAggregateDevice(deviceID _: AudioDeviceID) async throws {}
    func setDefaultOutputDevice(deviceID _: AudioDeviceID) async throws {}
    func setSampleRate(on _: AudioDeviceID, to _: Double) -> Bool { false }
}
