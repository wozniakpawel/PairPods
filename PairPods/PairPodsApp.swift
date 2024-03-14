//
//  PairPodsApp.swift
//  PairPods
//
//  Created by Pawel Wozniak on 02/03/2024.
//

import SwiftUI

@main
struct PairPodsApp: App {
    var body: some Scene {
        MenuBarExtra("PairPods", systemImage: "airpods.gen3") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarContentView: View {
    @StateObject private var viewModel = AudioSharingViewModel()

    var body: some View {
        Toggle("Share Audio", isOn: $viewModel.isSharingAudio)
            .padding()
            .toggleStyle(.switch)
            .controlSize(.mini)
        
        Divider()
                    
        Button("About") {
            showAbout()
        }.keyboardShortcut("a")
        
        Button("Quit") {
            gracefulShutdown()
        }.keyboardShortcut("q")
    }

    func gracefulShutdown() {
        viewModel.isSharingAudio = false
        NSApplication.shared.terminate(nil)
    }
    
    func showAbout() {
        let alert = NSAlert()
        alert.messageText = "PairPods\nVersion: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")\nCopyright (C) Vertex Forge \(Calendar.current.component(.year, from: Date()))"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
