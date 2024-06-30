//
//  PurchaseManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 01/06/2024.
//

import StoreKit
import Combine
import SwiftUI

class PurchaseManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchaseState: PurchaseState = .free
    @Published var trialWasPurchased: Bool = false
    @Published var trialStartDate: Date?
    @Published var trialEndDate: Date?
    @Published var trialDaysRemaining: Int = 0
    @AppStorage("successfulSharesCount") var successfulSharesCount = 0

    private let stateQueue = DispatchQueue(label: "com.vantabyte.PairPods.PurchaseManager")

    init() {
        checkPurchaseState()
        fetchProducts()
        Task {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await self.handle(transaction: transaction)
                case .unverified(_, let error):
                    print("Unverified transaction: \(error.localizedDescription)")
                }
            }
        }
    }

    func fetchProducts() {
        Task {
            do {
                let storeProducts = try await Product.products(for: ["7DAYTRIAL", "LIFETIMELICENSE"])
                DispatchQueue.main.async {
                    self.products = storeProducts
                }
            } catch {
                print("Failed to fetch products: \(error)")
            }
        }
    }

    func checkPurchaseState() {
        Task {
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    print(transaction)
                    await handle(transaction: transaction)
                case .unverified(_, let error):
                    print("Unverified transaction: \(error.localizedDescription)")
                }
            }
        }
    }

    func purchase(productID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                if let product = products.first(where: { $0.id == productID }) {
                    let result = try await product.purchase()
                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            self.checkPurchaseState()
                            completion(.success(()))
                        }
                    case .pending, .userCancelled:
                        DispatchQueue.main.async {
                            completion(.failure(PurchaseError.purchaseCancelled))
                        }
                    @unknown default:
                        DispatchQueue.main.async {
                            completion(.failure(PurchaseError.unknown))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(PurchaseError.productNotFound))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func restorePurchases() {
        Task {
            do {
                try await AppStore.sync()
                checkPurchaseState()
            } catch {
                print("Failed to restore purchases: \(error)")
            }
        }
    }

    private func handle(transaction: StoreKit.Transaction) async {
        defer {
            Task {
                await transaction.finish()
            }
        }

        stateQueue.sync {
            let productID = transaction.productID
            let revocationDate = transaction.revocationDate
            
            if productID == "LIFETIMELICENSE" && revocationDate == nil {
                DispatchQueue.main.async {
                    self.purchaseState = .pro
                }
            } else if productID == "7DAYTRIAL" && revocationDate == nil {
                let trialStartDate = transaction.originalPurchaseDate
                let currentDate = Date()
                let trialDaysPassed = Calendar.current.dateComponents([.day], from: trialStartDate, to: currentDate).day ?? 0

                DispatchQueue.main.async {
                    self.trialWasPurchased = true
                    self.trialStartDate = trialStartDate
                    self.trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: trialStartDate)
                }

                DispatchQueue.main.async {
                    if self.purchaseState != .pro {
                        if trialDaysPassed < 7 {
                            self.purchaseState = .trial
                            self.trialDaysRemaining = 7 - trialDaysPassed
                        } else {
                            self.purchaseState = .free
                        }
                    }
                }
            }
        }
    }
    
    func incrementSuccessfulShares() {
        successfulSharesCount += 1
    }

    func getCurrentLicenseType() -> String {
        switch purchaseState {
        case .free:
            return "Free"
        case .trial:
            return "Trial (\(trialDaysRemaining) days remaining)"
        case .pro:
            return "Pro"
        }
    }
}

func displayPurchaseInvitation(purchaseManager: PurchaseManager) {
    let alert = NSAlert()
    alert.messageText = "Audio Sharing Stopped"
    alert.informativeText = """
    We hope you're enjoying using PairPods!
    PairPods' free audio sharing is limited to 5 minutes per session.
    You can start another free session right away, or consider upgrading to PairPods Pro to unlock unlimited audio sharing.
    """
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Manage License")
    alert.addButton(withTitle: "Close")
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        showLicenseManager(purchaseManager: purchaseManager)
    }
}

enum PurchaseState: Hashable, Codable {
    case free
    case trial
    case pro
}

enum PurchaseError: Error, LocalizedError {
    case purchaseCancelled
    case productNotFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .productNotFound:
            return "Product not found."
        case .unknown:
            return "Unknown error occurred."
        }
    }
}
