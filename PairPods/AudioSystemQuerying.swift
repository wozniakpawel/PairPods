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
    /// Every standalone clock the Mac advertises, best candidate first. Empty on hardware
    /// that exposes none, in which case the aggregate falls back to a master sub-device.
    func fetchClockDeviceUIDs() async -> [String]
    /// Current nominal rate, used to check a device still holds the value we wrote before
    /// restoring it.
    func fetchNominalSampleRate(on deviceID: AudioDeviceID) async -> Double?
}
