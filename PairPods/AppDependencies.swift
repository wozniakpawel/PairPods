//
//  AppDependencies.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import CoreAudio
import Foundation
import SwiftUI

protocol AudioDeviceManaging: ObservableObject {
    var deviceStateDidChange: ((AudioDeviceState) -> Void)? { get set }
    func isMultiOutputDeviceActive() async -> Bool
    func isMultiOutputDeviceValid() async -> Bool
    func setupMultiOutputDevice() async throws
    func removeMultiOutputDevice() async
    func restoreOutputDevice() async
    func refreshCompatibleDevices() async
    func cleanup() async
}

protocol AudioSharingManaging: ObservableObject {
    var state: AudioSharingState { get }
    var isSharingAudio: Bool { get }
    var stateDidChange: ((AudioSharingState) -> Void)? { get set }
    func startSharing()
    func stopSharing()
    func cleanup() async
}

protocol AppDependencies {
    var audioDeviceManager: any AudioDeviceManaging { get }
    var audioSharingManager: any AudioSharingManaging { get }
    var audioVolumeManager: AudioVolumeManager { get }
}

@MainActor
final class LiveAppDependencies: ObservableObject, AppDependencies {
    static let shared = LiveAppDependencies()

    let audioDeviceManager: any AudioDeviceManaging
    let audioSharingManager: any AudioSharingManaging
    let audioVolumeManager: AudioVolumeManager

    init() {
        let deviceManager = AudioDeviceManager(shouldShowAlerts: true)
        audioDeviceManager = deviceManager
        
        audioSharingManager = AudioSharingManager(
            audioDeviceManager: deviceManager
        )
        
        audioVolumeManager = AudioVolumeManager(
            audioDeviceManager: deviceManager
        )
    }

    func cleanup() async {
        await audioDeviceManager.cleanup()
        await audioSharingManager.cleanup()
    }
}
