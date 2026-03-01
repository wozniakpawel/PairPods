//
//  CoreAudioSystem.swift
//  PairPods
//

import CoreAudio
import Foundation

struct CoreAudioSystem: AudioSystemQuerying, AudioSystemCommanding {
    func fetchAllAudioDevices() async throws -> [AudioDevice] {
        let deviceIDs = try fetchAllAudioDeviceIDs()
        return await withTaskGroup(of: AudioDevice?.self) { group in
            for deviceID in deviceIDs {
                group.addTask {
                    await AudioDevice(deviceID: deviceID)
                }
            }
            var devices: [AudioDevice] = []
            for await device in group {
                if let device {
                    devices.append(device)
                }
            }
            return devices
        }
    }

    func fetchDefaultOutputDevice() async -> (AudioDevice?, AudioDeviceID?) {
        guard let defaultDeviceID = findDefaultAudioDeviceID() else {
            return (nil, nil)
        }
        let device = await AudioDevice(deviceID: defaultDeviceID)
        return (device, defaultDeviceID)
    }

    func fetchDeviceID(deviceUID: String) async -> AudioDeviceID? {
        do {
            let devices = try await fetchAllAudioDevices()
            return devices.first { $0.uid == deviceUID }?.id
        } catch {
            logError("Failed to fetch device ID", error: .systemError(error))
            return nil
        }
    }

    func createAggregateDevice(name: String, uid: String,
                               masterUID: String, secondUID: String) async throws -> AudioDeviceID
    {
        logDebug("Creating aggregate device")
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: name,
            kAudioAggregateDeviceUIDKey: uid,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: masterUID],
                [kAudioSubDeviceUIDKey: secondUID, kAudioSubDeviceDriftCompensationKey as String: 1],
            ],
            kAudioAggregateDeviceMasterSubDeviceKey: masterUID,
            kAudioAggregateDeviceIsStackedKey: 1,
        ]

        var aggregateDevice: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggregateDevice)
        guard status == noErr else {
            throw AppError.operationError("Failed to create aggregate device. Status: \(status)")
        }

        logInfo("Created aggregate device with ID: \(aggregateDevice)")
        return aggregateDevice
    }

    func destroyAggregateDevice(deviceID: AudioDeviceID) async throws {
        let status = AudioHardwareDestroyAggregateDevice(deviceID)
        guard status == noErr else {
            throw AppError.operationError("Failed to destroy aggregate device. Status: \(status)")
        }
    }

    func setDefaultOutputDevice(deviceID: AudioDeviceID) async throws {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var propertyAddress = systemObject.getPropertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice)

        var mutableDeviceID = deviceID
        let status = AudioObjectSetPropertyData(
            systemObject,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
        guard status == noErr else {
            throw AppError.operationError("Failed to set default output device. Status: \(status)")
        }
    }

    func setSampleRate(on deviceID: AudioDeviceID, to sampleRate: Double) -> Bool {
        deviceID.setSampleRate(sampleRate)
    }

    // MARK: - Private Helpers

    private func fetchAllAudioDeviceIDs() throws -> [AudioDeviceID] {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var propertyAddress = systemObject.getPropertyAddress(selector: kAudioHardwarePropertyDevices)

        var propertySize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(systemObject, &propertyAddress, 0, nil, &propertySize)
        guard status == noErr else {
            throw AppError.operationError("Unable to get property data size for audio devices. Status: \(status)")
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        let getStatus = AudioObjectGetPropertyData(systemObject, &propertyAddress, 0, nil, &propertySize, &deviceIDs)
        guard getStatus == noErr else {
            throw AppError.operationError("Unable to get audio device IDs. Status: \(getStatus)")
        }

        return deviceIDs
    }

    private func findDefaultAudioDeviceID() -> AudioDeviceID? {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var defaultDeviceID = AudioDeviceID()
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = systemObject.getPropertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice)

        let status = AudioObjectGetPropertyData(systemObject, &propertyAddress, 0, nil, &propertySize, &defaultDeviceID)
        return status == noErr ? defaultDeviceID : nil
    }
}
