//
//  AudioDevice.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import CoreAudio
import Foundation

struct AudioDevice: Sendable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transportType: UInt32
    let isOutputDevice: Bool
    let sampleRate: Double

    var isCompatibleOutputDevice: Bool {
        isOutputDevice && (transportType == kAudioDeviceTransportTypeBluetooth ||
            transportType == kAudioDeviceTransportTypeBluetoothLE)
    }

    init?(deviceID: AudioDeviceID) async {
        id = deviceID
        guard let uid = await AudioDevice.getDeviceUID(deviceID: deviceID),
              let name = await AudioDevice.getDeviceName(deviceID: deviceID),
              let transportType = await AudioDevice.getTransportType(deviceID: deviceID),
              let sampleRate = await AudioDevice.getSampleRate(deviceID: deviceID)
        else {
            logWarning("Failed to initialize AudioDevice for ID: \(deviceID)")
            return nil
        }

        self.uid = uid
        self.name = name
        self.transportType = transportType
        isOutputDevice = await AudioDevice.isOutputDevice(deviceID: deviceID)
        self.sampleRate = sampleRate

        logDebug("Initialized AudioDevice: \(name) (ID: \(deviceID))")
    }

    static func getDeviceUID(deviceID: AudioDeviceID) async -> String? {
        await getStringProperty(deviceID: deviceID, selector: kAudioDevicePropertyDeviceUID)
    }

    static func getDeviceName(deviceID: AudioDeviceID) async -> String? {
        await getStringProperty(deviceID: deviceID, selector: kAudioDevicePropertyDeviceNameCFString)
    }

    static func getTransportType(deviceID: AudioDeviceID) async -> UInt32? {
        await getUInt32Property(deviceID: deviceID, selector: kAudioDevicePropertyTransportType)
    }

    static func isOutputDevice(deviceID: AudioDeviceID) async -> Bool {
        let streamConfiguration = await getStreamConfiguration(deviceID: deviceID,
                                                               scope: kAudioObjectPropertyScopeOutput)
        return streamConfiguration?.mNumberBuffers ?? 0 > 0
    }

    static func getSampleRate(deviceID: AudioDeviceID) async -> Double? {
        await getFloat64Property(deviceID: deviceID, selector: kAudioDevicePropertyNominalSampleRate)
    }

    private static func getStringProperty(deviceID: AudioDeviceID,
                                          selector: AudioObjectPropertySelector) async -> String?
    {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfString: Unmanaged<CFString>?
        var propsize = UInt32(MemoryLayout<CFString?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propsize, &cfString)

        guard status == noErr, let unwrapped = cfString?.takeRetainedValue() else {
            logDebug("Failed to get string property (selector: \(selector)) for device ID: \(deviceID)")
            return nil
        }
        return unwrapped as String
    }

    private static func getUInt32Property(deviceID: AudioDeviceID,
                                          selector: AudioObjectPropertySelector) async -> UInt32?
    {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var propsize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propsize, &value)

        guard status == noErr else {
            logDebug("Failed to get UInt32 property (selector: \(selector)) for device ID: \(deviceID)")
            return nil
        }
        return value
    }

    private static func getFloat64Property(deviceID: AudioDeviceID,
                                           selector: AudioObjectPropertySelector) async -> Double?
    {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Float64 = 0.0
        var propsize = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propsize, &value)

        guard status == noErr else {
            logDebug("Failed to get Float64 property (selector: \(selector)) for device ID: \(deviceID)")
            return nil
        }
        return value
    }

    private static func getStreamConfiguration(deviceID: AudioDeviceID,
                                               scope: AudioObjectPropertyScope) async -> AudioBufferList?
    {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var propsize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propsize)
        guard status == noErr else {
            logDebug("Failed to get stream configuration size for device ID: \(deviceID)")
            return nil
        }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propsize))
        defer { bufferList.deallocate() }

        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propsize, bufferList)
        guard status == noErr else {
            logDebug("Failed to get stream configuration data for device ID: \(deviceID)")
            return nil
        }

        return bufferList.pointee
    }
}

extension AudioDevice {
    var description: String {
        """
        Device ID: \(id)
        Name: \(name)
        UID: \(uid)
        Transport Type: \(transportTypeString)
        Is Output Device: \(isOutputDevice)
        Sample Rate: \(sampleRate) Hz
        Is Compatible: \(isCompatibleOutputDevice)
        """
    }

    private var transportTypeString: String {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn: "Built-in"
        case kAudioDeviceTransportTypeAggregate: "Aggregate"
        case kAudioDeviceTransportTypeVirtual: "Virtual"
        case kAudioDeviceTransportTypePCI: "PCI"
        case kAudioDeviceTransportTypeUSB: "USB"
        case kAudioDeviceTransportTypeFireWire: "FireWire"
        case kAudioDeviceTransportTypeBluetooth: "Bluetooth"
        case kAudioDeviceTransportTypeBluetoothLE: "Bluetooth LE"
        case kAudioDeviceTransportTypeHDMI: "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay: "AirPlay"
        case kAudioDeviceTransportTypeAVB: "AVB"
        case kAudioDeviceTransportTypeThunderbolt: "Thunderbolt"
        default: "Unknown"
        }
    }
}

extension AudioDevice {
    func getVolume() async -> Float? {
        await Self.getVolumeProperty(deviceID: id)
    }

    func setVolume(_ volume: Float) async throws {
        try await Self.setVolumeProperty(deviceID: id, volume: volume)
    }

    private static func getPropertyAddress(for deviceID: AudioDeviceID) -> AudioObjectPropertyAddress? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if the property exists
        var propertyExists = AudioObjectHasProperty(deviceID, &address)
        if !propertyExists {
            // Try alternative volume control (channel-based)
            address.mElement = 1 // Left/Main channel
            propertyExists = AudioObjectHasProperty(deviceID, &address)

            if !propertyExists {
                logDebug("Device \(deviceID) does not support volume control")
                return nil
            }
        }

        return address
    }

    static func getVolumeProperty(deviceID: AudioDeviceID) async -> Float? {
        guard var address = getPropertyAddress(for: deviceID) else {
            return nil
        }

        var value: Float = 0.0
        var propsize = UInt32(MemoryLayout<Float>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propsize, &value)

        guard status == noErr else {
            logDebug("Failed to get volume property for device ID: \(deviceID). Status: \(status)")
            return nil
        }
        logDebug("Successfully got volume \(value) for device ID: \(deviceID)")
        return value
    }

    static func setVolumeProperty(deviceID: AudioDeviceID, volume: Float) async throws {
        logDebug("Attempting to set volume \(volume) for device ID: \(deviceID)")

        guard var address = getPropertyAddress(for: deviceID) else {
            throw AppError.operationError("Device does not support volume control")
        }

        // Check if the property is writable
        var isWritable: DarwinBoolean = false
        let checkStatus = AudioObjectIsPropertySettable(deviceID, &address, &isWritable)

        guard checkStatus == noErr else {
            throw AppError.operationError("Failed to check if volume property is settable. Status: \(checkStatus)")
        }

        guard isWritable.boolValue else {
            throw AppError.operationError("Volume property is not settable for device ID: \(deviceID)")
        }

        // Set the volume
        var mutableVolume = volume
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float>.size),
            &mutableVolume
        )

        guard status == noErr else {
            throw AppError.operationError("Failed to set volume. Status: \(status)")
        }

        logDebug("Successfully set volume to \(volume) for device ID: \(deviceID)")

        // If we're using a channel-based approach, also set the right channel
        if address.mElement == 1 {
            try? setRightChannelVolume(deviceID: deviceID, volume: volume)
        }
    }

    private static func setRightChannelVolume(deviceID: AudioDeviceID, volume: Float) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 2 // Right channel
        )

        if !AudioObjectHasProperty(deviceID, &address) {
            return
        }

        var isWritable: DarwinBoolean = false
        if AudioObjectIsPropertySettable(deviceID, &address, &isWritable) != noErr || !isWritable.boolValue {
            return
        }

        var mutableVolume = volume
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float>.size),
            &mutableVolume
        )

        if status != noErr {
            logWarning("Failed to set right channel volume. Status: \(status)")
        }
    }
}
