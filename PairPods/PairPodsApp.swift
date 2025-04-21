//
//  PairPodsApp.swift
//  PairPods
//
//  Created by Pawel Wozniak on 24/02/2025.
//

import LaunchAtLogin
import MacControlCenterUI
import Sparkle
import StoreKit
import SwiftUI

@main
struct PairPodsApp: App {
    @StateObject private var dependencies = LiveAppDependencies.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var isMenuPresented: Bool = false

    var body: some Scene {
        MenuBarExtra {
            ContentView(
                audioSharingManager: dependencies.audioSharingManager as! AudioSharingManager,
                audioDeviceManager: dependencies.audioDeviceManager as! AudioDeviceManager,
                audioVolumeManager: dependencies.audioVolumeManager as! AudioVolumeManager,
                isMenuPresented: $isMenuPresented
            )
        } label: {
            MenuBarIcon(
                audioSharingManager: dependencies.audioSharingManager as! AudioSharingManager
            )
        }
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $isMenuPresented)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_: Notification) {
        Task {
            await LiveAppDependencies.shared.cleanup()
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Register a global keyboard shortcut for settings
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
                // Post notification to show settings
                NotificationCenter.default.post(name: NSNotification.Name("ShowAboutWindow"), object: nil)
                return nil
            }
            return event
        }
    }
}

struct ContentView: View {
    @ObservedObject private var audioSharingManager: AudioSharingManager
    @ObservedObject private var audioDeviceManager: AudioDeviceManager
    @ObservedObject private var audioVolumeManager: AudioVolumeManager
    @Binding private var isMenuPresented: Bool
    @State private var settingsWindow: NSWindow?
    @State private var aboutWindow: NSWindow?

    init(
        audioSharingManager: any AudioSharingManaging,
        audioDeviceManager: any AudioDeviceManaging,
        audioVolumeManager: any AudioVolumeManaging,
        isMenuPresented: Binding<Bool>
    ) {
        self.audioSharingManager = audioSharingManager as! AudioSharingManager
        self.audioDeviceManager = audioDeviceManager as! AudioDeviceManager
        self.audioVolumeManager = audioVolumeManager as! AudioVolumeManager
        _isMenuPresented = isMenuPresented
    }

    var body: some View {
        MacControlCenterMenu(isPresented: $isMenuPresented) {
            HStack {
                Text("Share Audio")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { audioSharingManager.isSharingAudio },
                    set: { newValue in
                        Task {
                            if newValue {
                                audioSharingManager.startSharing()
                            } else {
                                audioSharingManager.stopSharing()
                            }
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
            .disabled(
                audioDeviceManager.compatibleDevices.count < 2
            )
            .accessibilityIdentifier("shareAudioToggle")
            .keyboardShortcut("s")

            MenuSection(audioDeviceManager.compatibleDevices.isEmpty
                ? "No Connected Devices"
                : audioDeviceManager.compatibleDevices.count == 1
                ? "Connected Device"
                : "Connected Devices"
            )

            DeviceVolumeView(
                audioDeviceManager: audioDeviceManager,
                volumeManager: audioVolumeManager
            )
            .disabled(
                !audioSharingManager.isSharingAudio &&
                    !audioDeviceManager.compatibleDevices.isEmpty
            )

            Divider()

            LaunchAtLoginMenuToggle()
                .accessibilityIdentifier("launchAtLoginToggle")
                .padding(.horizontal, -14)
                .padding(.vertical, -4)

            AutomaticUpdatesToggle()
                .accessibilityIdentifier("automaticUpdatesToggle")
                .padding(.horizontal, -14)
                .padding(.vertical, -4)


            Divider()

            MenuCommand {
                showAboutWindow()
            } label: {
                HStack {
                    Text("About")
                    Spacer()
                    Text("⌘ A")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
            }
            .accessibilityIdentifier("aboutButton")
            .keyboardShortcut("a")
            .padding(.horizontal, -14)
            .padding(.vertical, -4)

            MenuCommand {
                Task {
                    audioSharingManager.stopSharing()
                    try? await Task.sleep(for: .seconds(0.5))
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                HStack {
                    Text("Quit")
                    Spacer()
                    Text("⌘ Q")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
            }
            .accessibilityIdentifier("quitButton")
            .keyboardShortcut("q")
            .padding(.horizontal, -14)
            .padding(.vertical, -4)
        }
        .onAppear {
            Task {
                await audioDeviceManager.refreshCompatibleDevices()
                await audioVolumeManager.refreshAllVolumes()
            }

            // Add observer for settings shortcut notification
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ShowAboutWindow"),
                object: nil,
                queue: .main
            ) { _ in
                showAboutWindow()
            }
        }
        .onChange(of: audioSharingManager.isSharingAudio) { isSharing in
            Task {
                if isSharing {
                    await audioDeviceManager.refreshCompatibleDevices()
                    await audioVolumeManager.refreshAllVolumes()
                }
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

#Preview {
    ContentView(
        audioSharingManager: AudioSharingManager(audioDeviceManager: AudioDeviceManager()),
        audioDeviceManager: AudioDeviceManager(),
        audioVolumeManager: AudioVolumeManager(audioDeviceManager: AudioDeviceManager()),
        isMenuPresented: .constant(true)
    )
    .frame(maxWidth: 270)
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

struct LaunchAtLoginMenuToggle: View {
    var body: some View {
        let binding = Binding<Bool>(
            get: { LaunchAtLogin.isEnabled },
            set: { LaunchAtLogin.isEnabled = $0 }
        )

        MenuToggle(isOn: binding, style: .checkmark()) {
            Text("Launch at Login")
        }
    }
}
