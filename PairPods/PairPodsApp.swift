//
//  PairPodsApp.swift
//  PairPods
//
//  Created by Pawel Wozniak on 02/03/2024.
//

import SwiftUI

@main
struct PairPodsApp: App {
    @StateObject private var viewModel = AudioSharingViewModel()
    
    var body: some Scene {
        
        MenuBarExtra {
            
            Toggle(isOn: $viewModel.isSharingAudio) {
                Text("Share Audio")
            }.keyboardShortcut("s")

            Divider()

            Button("About") {
                displayAboutWindow()
            }.keyboardShortcut("a")
            
            Button("Quit") {
                viewModel.isSharingAudio = false
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
            
        } label: {
            let currentColor = viewModel.isSharingAudio ? Color.blue : Color.red
            Image(systemName: "airpodspro.chargingcase.wireless.radiowaves.left.and.right.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.primary, currentColor, Color.blue)
                .animation(.interpolatingSpring(stiffness: 100, damping: 10), value: viewModel.isSharingAudio)
        }
    }
}
