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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "airpods.gen3", accessibilityDescription: "PairPods")
        
        // Set up the menu for the status bar item
        let menu = NSMenu()
        statusItem.menu = menu
        
        // Create the toggle menu item with custom view
        let toggleItem = NSMenuItem()
        let toggleView = ToggleNSView(frame: NSRect(x: 0, y: 0, width: 150, height: 30))
        toggleView.configure(with: viewModel)
        toggleItem.view = toggleView
        
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: "a")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
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
