//
//  LicenseManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 01/06/2024.
//

import SwiftUI
import AppKit

private var licenseManagerWindow: NSWindow?
private var licenseManagerWindowDelegate: LicenseManagerWindowDelegate?

func showLicenseManager(purchaseManager: PurchaseManager) {
    if licenseManagerWindow != nil {
        licenseManagerWindow?.makeKeyAndOrderFront(nil)
        return
    }

    let licenseManagerView = LicenseManager().environmentObject(purchaseManager)
    let hostingController = NSHostingController(rootView: licenseManagerView)
    let window = NSWindow(contentViewController: hostingController)
    window.title = "License Manager"
    window.setContentSize(NSSize(width: 400, height: 300))
    window.styleMask = [.titled, .closable, .resizable]
    window.center()
    window.makeKeyAndOrderFront(nil)
    
    let delegate = LicenseManagerWindowDelegate() // Create the delegate
    window.delegate = delegate
    licenseManagerWindowDelegate = delegate // Retain the delegate
    licenseManagerWindow = window
}

private class LicenseManagerWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == licenseManagerWindow {
            licenseManagerWindow = nil
            licenseManagerWindowDelegate = nil // Release the delegate reference
        }
    }
}

struct LicenseManager: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedOption: PurchaseState = .free

    var body: some View {
        VStack {
            Text("Welcome to PairPods!")
                .font(.largeTitle)
                .padding()
            
            Text("""
                 You are welcome to use PairPods Free for as long as you like, but the audio sharing feature is limited to 5 minutes at a time.
                 Alternatively, you can try our 7-day trial version for unlimited audio sharing, or purchase a lifetime Pro version license.
                 """)
                .padding()
            
            if purchaseManager.products.isEmpty {
                Text("Loading products...")
                    .padding()
            } else {
                Picker("Select an option", selection: $selectedOption) {
                    Text("Continue using for free (audio sharing limited to 5 minutes at a time)").tag(PurchaseState.free)
                    if let trialProduct = purchaseManager.products.first(where: { $0.id == "7DAYTRIAL" }) {
                        Text("\(trialProduct.displayName) (\(trialProduct.displayPrice))").tag(PurchaseState.trial(daysRemaining: 7))
                    }
                    if let fullProduct = purchaseManager.products.first(where: { $0.id == "LIFETIMELICENSE" }) {
                        Text("\(fullProduct.displayName) (\(fullProduct.displayPrice))").tag(PurchaseState.pro)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
                .padding()
            }
            
            Button(action: {
                handleContinue()
            }) {
                Text("Continue")
            }
            .padding()
            
            Button(action: {
                purchaseManager.restorePurchases()
            }) {
                Text("Restore Purchases")
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Purchase Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            purchaseManager.fetchProducts()
        }
    }
    
    private func handleContinue() {
        switch selectedOption {
        case .free:
            purchaseManager.purchaseState = .free
        case .trial:
            purchaseManager.purchase(productID: "7DAYTRIAL") { result in
                handlePurchaseResult(result)
            }
        case .pro:
            purchaseManager.purchase(productID: "LIFETIMELICENSE") { result in
                handlePurchaseResult(result)
            }
        }
    }
    
    private func handlePurchaseResult(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            break // Purchase was successful
        case .failure(let error):
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}
