//
//  PurchaseManager.swift
//  PairPods
//
//  Created by Pawel Wozniak on 01/06/2024.
//

import StoreKit

class PurchaseManager: ObservableObject {
    @Published var purchaseState: PurchaseState = .free
    @Published var trialDaysRemaining: Int = 0
    @Published var products: [Product] = []
    
    private var trialEndDate: Date?
    
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
                        checkPurchaseState()
                        completion(.success(()))
                    case .pending, .userCancelled:
                        completion(.failure(PurchaseError.purchaseCancelled))
                    @unknown default:
                        completion(.failure(PurchaseError.unknown))
                    }
                } else {
                    completion(.failure(PurchaseError.productNotFound))
                }
            } catch {
                completion(.failure(error))
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

        if transaction.productID == "LIFETIMELICENSE" && transaction.revocationDate == nil {
            purchaseState = .pro
            return
        } else if transaction.productID == "7DAYTRIAL" && transaction.revocationDate == nil {
            let trialStartDate = transaction.originalPurchaseDate
            let trialDays = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
            if trialDays < 7 {
                purchaseState = .trial(daysRemaining: 7 - trialDays)
                trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: trialStartDate)
            } else {
                purchaseState = .free
            }
            return
        }
    }
}

enum PurchaseState: Hashable {
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
