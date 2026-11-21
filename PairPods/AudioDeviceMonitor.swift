//
//  AudioDeviceMonitor.swift
//  PairPods
//

import CoreAudio
import Foundation

@MainActor
final class AudioDeviceMonitor {
    private let deviceListListener: Listener?
    private let onVolumeChanged: @MainActor (AudioDeviceID) -> Void
    private var volumeListeners: [AudioDeviceID: [Listener]] = [:]

    init(onDevicesChanged: @escaping @MainActor () async -> Void, onVolumeChanged: @escaping @MainActor (AudioDeviceID) -> Void) {
        self.onVolumeChanged = onVolumeChanged
        let system = AudioObjectID(kAudioObjectSystemObject)
        let address = system.getPropertyAddress(selector: kAudioHardwarePropertyDevices)
        deviceListListener = Listener(object: system, address: address) { _, _ in
            Task { @MainActor in await onDevicesChanged() }
        }
    }

    func observeVolume(of ids: Set<AudioDeviceID>) {
        for id in Set(volumeListeners.keys).subtracting(ids) {
            volumeListeners[id] = nil
        }
        for id in ids where volumeListeners[id] == nil {
            volumeListeners[id] = listenForVolumeChanges(on: id)
        }
    }

    private func listenForVolumeChanges(on id: AudioDeviceID) -> [Listener] {
        var addresses = [id.getPropertyAddress(selector: kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)]
        if var volume = id.getVolumePropertyAddress() {
            addresses.append(volume)
            if volume.mElement == 1 {
                volume.mElement = 2
                addresses.append(volume)
            }
        }
        // The block receives property addresses. The device ID comes from the registration.
        let block: AudioObjectPropertyListenerBlock = { [onVolumeChanged] _, _ in
            Task { @MainActor in onVolumeChanged(id) }
        }
        return addresses.compactMap { address in
            var address = address
            guard AudioObjectHasProperty(id, &address) else { return nil }
            return Listener(object: id, address: address, block: block)
        }
    }

    private final class Listener {
        private let remove: @convention(block) () -> Void

        init?(object: AudioObjectID, address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) {
            var remove: (@convention(block) () -> Void)?
            let status = PairPodsObserveAudioProperty(object, address, block, &remove)
            guard let remove else {
                logWarning("Couldn’t observe audio properties for object \(object) (Core Audio: \(status))")
                return nil
            }
            self.remove = remove
        }

        deinit {
            remove()
        }
    }
}
