//
//  AppDelegate.swift
//  PairPods
//
//  Created by Pawel Wozniak on 19/06/2024.
//

import Cocoa
import SwiftUI
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var purchaseManager = PurchaseManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkFirstLaunch()
    }

    private func checkFirstLaunch() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            showLicenseManager(purchaseManager: purchaseManager)
        } else if purchaseManager.purchaseState == .free {
            showLicenseManager(purchaseManager: purchaseManager)
        }
    }
}
