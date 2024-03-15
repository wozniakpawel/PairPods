//
//  Utils.swift
//  PairPods
//
//  Created by Pawel Wozniak on 16/03/2024.
//

import AppKit

func displayAboutWindow() {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = "PairPods\nVersion: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")\nVertex Forge © \(Calendar.current.component(.year, from: Date()))"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

func handleError(_ message: String) {
    DispatchQueue.main.async {
        print(message)
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        if let warningIcon = NSImage(named: NSImage.cautionName) {
            alert.icon = warningIcon
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

