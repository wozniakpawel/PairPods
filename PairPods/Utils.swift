//
//  Utils.swift
//  PairPods
//
//  Created by Pawel Wozniak on 16/03/2024.
//

import AppKit
import SwiftUI

func displayAboutWindow(purchaseManager: PurchaseManager) {
    var statusText = "License status: Free"
    if case let .trial(daysRemaining) = purchaseManager.purchaseState {
        statusText = "License status: Trial (\(daysRemaining) days remaining)"
    } else if case .pro = purchaseManager.purchaseState {
        statusText = "License status: Pro"
    }

    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = """
        PairPods
        Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
        Copyright © \(Calendar.current.component(.year, from: Date())) Vantabyte
        \n\(statusText)
        """
        if purchaseManager.purchaseState != .pro {
            alert.addButton(withTitle: "Manage License")
            alert.addButton(withTitle: "Close")
        } else {
            alert.addButton(withTitle: "Close")
        }
        let response = alert.runModal()
        if response == .alertFirstButtonReturn && purchaseManager.purchaseState != .pro {
            showLicenseManager(purchaseManager: purchaseManager)
        }
    }
}

func displayPurchaseInvitation(purchaseManager: PurchaseManager) {
    let alert = NSAlert()
    alert.messageText = "Trial Ended"
    alert.informativeText = "Please purchase the full version to continue using PairPods."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Manage License")
    alert.addButton(withTitle: "Close")
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        showLicenseManager(purchaseManager: purchaseManager)
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
