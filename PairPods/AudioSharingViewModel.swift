//
//  AudioSharingViewModel.swift
//  PairPods
//
//  Created by Pawel Wozniak on 04/03/2024.
//

import CoreAudio

class AudioSharingViewModel: ObservableObject {
    @Published var isSharingAudio = false {
        didSet {
            if isSharingAudio {
                if !startSharingAudio() {
                    isSharingAudio = false
                }
            } else {
                _ = removePairPodsOutputDevice()
            }
        }
    }
    
    init() {
        // destroy any existing PairPodsOutputDevice on startup
        _ = removePairPodsOutputDevice()
    }
    
    private func startSharingAudio() -> Bool {
        
        listAllOutputDevices()
        
        guard let outputDevices = findTwoOutputDevices(), outputDevices.count >= 2 else {
            handleError("Please make sure two pairs of AirPods are connected via Bluetooth.")
            return false
        }
        
        let (masterDeviceUID, secondDeviceUID) = (outputDevices[0].deviceUID as CFString, outputDevices[1].deviceUID as CFString)
        
        if let deviceID = createAndUseMultiOutputDevice(masterDeviceUID: masterDeviceUID, secondDeviceUID: secondDeviceUID) {
            print("Successfully created and set multi-output device with ID: \(deviceID)")
            return true
        } else {
            handleError("Something went wrong. Failed to create multi-output device.")
            return false
        }
    }
    
    private func fetchAllAudioDeviceIDs() -> [AudioDeviceID]? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize)
        guard status == noErr else {
            print("Error: Unable to get the property data size for audio devices. Status code: \(status)")
            return nil
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        guard deviceCount > 0 else {
            print("No audio devices found.")
            return nil
        }
        
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceIDs)
        guard status == noErr else {
            print("Error: Unable to get audio device IDs. Status code: \(status)")
            return nil
        }
        
        return deviceIDs
    }
    
    private func findDefaultAudioDeviceID() -> AudioDeviceID? {
        var defaultDeviceID = AudioDeviceID()
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultDeviceID)
        
        guard status == noErr else {
            print("Error: Unable to get the default audio device ID. Status code: \(status)")
            return nil
        }
        
        return defaultDeviceID
    }
    
    private func fetchDeviceName(deviceID: AudioDeviceID) -> String? {
        var name: Unmanaged<CFString>?
        var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &name)
        
        guard status == noErr, let deviceName = name?.takeRetainedValue() else {
            print("Error: Unable to get the name for device ID: \(deviceID). Status code: \(status)")
            return nil
        }
        
        return deviceName as String
    }
    
    private func fetchDeviceUID(deviceID: AudioDeviceID) -> String? {
        var uid: Unmanaged<CFString>?
        var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &uid)
        
        guard status == noErr, let deviceUID = uid?.takeRetainedValue() else {
            print("Error: Unable to get the UID for device ID: \(deviceID). Status code: \(status)")
            return nil
        }
        
        return deviceUID as String
    }
    
    // avoid this function if possible, it's pretty expensive to run!
    private func fetchDeviceID(deviceUID: CFString) -> AudioDeviceID? {
        guard let deviceIDs = fetchAllAudioDeviceIDs() else {
            print("Error: Unable to fetch audio device IDs.")
            return nil
        }
        
        for deviceID in deviceIDs {
            var uid: Unmanaged<CFString>?
            var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            
            let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &uid)
            
            guard status == noErr else {
                print("Error: Unable to get UID for device ID \(deviceID). Status code: \(status)")
                continue // Skipping this device due to error, continue with next
            }
            
            let fetchedUID = uid?.takeRetainedValue()
            if fetchedUID == deviceUID {
                return deviceID
            }
        }
        
        print("No audio device found with UID: \(deviceUID as String)")
        return nil
    }
    
    private func listAllOutputDevices() {
        guard let audioDevices = fetchAllAudioDeviceIDs() else {
            print("Error: Unable to fetch audio device IDs.")
            return
        }
        
        print("\n--- Listing Output Devices ---\n")
        
        for deviceID in audioDevices {
            
            print("Device ID: \(deviceID)")
            printProperty(deviceID: deviceID, propertySelector: kAudioDevicePropertyDeviceNameCFString, propertyName: "Name")
            printProperty(deviceID: deviceID, propertySelector: kAudioDevicePropertyDeviceUID, propertyName: "UID")
            printProperty(deviceID: deviceID, propertySelector: kAudioDevicePropertyModelUID, propertyName: "Model UID")
            printProperty(deviceID: deviceID, propertySelector: kAudioDevicePropertyTransportType, propertyName: "Transport Type")
            printProperty(deviceID: deviceID, propertySelector: kAudioObjectPropertyManufacturer, propertyName: "Manufacturer")

            // Advanced details (add as needed)
            printProperty(deviceID: deviceID, propertySelector: kAudioDevicePropertyDeviceIsAlive, propertyName: "Is Alive")
            printProperty(deviceID: deviceID, propertySelector: kAudioDevicePropertyDeviceIsRunning, propertyName: "Is Running")
            printProperty(deviceID: deviceID, propertySelector: kAudioDevicePropertyNominalSampleRate, propertyName: "Nominal Sample Rate")
            printProperty(deviceID: deviceID, propertySelector: kAudioDevicePropertyStreams, propertyName: "Streams")

            // Note: For properties requiring special handling (e.g., arrays, structs), you'll need custom printProperty implementations.
            
            print("\n")
        }
    }

    private func printProperty(deviceID: AudioObjectID, propertySelector: AudioObjectPropertySelector, propertyName: String) {
        var propertyAddress = AudioObjectPropertyAddress(mSelector: propertySelector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        
        guard status == noErr else {
            print("Failed to get data size for \(propertyName)")
            return
        }
        
        if propertySelector == kAudioDevicePropertyDeviceNameCFString ||
            propertySelector == kAudioDevicePropertyDeviceUID ||
            propertySelector == kAudioDevicePropertyModelUID ||
            propertySelector == kAudioObjectPropertyManufacturer {
            
            let buffer = UnsafeMutablePointer<Unmanaged<CFString>?>.allocate(capacity: 1)
            defer { buffer.deallocate() }
            
            status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, buffer)
            if status == noErr, let cfStr: CFString = buffer.pointee?.takeRetainedValue() {
                let str = cfStr as String
                print("\(propertyName): \(str)")
            } else {
                print("Failed to get \(propertyName)")
            }
        } else if propertySelector == kAudioDevicePropertyTransportType {
            var transportType: UInt32 = 0
            status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &transportType)
            if status == noErr {
                print("\(propertyName): \(transportTypeToString(transportType))")
            } else {
                print("Failed to get \(propertyName)")
            }
        } else {
            // Generic handling for numbers and other data types
            print("Property \(propertyName) requires specific handling")
        }
    }

    private func transportTypeToString(_ transportType: UInt32) -> String {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
        case kAudioDeviceTransportTypeAggregate: return "Aggregate"
        case kAudioDeviceTransportTypeVirtual: return "Virtual"
        case kAudioDeviceTransportTypePCI: return "PCI"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeFireWire: return "FireWire"
        case kAudioDeviceTransportTypeBluetooth: return "Bluetooth"
        case kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth LE"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
        case kAudioDeviceTransportTypeAVB: return "AVB"
        case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
        default: return "Unknown"
        }
    }
    
    private func findTwoOutputDevices() -> [(deviceID: AudioDeviceID, deviceUID: String)]? {
        guard let audioDevices = fetchAllAudioDeviceIDs() else {
            return nil
        }
        
        var outputDevices: [(deviceID: AudioDeviceID, deviceUID: String)] = []
        
        for deviceID in audioDevices {
            guard let deviceUID = fetchDeviceUID(deviceID: deviceID),
                  !deviceUID.contains("BuiltInSpeakerDevice"),
                  !deviceUID.contains("AMS2_Aggregate"),
                  !deviceUID.contains("AMS2_StackedOutput"),
                  let _ = fetchDeviceName(deviceID: deviceID) else { continue }
            
            var propertyAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var dataSize: UInt32 = 0
            let statusDataSize = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
            
            if statusDataSize == noErr, dataSize > 0 {
                let bufferPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
                defer { bufferPointer.deallocate() }
                
                let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferPointer)
                
                if status == noErr, bufferPointer.pointee.mNumberBuffers > 0 {
                    outputDevices.append((deviceID, deviceUID))
                    if outputDevices.count == 2 { break } // Only need two devices
                }
            }
        }
        
        return outputDevices.count == 2 ? outputDevices : nil
    }
    
    private func createMultiOutputDevice(masterDeviceUID: CFString, secondDeviceUID: CFString) -> AudioDeviceID? {
        let multiOutUID = "PairPodsOutputDevice"
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "PairPods Output Device",
            kAudioAggregateDeviceUIDKey: multiOutUID,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: masterDeviceUID], [kAudioSubDeviceUIDKey: secondDeviceUID]],
            kAudioAggregateDeviceMasterSubDeviceKey: masterDeviceUID,
            kAudioAggregateDeviceIsStackedKey: 1,
        ]
        
        var aggregateDevice: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggregateDevice)
        
        guard status == noErr else {
            print("Failed to create the multi-output device. Error: \(status)")
            return nil
        }
        
        return aggregateDevice
    }
    
    private func setDefaultOutputDevice(deviceID: AudioDeviceID) -> OSStatus {
        var mutableDeviceID = deviceID // Make a mutable copy to prevent compiler errors
        var defaultOutputPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        let setStatus = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputPropertyAddress, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &mutableDeviceID)
        
        guard setStatus == noErr else {
            print("Failed to set the device ID \(deviceID) as the default output device. Error: \(setStatus)")
            return setStatus
        }
        
        return setStatus
    }
    
    private func createAndUseMultiOutputDevice(masterDeviceUID: CFString, secondDeviceUID: CFString) -> AudioDeviceID? {
        guard let deviceID = createMultiOutputDevice(masterDeviceUID: masterDeviceUID, secondDeviceUID: secondDeviceUID) else {
            return nil
        }
        
        let setStatus = setDefaultOutputDevice(deviceID: deviceID)
        guard setStatus == noErr else {
            print("Failed to set the multi-output device as default. Error: \(setStatus)")
            return nil
        }
        
        return deviceID
    }
    
    private func removeMultiOutputDevice(deviceID: AudioDeviceID) -> OSStatus {
        let status = AudioHardwareDestroyAggregateDevice(deviceID)
        
        guard status == noErr else {
            print("Failed to remove the multi-output device with ID \(deviceID). Error: \(status)")
            return status
        }
        
        print("Successfully removed the multi-output device with ID \(deviceID).")
        return status
    }
    
    private func removePairPodsOutputDevice() -> OSStatus {
        let multiOutUID = "PairPodsOutputDevice" as CFString
        
        guard let deviceID = fetchDeviceID(deviceUID: multiOutUID) else {
            return noErr
        }
        
        return removeMultiOutputDevice(deviceID: deviceID)
    }

}
