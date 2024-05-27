//
//  AudioDeviceDebugHelper.swift
//  PairPods
//
//  Created by Pawel Wozniak on 27/05/2024.
//

import CoreAudio

struct AudioDeviceDebugHelper {
    
    static func listAllOutputDevices() {
        guard let audioDevices = AudioDeviceHelper.fetchAllAudioDeviceIDs() else {
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
            
            printStreamsProperty(deviceID: deviceID)
            
            print("\n")
        }
    }
    
    private static func printProperty(deviceID: AudioObjectID, propertySelector: AudioObjectPropertySelector, propertyName: String) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: propertySelector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        
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
            
            let fetchStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, buffer)
            if fetchStatus == noErr, let cfStr: CFString = buffer.pointee?.takeRetainedValue() {
                let str = cfStr as String
                print("\(propertyName): \(str)")
            } else {
                print("Failed to get \(propertyName)")
            }
        } else if propertySelector == kAudioDevicePropertyTransportType {
            var transportType: UInt32 = 0
            let fetchStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &transportType)
            if fetchStatus == noErr {
                print("\(propertyName): \(transportTypeToString(transportType))")
            } else {
                print("Failed to get \(propertyName)")
            }
        } else {
            print("Property \(propertyName) requires specific handling")
        }
    }
    
    private static func printStreamsProperty(deviceID: AudioDeviceID) {
        var dataSize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else {
            print("Failed to get Streams data size")
            return
        }
        
        let streamCount = Int(dataSize) / MemoryLayout<AudioStreamID>.size
        print("Streams: \(streamCount)")
    }
    
    private static func transportTypeToString(_ transportType: UInt32) -> String {
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
}
