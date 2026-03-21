//
//  AudioDevice.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import CoreAudio
import Foundation
import IOBluetooth

// MARK: - CoreAudio Extensions

extension AudioObjectID {
    func getPropertyAddress(selector: AudioObjectPropertySelector,
                            scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                            element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress
    {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
    }

    func getStringProperty(selector: AudioObjectPropertySelector) -> String? {
        var address = getPropertyAddress(selector: selector)
        var cfString: Unmanaged<CFString>?
        var propsize = UInt32(MemoryLayout<CFString?>.size)
        let status = AudioObjectGetPropertyData(self, &address, 0, nil, &propsize, &cfString)

        guard status == noErr, let unwrapped = cfString?.takeRetainedValue() else {
            logDebug("Failed to get string property (selector: \(selector)) for device ID: \(self)")
            return nil
        }
        return unwrapped as String
    }

    func getUInt32Property(selector: AudioObjectPropertySelector) -> UInt32? {
        var address = getPropertyAddress(selector: selector)
        var value: UInt32 = 0
        var propsize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(self, &address, 0, nil, &propsize, &value)

        guard status == noErr else {
            logDebug("Failed to get UInt32 property (selector: \(selector)) for device ID: \(self)")
            return nil
        }
        return value
    }

    func getFloat64Property(selector: AudioObjectPropertySelector) -> Double? {
        var address = getPropertyAddress(selector: selector)
        var value: Float64 = 0.0
        var propsize = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(self, &address, 0, nil, &propsize, &value)

        guard status == noErr else {
            logDebug("Failed to get Float64 property (selector: \(selector)) for device ID: \(self)")
            return nil
        }
        return value
    }

    func getStreamConfiguration(scope: AudioObjectPropertyScope) -> AudioBufferList? {
        var address = getPropertyAddress(selector: kAudioDevicePropertyStreamConfiguration, scope: scope)
        var propsize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(self, &address, 0, nil, &propsize)
        guard status == noErr else {
            logDebug("Failed to get stream configuration size for device ID: \(self)")
            return nil
        }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propsize))
        defer { bufferList.deallocate() }

        status = AudioObjectGetPropertyData(self, &address, 0, nil, &propsize, bufferList)
        guard status == noErr else {
            logDebug("Failed to get stream configuration data for device ID: \(self)")
            return nil
        }

        return bufferList.pointee
    }

    /// Volume control methods
    func getVolumePropertyAddress() -> AudioObjectPropertyAddress? {
        var address = getPropertyAddress(
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )

        // Check if the property exists
        var propertyExists = AudioObjectHasProperty(self, &address)
        if !propertyExists {
            // Try alternative volume control (channel-based)
            address.mElement = 1 // Left/Main channel
            propertyExists = AudioObjectHasProperty(self, &address)

            if !propertyExists {
                logDebug("Device \(self) does not support volume control")
                return nil
            }
        }

        return address
    }

    func addVolumePropertyListener(listener: @escaping AudioObjectPropertyListenerBlock) -> Bool {
        // First try with main element
        guard var address = getVolumePropertyAddress() else {
            return false
        }

        let status = AudioObjectAddPropertyListenerBlock(
            self,
            &address,
            DispatchQueue.main,
            listener
        )

        if status != noErr {
            logError("Failed to add volume listener for device ID: \(self)", error: .operationError("Status: \(status)"))
            return false
        }

        // If using channel-based volume, also listen to right channel
        if address.mElement == 1 {
            var rightChannelAddress = getPropertyAddress(
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                element: 2 // Right channel
            )

            if AudioObjectHasProperty(self, &rightChannelAddress) {
                let rightStatus = AudioObjectAddPropertyListenerBlock(
                    self,
                    &rightChannelAddress,
                    DispatchQueue.main,
                    listener
                )

                if rightStatus != noErr {
                    logWarning("Failed to add right channel volume listener for device ID: \(self)")
                }
            }
        }

        return true
    }

    func removeVolumePropertyListener(listener: @escaping AudioObjectPropertyListenerBlock) {
        guard var address = getVolumePropertyAddress() else { return }

        AudioObjectRemovePropertyListenerBlock(self, &address, DispatchQueue.main, listener)

        if address.mElement == 1 {
            var rightChannelAddress = getPropertyAddress(
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioDevicePropertyScopeOutput,
                element: 2
            )
            if AudioObjectHasProperty(self, &rightChannelAddress) {
                AudioObjectRemovePropertyListenerBlock(self, &rightChannelAddress, DispatchQueue.main, listener)
            }
        }
    }

    func removeMutePropertyListener(listener: @escaping AudioObjectPropertyListenerBlock) {
        var address = getPropertyAddress(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(self, &address) else { return }
        AudioObjectRemovePropertyListenerBlock(self, &address, DispatchQueue.main, listener)
    }

    func addMutePropertyListener(listener: @escaping AudioObjectPropertyListenerBlock) -> Bool {
        var address = getPropertyAddress(
            selector: kAudioDevicePropertyMute,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )

        if !AudioObjectHasProperty(self, &address) {
            return false
        }

        let status = AudioObjectAddPropertyListenerBlock(
            self,
            &address,
            DispatchQueue.main,
            listener
        )

        if status != noErr {
            logWarning("Failed to add mute listener for device ID: \(self)")
            return false
        }

        return true
    }

    func getVolume() -> Float? {
        guard var address = getVolumePropertyAddress() else {
            return nil
        }

        var value: Float = 0.0
        var propsize = UInt32(MemoryLayout<Float>.size)
        let status = AudioObjectGetPropertyData(self, &address, 0, nil, &propsize, &value)

        guard status == noErr else {
            logDebug("Failed to get volume property for device ID: \(self). Status: \(status)")
            return nil
        }
        logDebug("Successfully got volume \(value) for device ID: \(self)")
        return value
    }

    func setSampleRate(_ sampleRate: Double) -> Bool {
        var address = getPropertyAddress(
            selector: kAudioDevicePropertyNominalSampleRate,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        )

        var isWritable: DarwinBoolean = false
        let checkStatus = AudioObjectIsPropertySettable(self, &address, &isWritable)
        guard checkStatus == noErr, isWritable.boolValue else {
            logDebug("Sample rate is not settable for device ID: \(self)")
            return false
        }

        var mutableRate = sampleRate
        let status = AudioObjectSetPropertyData(
            self,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float64>.size),
            &mutableRate
        )

        if status != noErr {
            logDebug("Failed to set sample rate to \(sampleRate) for device ID: \(self). Status: \(status)")
            return false
        }

        logDebug("Successfully set sample rate to \(sampleRate) for device ID: \(self)")
        return true
    }

    func setVolume(_ volume: Float) throws {
        logDebug("Attempting to set volume \(volume) for device ID: \(self)")

        guard var address = getVolumePropertyAddress() else {
            throw AppError.operationError("Device does not support volume control")
        }

        // Check if the property is writable
        var isWritable: DarwinBoolean = false
        let checkStatus = AudioObjectIsPropertySettable(self, &address, &isWritable)

        guard checkStatus == noErr else {
            throw AppError.operationError("Failed to check if volume property is settable. Status: \(checkStatus)")
        }

        guard isWritable.boolValue else {
            throw AppError.operationError("Volume property is not settable for device ID: \(self)")
        }

        // Set the volume
        var mutableVolume = volume
        let status = AudioObjectSetPropertyData(
            self,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float>.size),
            &mutableVolume
        )

        guard status == noErr else {
            throw AppError.operationError("Failed to set volume. Status: \(status)")
        }

        logDebug("Successfully set volume to \(volume) for device ID: \(self)")

        // If we're using a channel-based approach, also set the right channel
        if address.mElement == 1 {
            do {
                try setRightChannelVolume(volume: volume)
            } catch {
                logDebug("Right channel volume not set for device \(self) (expected on mono devices): \(error.localizedDescription)")
            }
        }
    }

    private func setRightChannelVolume(volume: Float) throws {
        var address = getPropertyAddress(
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioDevicePropertyScopeOutput,
            element: 2 // Right channel
        )

        if !AudioObjectHasProperty(self, &address) {
            return
        }

        var isWritable: DarwinBoolean = false
        if AudioObjectIsPropertySettable(self, &address, &isWritable) != noErr || !isWritable.boolValue {
            return
        }

        var mutableVolume = volume
        let status = AudioObjectSetPropertyData(
            self,
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

// MARK: - Battery Info Model

struct BatteryInfo: Equatable {
    let left: Int?
    let right: Int?
    let case_: Int?
    let single: Int?

    /// case_ intentionally excluded — we display earbud/headphone level, not case level
    var displayLevel: Int? {
        if let left, let right {
            return min(left, right)
        }
        return single ?? left ?? right
    }
}

// MARK: - AudioDevice Model

struct AudioDevice: Identifiable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transportType: UInt32
    let isOutputDevice: Bool
    let sampleRate: Double
    let batteryInfo: BatteryInfo?

    var isCompatibleOutputDevice: Bool {
        isOutputDevice && (transportType == kAudioDeviceTransportTypeBluetooth ||
            transportType == kAudioDeviceTransportTypeBluetoothLE)
    }

    init(id: AudioDeviceID, uid: String, name: String, transportType: UInt32, isOutputDevice: Bool, sampleRate: Double, batteryInfo: BatteryInfo? = nil) {
        self.id = id
        self.uid = uid
        self.name = name
        self.transportType = transportType
        self.isOutputDevice = isOutputDevice
        self.sampleRate = sampleRate
        self.batteryInfo = batteryInfo
    }

    init?(deviceID: AudioDeviceID) async {
        id = deviceID
        guard let uid = deviceID.getStringProperty(selector: kAudioDevicePropertyDeviceUID),
              let name = deviceID.getStringProperty(selector: kAudioDevicePropertyDeviceNameCFString),
              let transportType = deviceID.getUInt32Property(selector: kAudioDevicePropertyTransportType),
              let sampleRate = deviceID.getFloat64Property(selector: kAudioDevicePropertyNominalSampleRate)
        else {
            logWarning("Failed to initialize AudioDevice for ID: \(deviceID)")
            return nil
        }

        self.uid = uid
        self.name = name
        self.transportType = transportType
        let streamConfiguration = deviceID.getStreamConfiguration(scope: kAudioObjectPropertyScopeOutput)
        isOutputDevice = streamConfiguration?.mNumberBuffers ?? 0 > 0
        self.sampleRate = sampleRate
        batteryInfo = AudioDevice.queryBatteryFromBluetooth(forDeviceUID: uid)

        logDebug("Initialized AudioDevice: \(name) (ID: \(deviceID))")
    }

    // MARK: - Battery Level Query

    /// Query battery info for a Bluetooth device by matching its MAC address.
    /// Extracts the MAC from the CoreAudio device UID (format: "XX-XX-XX-XX-XX-XX:output")
    /// and matches it against paired IOBluetoothDevice entries.
    static func queryBatteryFromBluetooth(forDeviceUID uid: String) -> BatteryInfo? {
        // Extract MAC address from CoreAudio UID (e.g., "20-F4-D4-49-C9-47:output" -> "20-F4-D4-49-C9-47")
        let mac = uid.components(separatedBy: ":").first ?? uid

        guard let pairedDevices = IOBluetoothDevice.pairedDevices() else {
            logDebug("IOBluetoothDevice.pairedDevices() returned nil")
            return nil
        }

        for case let device as IOBluetoothDevice in pairedDevices {
            guard let address = device.addressString,
                  address.caseInsensitiveCompare(mac) == .orderedSame,
                  device.isConnected()
            else { continue }

            let left = device.value(forKey: "batteryPercentLeft") as? Int
            let right = device.value(forKey: "batteryPercentRight") as? Int
            let case_ = device.value(forKey: "batteryPercentCase") as? Int
            let single = device.value(forKey: "batteryPercentSingle") as? Int

            // 0 means "not reporting" — treat as nil
            let info = BatteryInfo(
                left: left != nil && left! > 0 ? left : nil,
                right: right != nil && right! > 0 ? right : nil,
                case_: case_ != nil && case_! > 0 ? case_ : nil,
                single: single != nil && single! > 0 ? single : nil
            )

            if info.displayLevel != nil {
                logDebug("Battery for \(device.name ?? mac): L=\(info.left ?? -1) R=\(info.right ?? -1) C=\(info.case_ ?? -1) S=\(info.single ?? -1)")
                return info
            }

            logDebug("Battery query matched \(device.name ?? mac) but no levels reported")
            return nil
        }

        logDebug("No paired Bluetooth device matched MAC \(mac)")
        return nil
    }
}

// MARK: - AudioDevice Extensions

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
    func getVolume() -> Float? {
        id.getVolume()
    }

    func setVolume(_ volume: Float) throws {
        try id.setVolume(volume)
    }
}
