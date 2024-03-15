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
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "PairPods\nVersion: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")\nVertex Forge © \(Calendar.current.component(.year, from: Date()))"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }.keyboardShortcut("a")
            
            Button("Quit") {
                viewModel.isSharingAudio = false
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
            
        } label: {
            Image(systemName: viewModel.isSharingAudio ? "airpodspro.chargingcase.wireless.radiowaves.left.and.right.fill" : "airpodspro.chargingcase.wireless.fill")
                .labelStyle(IconOnlyLabelStyle())
        }
    }
}
