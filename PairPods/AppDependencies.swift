//
//  AppDependencies.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import CoreAudio
import Foundation
import SwiftUI

@MainActor
final class AppDependencies: ObservableObject {
    static let shared = AppDependencies()

    let audioDeviceManager: AudioDeviceManager
    let audioSharingManager: AudioSharingManager
    let audioVolumeManager: AudioVolumeManager

    init() {
        audioDeviceManager = AudioDeviceManager(shouldShowAlerts: true)
        audioSharingManager = AudioSharingManager(audioDeviceManager: audioDeviceManager)
        audioVolumeManager = AudioVolumeManager(audioDeviceManager: audioDeviceManager)
    }

    func cleanup() async {
        await audioDeviceManager.cleanup()
        await audioSharingManager.cleanup()
    }
}
