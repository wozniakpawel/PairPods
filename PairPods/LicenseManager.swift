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
    window.title = "PairPods License Manager"
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
                .fixedSize(horizontal: false, vertical: true)
            
            if purchaseManager.products.isEmpty {
                Text("Loading products...")
                    .padding()
            } else {
                VStack(spacing: 16) {
                    productSelectionView(
                        title: "Continue using for free",
                        description: "Use for free for as long as you like. Audio sharing limited to 5 minutes at a time.",
                        price: "",
                        isSelected: selectedOption == .free,
                        selectionAction: { selectedOption = .free }
                    )
                    if let trialProduct = purchaseManager.products.first(where: { $0.id == "7DAYTRIAL" }) {
                        productSelectionView(
                            title: trialProduct.displayName,
                            description: trialProduct.description,
                            price: trialProduct.displayPrice,
                            isSelected: selectedOption == .trial(daysRemaining: 7),
                            selectionAction: { selectedOption = .trial(daysRemaining: 7) }
                        )
                    }
                    if let fullProduct = purchaseManager.products.first(where: { $0.id == "LIFETIMELICENSE" }) {
                        productSelectionView(
                            title: fullProduct.displayName,
                            description: fullProduct.description,
                            price: fullProduct.displayPrice,
                            isSelected: selectedOption == .pro,
                            selectionAction: { selectedOption = .pro }
                        )
                    }
                }
                .padding()
            }
            
            Button(action: {
                handleContinue()
            }) {
                Text("Continue")
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            Button(action: {
                purchaseManager.restorePurchases()
            }) {
                Text("Restore Purchases")
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300) // Minimum window size
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Purchase Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            purchaseManager.fetchProducts()
        }
    }
    
    private func productSelectionView(title: String, description: String, price: String, isSelected: Bool, selectionAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(price)
                    .font(.headline)
            }
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true) // Allow text wrapping
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(10))
        .onTapGesture {
            selectionAction()
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
