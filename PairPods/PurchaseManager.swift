//
//  PurchaseManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 01/06/2024.
//

import StoreKit
import Combine

class PurchaseManager: ObservableObject {
    @Published var purchaseState: PurchaseState = .free
    @Published var trialDaysRemaining: Int = 0
    @Published var products: [Product] = []

    private var trialEndDate: Date?
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

    private func handle(transaction: Transaction) async {
        defer {
            Task {
                await transaction.finish()
            }
        }

        stateQueue.sync {
            if transaction.productID == "LIFETIMELICENSE" && transaction.revocationDate == nil {
                DispatchQueue.main.async {
                    self.purchaseState = .pro
                }
            } else if transaction.productID == "7DAYTRIAL" && transaction.revocationDate == nil {
                let trialStartDate = transaction.originalPurchaseDate
                let trialDays = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
                if trialDays < 7 {
                    DispatchQueue.main.async {
                        if self.purchaseState != .pro {
                            self.purchaseState = .trial(daysRemaining: 7 - trialDays)
                            self.trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: trialStartDate)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        if self.purchaseState != .pro {
                            self.purchaseState = .free
                        }
                    }
                }
            }
        }
    }

    func getCurrentLicenseType() -> String {
        switch purchaseState {
        case .free:
            return "Free"
        case let .trial(daysRemaining):
            return "Trial (\(daysRemaining) days remaining)"
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
    case trial(daysRemaining: Int)
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
