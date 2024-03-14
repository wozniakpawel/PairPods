//
//  AppDelegate.swift
//  PairPods
//
//  Created by Pawel Wozniak on 14/03/2024.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var viewModel = AudioSharingViewModel()
        
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(updateShareAudioToggle), name: NSNotification.Name("updateShareAudioToggle"), object: nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up the menu for the status bar item
        let menu = NSMenu()
        
        // Create the toggle menu item with custom view
        let toggleItem = NSMenuItem()
        let toggleView = ToggleNSView(frame: NSRect(x: 0, y: 0, width: 150, height: 30))
        toggleView.toggleSwitch.target = self
        toggleView.toggleSwitch.action = #selector(toggleAudioSharing(_:))
        toggleItem.view = toggleView
        
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "a")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.image = NSImage(systemSymbolName: "airpods.gen3", accessibilityDescription: "PairPods")
    }
    
    @objc func toggleAudioSharing(_ sender: NSSwitch) {
        viewModel.isSharingAudio = (sender.state == .on)
    }
    
    @objc func updateShareAudioToggle() {
        if let toggleItemView = statusItem.menu?.item(withTitle: "Share Audio")?.view as? ToggleNSView {
            toggleItemView.toggleSwitch.state = viewModel.isSharingAudio ? .on : .off
        }
    }
    
    @objc func showAbout() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "PairPods\nVersion: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")\nVertex Forge © \(Calendar.current.component(.year, from: Date()))"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    @objc func quitApp() {
        viewModel.isSharingAudio = false
        NSApplication.shared.terminate(nil)
    }
}
