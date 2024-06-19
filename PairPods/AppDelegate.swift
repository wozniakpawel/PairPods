//
//  AppDelegate.swift
//  PairPods
//
//  Created by Pawel Wozniak on 19/06/2024.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var purchaseManager = PurchaseManager()
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkFirstLaunch()
    }

    private func checkFirstLaunch() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            showLicenseManager()
        } else if purchaseManager.purchaseState == .free {
            showLicenseManager()
        }
    }

    private func showLicenseManager() {
        let licenseManagerView = LicenseManager().environmentObject(purchaseManager)
        let hostingController = NSHostingController(rootView: licenseManagerView)
        window = NSWindow(contentViewController: hostingController)
        window.title = "License Manager"
        window.setContentSize(NSSize(width: 400, height: 300))
        window.styleMask = [.titled, .closable, .resizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
