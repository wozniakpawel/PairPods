//
//  AudioSharingViewModel.swift
//  PairPods
//
//  Created by Pawel Wozniak on 04/03/2024.
//

import Foundation
import CoreAudio

class AudioSharingViewModel: ObservableObject {
    @Published var isSharingAudio = false
    @Published var isShowingAlert = false
    @Published var alertMessage = ""

    // Track the current aggregate device ID
    private var currentAggregateDeviceID: AudioDeviceID?

    func toggleAudioSharing() {
        if isSharingAudio {
            startSharingAudio()
        } else {
            stopSharingAudio()
        }
    }
    
    private func startSharingAudio() {
        guard !isShowingAlert else { return }

        print("Sharing audio between two pairs of AirPods")
        // Ensure we're not creating another device if one already exists
        guard currentAggregateDeviceID == nil else {
            print("An aggregate device already exists. ID: \(String(describing: currentAggregateDeviceID))")
            return
        }

        // Simplified device finding logic for demonstration
        guard let outputDevices = findTwoOutputDevices() else {
            alertMessage = "Please make sure two pairs of AirPods are connected via Bluetooth"
            isShowingAlert = true
            isSharingAudio = false
            return
        }
        let masterDeviceUID = outputDevices[0].deviceUID as CFString
        let secondDeviceUID = outputDevices[1].deviceUID as CFString

        if let deviceID = createAndUseMultiOutputDevice(masterDeviceUID: masterDeviceUID, secondDeviceUID: secondDeviceUID) {
            print("Successfully created and set multi-output device.")
            currentAggregateDeviceID = deviceID
        } else {
            alertMessage = "Failed to create multi-output device."
            isShowingAlert = true
            isSharingAudio = false
        }
    }

    private func stopSharingAudio() {
        guard let deviceID = currentAggregateDeviceID else {
            print("No aggregate device to remove.")
            return
        }
        
        let removeDeviceStatus = removeMultiOutputDevice(deviceID: deviceID)
        if removeDeviceStatus == noErr {
            print("Audio Sharing stopped and device removed.")
            currentAggregateDeviceID = nil
        } else {
            print("Failed to remove the aggregate device. Status: \(removeDeviceStatus)")
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
        
        print("Error: No audio device found with UID: \(deviceUID as String)")
        return nil
    }
    
    private func listAllOutputDevices() {
        guard let audioDevices = fetchAllAudioDeviceIDs() else {
            print("Error: Unable to fetch audio device IDs.")
            return
        }
        
        print("\n--- Listing Output Devices ---\n")
        
        for deviceID in audioDevices {
            guard let deviceName = fetchDeviceName(deviceID: deviceID),
                  let deviceUID = fetchDeviceUID(deviceID: deviceID) else {
                print("Warning: Could not fetch name or UID for device ID \(deviceID). Skipping...")
                continue
            }
            
            // Determine if the device has any output channels
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain)
            var dataSize: UInt32 = 0
            let statusDataSize = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
            
            guard statusDataSize == noErr, dataSize > 0 else {
                continue // Skip this device if unable to get data size or if there are no output channels
            }
            
            let bufferPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferPointer.deallocate() }
            
            let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferPointer)
            
            guard status == noErr else {
                print("Error: Failed to get stream configuration for device ID \(deviceID). Status code: \(status). Skipping...")
                continue
            }
            
            let streamConfig = bufferPointer.pointee
            if streamConfig.mNumberBuffers > 0 {
                print("Output Device Name: \(deviceName), ID: \(deviceID), UID: \(deviceUID)")
            }
        }
    }
    
    private func areTwoAirPodsConnected() -> Bool {
        // Dummy implementation - replace with actual Bluetooth device checking logic
        // This part is highly dependent on macOS APIs and the ability to access Bluetooth device status.
        return true // Assuming two pairs are connected for demonstration purposes
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
            print("Device with UID \(multiOutUID) not found. Perhaps it was already removed.")
            return noErr
        }

        return removeMultiOutputDevice(deviceID: deviceID)
    }

}
