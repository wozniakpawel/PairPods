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

    func toggleAudioSharing() {
        if isSharingAudio {
            startSharingAudio()
        } else {
            stopSharingAudio()
        }
    }

    private func startSharingAudio() {
        // Check for two pairs of AirPods connected
        print("Sharing audio between two pairs of AirPods")
        listAllAudioDevices()
//        guard areTwoAirPodsConnected() else {
//            // Handle the error: Not enough AirPods connected
//            print("Error: Two pairs of AirPods must be connected.")
//            DispatchQueue.main.async {
//                self.isSharingAudio = false
//            }
//            return
//        }
//
//        // Create the Multi-Output Device and set it as the system's output
//        createAndUseMultiOutputDevice()
    }

    private func stopSharingAudio() {
        // Set MacBook speakers as the output device and remove the Multi-Output Device
        // setSystemAudioOutputDevice()
        print("Setting the output device to internal speakers")
//        guard let builtInSpeakerID = findBuiltInSpeakerDeviceID() else {
//            print("Failed to find the built-in speaker device ID.")
//            return
//        }
//
//        print("Setting the output device to internal speakers")
//        setSystemAudioOutputDevice(to: builtInSpeakerID)
    }

    private func listAllAudioDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize)
        guard status == noErr else {
            print("Error: Unable to get property data size")
            return
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &audioDevices)
        guard status == noErr else {
            print("Error: Unable to get property data")
            return
        }

        for device in audioDevices {
            var name: Unmanaged<CFString>?
            var uid: Unmanaged<CFString>?
            
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
            status = AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &size, &name)
            if status != noErr { continue }
            
            propertyAddress.mSelector = kAudioDevicePropertyDeviceUID
            status = AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &size, &uid)
            if status != noErr { continue }

            let deviceName = name?.takeRetainedValue() as String? ?? "Unknown"
            let deviceUID = uid?.takeRetainedValue() as String? ?? "Unknown"
            
            // Print device details. Extend this section to include other details you're interested in.
            print("Device Name: \(deviceName), UID: \(deviceUID)")
        }
        
        
        print("\n--- Filtering Output Devices Except Internal Speakers ---\n")
        
        // Additional loop to list only output devices except internal speakers
        for device in audioDevices {
            var name: Unmanaged<CFString>?
            var isOutput: UInt32 = 0
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
            propertyAddress.mScope = kAudioObjectPropertyScopeGlobal // Reset scope to global for name retrieval
            
            AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &size, &name)
            
            // Check again if device is an output device
            propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration
            propertyAddress.mScope = kAudioDevicePropertyScopeOutput
            var streamConfig: AudioBufferList = AudioBufferList()
            size = UInt32(MemoryLayout<AudioBufferList>.size)
            status = AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &size, &streamConfig)
            if status == noErr && streamConfig.mNumberBuffers > 0 {
                isOutput = 1
            }
            
            let deviceName = name?.takeRetainedValue() as String? ?? "Unknown"
            
            // Filter out internal speakers and non-output devices
            if isOutput == 1 && !deviceName.contains("Internal Speakers") && !deviceName.contains("MacBook Pro Speakers") {
                print("Output Device Name: \(deviceName)")
            }
        }
    }

    private func areTwoAirPodsConnected() -> Bool {
        // Dummy implementation - replace with actual Bluetooth device checking logic
        // This part is highly dependent on macOS APIs and the ability to access Bluetooth device status.
        return true // Assuming two pairs are connected for demonstration purposes
    }
    
    private func findBuiltInSpeakerDeviceID() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize)
        guard status == noErr else { return nil }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &audioDevices)
        guard status == noErr else { return nil }

        for device in audioDevices {
            var name: Unmanaged<CFString>?
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString

            status = AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &size, &name)
            if status == noErr, let name = name?.takeRetainedValue() as String?, name == "Built-in Speaker" {
                return device
            }
        }

        return nil
    }

    private func createAndUseMultiOutputDevice() {
        // Placeholder UIDs for demonstration. You'll need to dynamically find these.
        let masterDeviceUID: CFString = "MasterDeviceUID" as CFString
        let secondDeviceUID: CFString = "SecondDeviceUID" as CFString
        let multiOutUID: String = "com.PairPods.PairPodsMultiOutputDevice"

        // Create the multi-output device
        let (status, deviceID) = createMultiOutputAudioDevice(masterDeviceUID: masterDeviceUID, secondDeviceUID: secondDeviceUID, multiOutUID: multiOutUID)

        if status == noErr {
            print("Successfully created multi-output device with ID \(deviceID).")
            // Set the created multi-output device as the system's audio output
            setSystemAudioOutputDevice(to: deviceID)
        } else {
            print("Failed to create multi-output device. Error code: \(status)")
        }
    }

    private func setSystemAudioOutputDevice(to deviceID: AudioDeviceID) {
        // This is a simplified placeholder. Setting the system's audio output device involves additional CoreAudio API calls.
        // You would typically use AudioHardwareSetProperty or AudioObjectSetPropertyData to change the default output device.
        print("Setting the system's audio output device to \(deviceID).")
    }
    
    private func createMultiOutputAudioDevice(masterDeviceUID: CFString, secondDeviceUID: CFString, multiOutUID: String) -> (OSStatus, AudioDeviceID) {
        let desc: [String : Any] = [
            kAudioAggregateDeviceNameKey: "PairPods Output Device",
            kAudioAggregateDeviceUIDKey: multiOutUID,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: masterDeviceUID], [kAudioSubDeviceUIDKey: secondDeviceUID]],
            kAudioAggregateDeviceMasterSubDeviceKey: masterDeviceUID,
            kAudioAggregateDeviceIsStackedKey: 1,
        ]

        var aggregateDevice: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggregateDevice)
        return (status, aggregateDevice)
    }
}
