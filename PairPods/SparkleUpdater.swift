//
//  SparkleUpdater.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import MacControlCenterUI
import Sparkle
import SwiftUI

final class SparkleUpdater {
    static let shared = SparkleUpdater()
    let updaterController: SPUUpdater

    private init() {
        let driver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)
        do {
            updaterController = try SPUUpdater(
                hostBundle: Bundle.main,
                applicationBundle: Bundle.main,
                userDriver: driver,
                delegate: nil
            )
            try updaterController.start()
        } catch {
            fatalError("Failed to initialize SPUUpdater: \(error)")
        }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates()
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.automaticallyChecksForUpdates }
        set { updaterController.automaticallyChecksForUpdates = newValue }
    }
}

final class UpdaterViewModel: ObservableObject {
    private let updater = SparkleUpdater.shared

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }
}

struct AutomaticUpdatesToggle: View {
    @StateObject private var updaterViewModel = UpdaterViewModel()

    var body: some View {
        MenuToggleItem(
            isOn: Binding(
                get: { updaterViewModel.automaticallyChecksForUpdates },
                set: {
                    updaterViewModel.automaticallyChecksForUpdates = $0
                    updaterViewModel.objectWillChange.send()
                }
            ),
            action: {
                updaterViewModel.automaticallyChecksForUpdates.toggle()
                updaterViewModel.objectWillChange.send()
            }
        ) {
            Text("Automatic Updates")
        }
    }
}

#Preview {
    AutomaticUpdatesToggle()
        .frame(width: 300, height: 300)
}

extension UpdaterViewModel {
    func toggleAutomaticChecks(_ newValue: Bool) {
        automaticallyChecksForUpdates = newValue
        // Notify any observers that the state has changed
        objectWillChange.send()
    }
}
