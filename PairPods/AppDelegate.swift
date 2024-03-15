//
//  AppDelegate.swift
//  PairPods
//
//  Created by Pawel Wozniak on 14/03/2024.
//

import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var viewModel = AudioSharingViewModel()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel.isSharingAudio = false // destroy output device on startup
        statusItem = NSStatusBar.system.statusItem(withLength: 30)
        setupStatusBar()
        bindViewModel()
    }
      
    private func setupStatusBar() {
        let menu = NSMenu()
        statusItem.menu = menu
        
        menu.addItem(withTitle: "Share Audio", action: #selector(toggleAudioSharing), keyEquivalent: "s")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "About", action: #selector(showAbout), keyEquivalent: "a")
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
    }
       
    private func bindViewModel() {
        viewModel.$isSharingAudio
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: updateStatusItemIcon(isSharing:))
            .store(in: &cancellables)
    }
        
    private func updateStatusItemIcon(isSharing: Bool) {
        let iconName = isSharing ? "airpodspro.chargingcase.wireless.radiowaves.left.and.right.fill" : "airpodspro.chargingcase.wireless.fill"
        statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "PairPods")
    }
    
    @objc private func showAbout() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "PairPods\nVersion: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")\nVertex Forge © \(Calendar.current.component(.year, from: Date()))"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc private func quitApp() {
        viewModel.isSharingAudio = false
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func toggleAudioSharing() {
        viewModel.isSharingAudio.toggle()
    }
}
