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
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        // The qualifier CoreAudio wants is a CFStringRef, so what we hand it is a pointer
        // to that reference. Taking `&uid` on the CFString variable directly forms a raw
        // pointer to memory holding an object reference, which the compiler rightly warns
        // about; going through an opaque pointer keeps the same bytes on the wire without
        // the hazard. withExtendedLifetime keeps the bridged string alive for the call.
        let uid = deviceUID as CFString
        var qualifier = Unmanaged.passUnretained(uid).toOpaque()
        var deviceID = AudioDeviceID(0)
        var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withExtendedLifetime(uid) {
            AudioObjectGetPropertyData(
                systemObject, &address,
                UInt32(MemoryLayout<UnsafeMutableRawPointer>.size), &qualifier,
                &propSize, &deviceID
            )
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    /// Builds the aggregate.
    ///
    /// When `clockUID` is supplied the aggregate is clocked by a standalone CoreAudio clock
    /// device, so *every* sub-device gets drift compensation and no Bluetooth radio acts as
    /// the timing reference. That is the fix for the pitch warble in #35: previously the
    /// master was always a Bluetooth device, uncorrected by definition, and the other device's
    /// resampler chased a moving target. Falls back to a master sub-device when no clock
    /// device exists.
    func createAggregateDevice(name: String, uid: String, masterUID: String,
                               subDeviceUIDs: [String], clockUID: String?) async throws -> AudioDeviceID
    {
        logDebug("Creating aggregate device (clock: \(clockUID ?? "master sub-device \(masterUID)"))")
        let subDeviceList: [[String: Any]] = subDeviceUIDs.map { subUID in
            // The master sub-device is the clock reference and must not be resampled.
            // With an external clock device there is no master, so everything is corrected.
            guard clockUID != nil || subUID != masterUID else {
                return [kAudioSubDeviceUIDKey: subUID]
            }
            return [
                kAudioSubDeviceUIDKey: subUID,
                kAudioSubDeviceDriftCompensationKey as String: 1,
                kAudioSubDeviceDriftCompensationQualityKey as String: kAudioAggregateDriftCompensationMaxQuality,
            ]
        }
        var desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: name,
            kAudioAggregateDeviceUIDKey: uid,
            kAudioAggregateDeviceSubDeviceListKey: subDeviceList,
            kAudioAggregateDeviceIsStackedKey: 1,
        ]
        if let clockUID {
            desc[kAudioAggregateDeviceClockDeviceKey] = clockUID
        } else {
            desc[kAudioAggregateDeviceMasterSubDeviceKey] = masterUID
        }

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

    func setSampleRate(on deviceID: AudioDeviceID, to sampleRate: Double) async -> Bool {
        await deviceID.setSampleRate(sampleRate)
    }

    func fetchNominalSampleRate(on deviceID: AudioDeviceID) async -> Double? {
        deviceID.getFloat64Property(selector: kAudioDevicePropertyNominalSampleRate)
    }

    /// Standalone clock devices that can drive the aggregate. Apple Silicon and T2 Macs
    /// publish `ATSAC:…` clocks; older hardware may publish none.
    func fetchClockDeviceUIDs() async -> [String] {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var address = systemObject.getPropertyAddress(selector: kAudioHardwarePropertyClockDeviceList)

        var propertySize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &propertySize) == noErr,
              propertySize > 0
        else {
            logDebug("No CoreAudio clock devices available")
            return []
        }

        var clockIDs = [AudioObjectID](repeating: 0, count: Int(propertySize) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &propertySize, &clockIDs) == noErr else {
            logDebug("Failed to read the clock device list")
            return []
        }

        let uids = clockIDs.compactMap { $0.getStringProperty(selector: kAudioClockDevicePropertyDeviceUID) }
        logDebug("Clock device candidates for aggregate: \(uids)")
        return uids
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
