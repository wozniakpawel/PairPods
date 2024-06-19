//
//  LicenseManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 01/06/2024.
//

import SwiftUI

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
            
            Text("Please select an option:")
                .padding()
            
            Picker("Select an option", selection: $selectedOption) {
                Text("Use for free").tag(PurchaseState.free)
                if let trialProduct = purchaseManager.products.first(where: { $0.id == "7DAYTRIAL" }) {
                    Text("\(trialProduct.displayName) (\(trialProduct.displayPrice))").tag(PurchaseState.trial(daysRemaining: 7))
                }
                if let fullProduct = purchaseManager.products.first(where: { $0.id == "LIFETIMELICENSE" }) {
                    Text("\(fullProduct.displayName) (\(fullProduct.displayPrice))").tag(PurchaseState.pro)
                }
            }
            .pickerStyle(RadioGroupPickerStyle())
            .padding()
            
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
