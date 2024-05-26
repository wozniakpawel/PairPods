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
        alert.messageText = """
        PairPods
        Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
        Copyright © \(Calendar.current.component(.year, from: Date())) Vantabyte
        """
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
        alert.icon = NSImage(named: NSImage.cautionName)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
