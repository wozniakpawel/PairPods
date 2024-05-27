//
//  AudioDeviceHelper.swift
//  PairPods
//
//  Created by Pawel Wozniak on 27/05/2024.
//

import CoreAudio

struct AudioDeviceHelper {
    
    static func fetchAllAudioDeviceIDs() -> [AudioDeviceID]? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize)
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
        let fetchStatus = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceIDs)
        guard fetchStatus == noErr else {
            print("Error: Unable to get audio device IDs. Status code: \(fetchStatus)")
            return nil
        }
        
        return deviceIDs
    }
    
    static func findDefaultAudioDeviceID() -> AudioDeviceID? {
        var defaultDeviceID = AudioDeviceID()
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &defaultDeviceID)
        
        guard status == noErr else {
            print("Error: Unable to get the default audio device ID. Status code: \(status)")
            return nil
        }
        
        return defaultDeviceID
    }
    
    static func fetchDeviceUID(deviceID: AudioDeviceID) -> String? {
        var uid: Unmanaged<CFString>?
        var propertySize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &uid)
        
        guard status == noErr, let deviceUID = uid?.takeRetainedValue() else {
            print("Error: Unable to get the UID for device ID: \(deviceID). Status code: \(status)")
            return nil
        }
        
        return deviceUID as String
    }
    
    static func fetchDeviceID(deviceUID: CFString) -> AudioDeviceID? {
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
                mElement: kAudioObjectPropertyElementMain
            )
            
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
}
