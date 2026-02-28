//
//  AudioSystemQuerying.swift
//  PairPods
//

import CoreAudio
import Foundation

protocol AudioSystemQuerying: Sendable {
    func fetchAllAudioDevices() async throws -> [AudioDevice]
    func fetchDefaultOutputDevice() async -> (AudioDevice?, AudioDeviceID?)
    func fetchDeviceID(deviceUID: String) async -> AudioDeviceID?
}
