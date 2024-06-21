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
            VStack(spacing: 4) {
                Text("Welcome to PairPods!")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top)
                
                Text("Please select your desired license type.")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 20)
            
            if purchaseManager.products.isEmpty {
                Text("Loading products...")
                    .padding()
            } else {
                VStack(spacing: 16) {
                    productSelectionView(
                        title: "PairPods Free",
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
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle()) // Ensure custom button style is applied
            .padding(.horizontal)
            
            Button(action: {
                purchaseManager.restorePurchases()
            }) {
                Text("Restore Purchases")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle()) // Ensure custom button style is applied
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 550) // Minimum window size
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
        .contentShape(Rectangle()) // Make entire area tappable
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
