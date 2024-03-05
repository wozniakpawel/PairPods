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
        // Placeholder UIDs for demonstration. You'll need to dynamically find these.
        let masterDeviceUID: CFString = "BuiltInSpeakerDevice" as CFString
        let secondDeviceUID: CFString = "EC-73-79-3D-0E-42:output" as CFString
        let multiOutUID: String = "PairPodsOutputDevice"
        // Create the multi-output device
        let setStatus = createAndSetMultiOutputDevice(masterDeviceUID: masterDeviceUID, secondDeviceUID: secondDeviceUID, multiOutUID: multiOutUID)
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
        print("Audio Sharing stopped.")
//        print("Setting the output device to internal speakers")
//        guard let builtInSpeakerID = findBuiltInSpeakerDeviceID() else {
//            print("Failed to find the built-in speaker device ID.")
//            return
//        }
//
//        print("Setting the output device to internal speakers")
//        setSystemAudioOutputDevice(to: builtInSpeakerID)
    }

    func listAllAudioDevices() {
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

        print("\n--- Filtering Output Devices Except Internal Speakers and Special Multi-Output Devices ---\n")

        for device in audioDevices {
            var name: Unmanaged<CFString>?
            var uid: Unmanaged<CFString>?
            var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
            propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
            
            AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &size, &name)
            propertyAddress.mSelector = kAudioDevicePropertyDeviceUID
            AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &size, &uid)

            let deviceName = name?.takeRetainedValue() as String? ?? "Unknown"
            let deviceUID = uid?.takeRetainedValue() as String? ?? "Unknown"

            // Query the size of the stream configuration data
            propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration
            propertyAddress.mScope = kAudioDevicePropertyScopeOutput
            var dataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(device, &propertyAddress, 0, nil, &dataSize)
            guard status == noErr else { continue }

            // Allocate a buffer of the correct size to hold the stream configuration data
            let bufferPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
            defer { bufferPointer.deallocate() }

            // Fetch the stream configuration data
            status = AudioObjectGetPropertyData(device, &propertyAddress, 0, nil, &dataSize, bufferPointer)
            guard status == noErr else { continue }

            let streamConfig = bufferPointer.pointee
            if streamConfig.mNumberBuffers > 0,
               deviceName.contains("MacBook Pro Speakers") {
                print("Output Device Name: \(deviceName), ID: \(device), UID: \(deviceUID)")
            }
            if streamConfig.mNumberBuffers > 0,
               !deviceName.contains("Internal Speakers"),
               !deviceName.contains("MacBook Pro Speakers"),
               !deviceUID.contains("AMS2_Aggregate"),
               !deviceUID.contains("AMS2_StackedOutput") {
                print("Output Device Name: \(deviceName), ID: \(device), UID: \(deviceUID)")
            }
        }
    }

    private func areTwoAirPodsConnected() -> Bool {
        // Dummy implementation - replace with actual Bluetooth device checking logic
        // This part is highly dependent on macOS APIs and the ability to access Bluetooth device status.
        return true // Assuming two pairs are connected for demonstration purposes
    }

    private func createAndSetMultiOutputDevice(masterDeviceUID: CFString, secondDeviceUID: CFString, multiOutUID: String) -> OSStatus {
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
            return status
        }

        // Successfully created the multi-output device, now set it as the default output device
        var defaultOutputPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        let setStatus = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultOutputPropertyAddress, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &aggregateDevice)

        
        guard setStatus == noErr else {
            print("Failed to set the multi-output device as the default output device. Error: \(setStatus)")
            return setStatus
        }

        return setStatus
    }
}
