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
            let iconName = viewModel.isSharingAudio ? "airpodspro.chargingcase.wireless.radiowaves.left.and.right.fill" : "airpodspro.chargingcase.wireless.fill"
            let menuIcon = prepareMenuIcon(imageName: iconName, targetWidth: 30)
            Image(nsImage: menuIcon)
        }
    }
}
