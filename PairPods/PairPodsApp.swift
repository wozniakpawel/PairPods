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
            Image(systemName: "airpodspro.chargingcase.wireless.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(viewModel.isSharingAudio ? Color.blue : Color.white)
        }
    }
}
