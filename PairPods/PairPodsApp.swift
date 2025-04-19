//
//  PairPodsApp.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import LaunchAtLogin
import Sparkle
import StoreKit
import SwiftUI

@main
struct PairPodsApp: App {
    @StateObject private var dependencies = LiveAppDependencies.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ContentView(
                audioSharingManager: dependencies.audioSharingManager,
                audioDeviceManager: dependencies.audioDeviceManager
            )
        } label: {
            MenuBarIcon(
                audioSharingManager: dependencies.audioSharingManager
            )
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_: Notification) {
        Task {
            await LiveAppDependencies.shared.cleanup()
        }
    }
}

struct ContentView: View {
    @ObservedObject private var audioSharingManager: AudioSharingManager
    @ObservedObject private var audioDeviceManager: AudioDeviceManager
    @StateObject private var volumeViewModel: DeviceVolumeViewModel
    @State private var aboutWindow: NSWindow?

    init(audioSharingManager: any AudioSharingManaging, audioDeviceManager: any AudioDeviceManaging) {
        let sharingManager = audioSharingManager as! AudioSharingManager
        let deviceManager = audioDeviceManager as! AudioDeviceManager
        _audioSharingManager = ObservedObject(wrappedValue: sharingManager)
        _audioDeviceManager = ObservedObject(wrappedValue: deviceManager)
        _volumeViewModel = StateObject(wrappedValue: DeviceVolumeViewModel(audioDeviceManager: deviceManager))
    }

    var body: some View {
        VStack(spacing: 12) {
            Toggle("Share Audio", isOn: Binding(
                get: { audioSharingManager.isSharingAudio },
                set: { newValue in
                    if newValue {
                        audioSharingManager.startSharing()
                    } else {
                        audioSharingManager.stopSharing()
                    }
                }
            ))
            .accessibilityIdentifier("shareAudioToggle")
            .keyboardShortcut("s")
            
            // Volume controls section
            GroupBox(label: Label("Device Volumes", systemImage: "speaker.wave.2")) {
                DeviceVolumeView(viewModel: volumeViewModel)
            }
            .padding(.top, 4)

            Divider()

            LaunchAtLogin.Toggle()
                .accessibilityIdentifier("launchAtLoginToggle")

            AutomaticUpdatesToggle()
                .accessibilityIdentifier("automaticUpdatesToggle")

            Button("About") {
                showAboutWindow()
            }
            .accessibilityIdentifier("aboutButton")
            .keyboardShortcut("a")

            Button("Quit") {
                Task {
                    audioSharingManager.stopSharing()
                    try? await Task.sleep(for: .seconds(1))
                    NSApplication.shared.terminate(nil)
                }
            }
            .accessibilityIdentifier("quitButton")
            .keyboardShortcut("q")
        }
        .padding()
        .frame(minWidth: 240)
        .onAppear {
            Task {
                // Refresh the list of devices when the view appears
                await audioDeviceManager.refreshCompatibleDevices()
            }
        }
        .onChange(of: audioSharingManager.isSharingAudio) { nowSharing in
          if nowSharing {
            Task { await audioDeviceManager.refreshCompatibleDevices() }
          }
        }
    }

    private func showAboutWindow() {
        if aboutWindow?.isVisible != true {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "About PairPods"
            window.contentView = NSHostingView(rootView: AboutView())
            window.isReleasedWhenClosed = false
            aboutWindow = window
        }

        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MenuBarIcon: View {
    @ObservedObject private var audioSharingManager: AudioSharingManager

    init(audioSharingManager: any AudioSharingManaging) {
        self.audioSharingManager = audioSharingManager as! AudioSharingManager
    }

    var body: some View {
        Image(systemName: "airpodspro.chargingcase.wireless.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                audioSharingManager.isSharingAudio ? Color.blue : Color.primary,
                audioSharingManager.isSharingAudio ? Color.blue : Color.secondary
            )
            .accessibilityIdentifier("menuBarIcon")
    }
}
