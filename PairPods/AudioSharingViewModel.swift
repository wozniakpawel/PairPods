//
//  AudioSharingViewModel.swift
//  PairPods
//
//  Created by Pawel Wozniak on 04/03/2024.
//

import Foundation

class AudioSharingViewModel: ObservableObject {
    @Published var isSharingAudio = false

    func toggleAudioSharing() {
        isSharingAudio.toggle() // Toggle the state
        if isSharingAudio {
            startSharingAudio()
        } else {
            stopSharingAudio()
        }
    }

    private func startSharingAudio() {
        // Implement the logic to start sharing audio
        print("Starting to share audio...")
        // Your code goes here
    }

    private func stopSharingAudio() {
        // Implement the logic to stop sharing audio
        print("Stopping audio sharing...")
        // Your code goes here
    }
}
