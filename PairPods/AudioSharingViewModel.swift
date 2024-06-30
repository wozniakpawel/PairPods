//
//  AudioSharingViewModel.swift
//  PairPods
//
//  Created by Pawel Wozniak on 04/03/2024.
//

import CoreAudio
import Combine

class AudioSharingViewModel: ObservableObject {
    private var purchaseManager: PurchaseManager
    private var freeLicenseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    @Published var shouldShowReviewPrompt = false

    @Published var isSharingAudio = false {
        didSet {
            if isSharingAudio {
                if !startSharingAudio() {
                    isSharingAudio = false
                } else {
                    if purchaseManager.purchaseState == .free {
                        startFreeLicenseTimer()
                    }
                }
            } else {
                stopFreeLicenseTimer()
                _ = removePairPodsOutputDevice()
                purchaseManager.incrementSuccessfulShares()
                if purchaseManager.successfulSharesCount >= 10 {
                    shouldShowReviewPrompt = true
                }
            }
        }
    }
    
    init(purchaseManager: PurchaseManager) {
        self.purchaseManager = purchaseManager
        _ = removePairPodsOutputDevice()
        startMonitoringAudioDevices()
        
        purchaseManager.$purchaseState
            .sink { [weak self] state in
                if state != .free {
                    self?.stopFreeLicenseTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stopMonitoringAudioDevices()
        stopFreeLicenseTimer()
    }
    
    private func startSharingAudio() -> Bool {
        AudioDeviceDebugHelper.listAllOutputDevices()
        
        guard let outputDevices = findTwoOutputDevices(), outputDevices.count >= 2 else {
            handleError("Please make sure two Bluetooth audio devices are connected.")
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
    
    private func startMonitoringAudioDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.handleAudioDeviceChange()
        }
        
        if status != noErr {
            print("Error: Unable to add audio device change listener. Status code: \(status)")
        }
    }
    
    private func stopMonitoringAudioDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            { _, _ in }
        )
        
        if status != noErr {
            print("Error: Unable to remove audio device change listener. Status code: \(status)")
        }
    }
    
    private func handleAudioDeviceChange() {
        guard let defaultDeviceID = AudioDeviceHelper.findDefaultAudioDeviceID() else {
            print("Error: Unable to fetch the default audio device ID.")
            self.isSharingAudio = false
            return
        }
        
        guard let defaultDeviceUID = AudioDeviceHelper.fetchDeviceUID(deviceID: defaultDeviceID) else {
            print("Error: Unable to fetch the UID for the default audio device.")
            self.isSharingAudio = false
            return
        }
        
        if defaultDeviceUID != "PairPodsOutputDevice" {
            DispatchQueue.main.async {
                self.isSharingAudio = false
            }
        }
    }
    
    private func findTwoOutputDevices() -> [(deviceID: AudioDeviceID, deviceUID: String)]? {
        guard let audioDevices = AudioDeviceHelper.fetchAllAudioDeviceIDs() else {
            return nil
        }
        
        var bluetoothOutputDevices: [(deviceID: AudioDeviceID, deviceUID: String)] = []
        
        for deviceID in audioDevices {
            var transportTypePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var transportType: UInt32 = 0
            var dataSize = UInt32(MemoryLayout<UInt32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &transportTypePropertyAddress, 0, nil, &dataSize, &transportType)
            
            guard status == noErr,
                  (transportType == kAudioDeviceTransportTypeBluetooth || transportType == kAudioDeviceTransportTypeBluetoothLE),
                  let deviceUID = AudioDeviceHelper.fetchDeviceUID(deviceID: deviceID) else {
                continue
            }
            
            var streamConfigurationAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var streamConfiguration: AudioBufferList = AudioBufferList()
            dataSize = UInt32(MemoryLayout<AudioBufferList>.size)
            let streamStatus = AudioObjectGetPropertyData(deviceID, &streamConfigurationAddress, 0, nil, &dataSize, &streamConfiguration)
            
            if streamStatus == noErr, streamConfiguration.mNumberBuffers > 0 {
                bluetoothOutputDevices.append((deviceID: deviceID, deviceUID: deviceUID))
                
                if bluetoothOutputDevices.count == 2 {
                    break // Stop once we have two Bluetooth output devices
                }
            }
        }
        
        return bluetoothOutputDevices.count == 2 ? bluetoothOutputDevices : nil
    }
    
    private func createMultiOutputDevice(masterDeviceUID: CFString, secondDeviceUID: CFString) -> AudioDeviceID? {
        let multiOutUID = "PairPodsOutputDevice"
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "PairPods Output Device",
            kAudioAggregateDeviceUIDKey: multiOutUID,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: masterDeviceUID],
                [kAudioSubDeviceUIDKey: secondDeviceUID]
            ],
            kAudioAggregateDeviceMasterSubDeviceKey: masterDeviceUID,
            kAudioAggregateDeviceIsStackedKey: 1
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
        var mutableDeviceID = deviceID
        var defaultOutputPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let setStatus = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputPropertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
        
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
        
        guard let deviceID = AudioDeviceHelper.fetchDeviceID(deviceUID: multiOutUID) else {
            return noErr
        }
        
        return removeMultiOutputDevice(deviceID: deviceID)
    }
    
    private func startFreeLicenseTimer() {
        freeLicenseTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            self?.stopFreeLicenseActions()
        }
    }
    
    private func stopFreeLicenseTimer() {
        freeLicenseTimer?.invalidate()
        freeLicenseTimer = nil
    }
    
    private func stopFreeLicenseActions() {
        DispatchQueue.main.async {
            self.isSharingAudio = false
            displayPurchaseInvitation(purchaseManager: self.purchaseManager)
        }
    }
}
