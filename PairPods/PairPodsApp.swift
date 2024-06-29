//
//  PairPodsApp.swift
//  PairPods
//
//  Created by Pawel Wozniak on 02/03/2024.
//

import SwiftUI
import LaunchAtLogin

@main
struct PairPodsApp: App {
    @StateObject private var viewModel: AudioSharingViewModel
    private static var purchaseManager: PurchaseManager = PurchaseManager()

    init() {
        let viewModel = AudioSharingViewModel(purchaseManager: PairPodsApp.purchaseManager)
        _viewModel = StateObject(wrappedValue: viewModel)
        checkFirstLaunch(purchaseManager: PairPodsApp.purchaseManager)
    }

    var body: some Scene {
        MenuBarExtra {
            Toggle(isOn: $viewModel.isSharingAudio) {
                Text("Share Audio")
            }.keyboardShortcut("s")

            Divider()

            LaunchAtLogin.Toggle()

            Button("About") {
                displayAboutWindow(purchaseManager: PairPodsApp.purchaseManager)
            }.keyboardShortcut("a")

            Button("Quit") {
                viewModel.isSharingAudio = false
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")

        } label: {
            let primaryColor = viewModel.isSharingAudio ? Color.blue : Color.primary
            let secondaryColor = viewModel.isSharingAudio ? Color.blue : Color.secondary
            Image(systemName: "earbuds")
                .symbolRenderingMode(.palette)
                .foregroundStyle(primaryColor, secondaryColor)
        } .menuBarExtraStyle(.menu)
    }

    private func checkFirstLaunch(purchaseManager: PurchaseManager) {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            showLicenseManager(purchaseManager: purchaseManager)
        } else if purchaseManager.purchaseState == .free {
            showLicenseManager(purchaseManager: purchaseManager)
        }
    }
}
