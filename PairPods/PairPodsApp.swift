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

// MARK: - UI Notifications

extension Notification.Name {
    static let showAboutWindow = Notification.Name("ShowAboutWindow")
}

extension NotificationCenter {
    func postShowAboutWindow() {
        post(name: .showAboutWindow, object: nil)
    }
}

@main
struct PairPodsApp: App {
    @StateObject private var dependencies = AppDependencies.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var isMenuPresented: Bool = false

    var body: some Scene {
        MenuBarExtra {
            ContentView(
                audioSharingManager: dependencies.audioSharingManager,
                audioDeviceManager: dependencies.audioDeviceManager,
                audioVolumeManager: dependencies.audioVolumeManager,
                isMenuPresented: $isMenuPresented
            )
        } label: {
            MenuBarIcon(
                audioSharingManager: dependencies.audioSharingManager
            )
        }
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $isMenuPresented)

        Window("About PairPods", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_: Notification) {
        AppDependencies.shared.cleanupSync()
    }

    func applicationDidFinishLaunching(_: Notification) {
        // Register a global keyboard shortcut for settings
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
                // Post notification to show settings
                NotificationCenter.default.postShowAboutWindow()
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
    @Environment(\.openWindow) private var openWindow
    @AppStorage("PairPods.ReconnectTimeout") private var reconnectTimeout: Double = 10.0

    init(
        audioSharingManager: AudioSharingManager,
        audioDeviceManager: AudioDeviceManager,
        audioVolumeManager: AudioVolumeManager,
        isMenuPresented: Binding<Bool>
    ) {
        self.audioSharingManager = audioSharingManager
        self.audioDeviceManager = audioDeviceManager
        self.audioVolumeManager = audioVolumeManager
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
                                await audioSharingManager.startSharing()
                            } else {
                                await audioSharingManager.stopSharing()
                            }
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
            .disabled(
                audioDeviceManager.selectedDevices.count < 2
            )
            .accessibilityIdentifier("shareAudioToggle")
            .keyboardShortcut("s")

            MenuSection(audioDeviceManager.compatibleDevices.isEmpty
                ? "No Connected Devices"
                : audioDeviceManager.compatibleDevices.count == 1
                ? "Connected Device"
                : "Connected Devices")

            DeviceVolumeView(
                audioDeviceManager: audioDeviceManager,
                volumeManager: audioVolumeManager,
                isSharingActive: audioSharingManager.isSharingAudio
            )

            Divider()

            HStack {
                Text("Reconnect")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $reconnectTimeout) {
                    Text("Off").tag(0.0)
                    Text("5s").tag(5.0)
                    Text("10s").tag(10.0)
                    Text("30s").tag(30.0)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .accessibilityIdentifier("reconnectTimeoutPicker")

            LaunchAtLoginMenuToggle()
                .accessibilityIdentifier("launchAtLoginToggle")
                .padding(.horizontal, -10)
                .padding(.vertical, -4)

            AutomaticUpdatesToggle()
                .accessibilityIdentifier("automaticUpdatesToggle")
                .padding(.horizontal, -10)
                .padding(.vertical, -4)

            Divider()

            MenuCommand {
                openWindow(id: "about")
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            } label: {
                HStack {
                    Text("About")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘ A")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                        .padding(.trailing, -8)
                }
            }
            .accessibilityIdentifier("aboutButton")
            .keyboardShortcut("a")
            .padding(.horizontal, -14)
            .padding(.vertical, -4)

            MenuCommand {
                Task {
                    await audioSharingManager.stopSharing()
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                HStack {
                    Text("Quit")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("⌘ Q")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                        .padding(.trailing, -8)
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
                audioVolumeManager.refreshAllVolumes()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAboutWindow)) { _ in
            openWindow(id: "about")
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onReceive(audioSharingManager.$state) { newState in
            guard newState == .active else { return }
            Task {
                await audioDeviceManager.refreshCompatibleDevices()
                audioVolumeManager.refreshAllVolumes()
            }
        }
    }
}

#Preview {
    let deviceManager = AudioDeviceManager(audioSystem: PreviewAudioSystem(), shouldShowAlerts: false)
    let sharingManager = AudioSharingManager(audioDeviceManager: deviceManager)
    let volumeManager = AudioVolumeManager(audioDeviceManager: deviceManager)

    return ContentView(
        audioSharingManager: sharingManager,
        audioDeviceManager: deviceManager,
        audioVolumeManager: volumeManager,
        isMenuPresented: .constant(true)
    )
    .frame(maxWidth: 270)
}

struct MenuBarIcon: View {
    @ObservedObject private var audioSharingManager: AudioSharingManager

    init(audioSharingManager: AudioSharingManager) {
        self.audioSharingManager = audioSharingManager
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

        MenuToggleItem(
            isOn: binding
        ) {
            Text("Launch at Login")
        }
    }
}
