//
//  AboutView.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import Sparkle
import SwiftUI

struct AboutView: View {
    @StateObject private var updaterViewModel = UpdaterViewModel()
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

    var body: some View {
        VStack(spacing: 16) {
            // App info section
            VStack(spacing: 8) {
                Text("PairPods")
                    .font(.title)
                    .bold()
                Text("Version \(version) (Build \(build))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Made with ❤️ by Pawel Wozniak")
                    .font(.subheadline)
            }

            Divider()

            // Links section
            VStack(spacing: 12) {
                // GitHub Repository
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "https://github.com/wozniakpawel/PairPods")!)
                }) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .imageScale(.large)
                            .foregroundColor(.blue)
                        Text("View code on GitHub")
                    }
                    .frame(maxWidth: 200)
                }
                .buttonStyle(.link)

                // GitHub Sponsor
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/wozniakpawel")!)
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .imageScale(.large)
                            .foregroundColor(.pink)
                        Text("Sponsor on GitHub")
                    }
                    .frame(maxWidth: 200)
                }
                .buttonStyle(.link)

                // Buy Me a Coffee
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "https://www.buymeacoffee.com/wozniakpawel")!)
                }) {
                    HStack {
                        Text("☕")
                            .font(.title2)
                        Text("Buy me a coffee")
                    }
                    .frame(maxWidth: 200)
                }
                .buttonStyle(.link)
            }

            Divider()

            Button("Check for Updates...") {
                updaterViewModel.checkForUpdates()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(width: 300)
    }
}
