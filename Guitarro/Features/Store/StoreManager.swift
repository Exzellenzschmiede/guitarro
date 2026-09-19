import Foundation
import Observation
import StoreKit
import os

/// What the free tier includes; everything else needs Guitarro Pro.
enum FreeTier {
    static let storyChapters = 2
    static let songs = 3
}

/// StoreKit 2 wrapper: products, purchases, restore and the Pro entitlement.
@MainActor
@Observable
final class StoreManager {
    enum ProductID: String, CaseIterable {
        case monthly = "de.kaniut.guitarro.pro.monthly"
        case yearly = "de.kaniut.guitarro.pro.yearly"
        case lifetime = "de.kaniut.guitarro.pro.lifetime"
    }

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var purchaseInProgress = false
    private(set) var lastError: String?
    /// Debug builds only: pretend to own Pro so every screen can be tested in the simulator.
    var debugProOverride = false

    /// Products granted by a verified purchase or update in this session. Kept separately
    /// because `Transaction.currentEntitlements` can lag behind a purchase in the sandbox.
    private var grantedProductIDs: Set<String> = []
    private var updates: Task<Void, Never>?
    private static let logger = Logger(subsystem: "de.kaniut.guitarro", category: "Store")

    var hasPro: Bool {
        #if DEBUG
        return isPro || debugProOverride
        #else
        return isPro
        #endif
    }

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.grant(transaction)
                    await self?.refreshEntitlements()
                }
            }
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        do {
            let loaded = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
        isLoading = false
    }

    func purchase(_ product: Product) async -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    grant(transaction)
                    await refreshEntitlements()
                    Self.logger.notice("Purchased \(transaction.productID, privacy: .public); pro=\(self.isPro)")
                    return true
                case .unverified(_, let error):
                    Self.logger.error("Unverified purchase: \(error.localizedDescription, privacy: .public)")
                    lastError = String(localized: "pro.error.unverified")
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                lastError = String(localized: "pro.error.pending")
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    /// Marks a verified transaction as owned right away.
    private func grant(_ transaction: Transaction) {
        guard ProductID(rawValue: transaction.productID) != nil else { return }
        if transaction.revocationDate == nil {
            grantedProductIDs.insert(transaction.productID)
        } else {
            grantedProductIDs.remove(transaction.productID)
        }
        isPro = isPro || !grantedProductIDs.isEmpty
    }

    func refreshEntitlements() async {
        var owned = false
        var seen = 0
        for await result in Transaction.currentEntitlements {
            seen += 1
            guard case .verified(let transaction) = result else { continue }
            if ProductID(rawValue: transaction.productID) != nil, transaction.revocationDate == nil {
                owned = true
            }
        }
        Self.logger.notice("Entitlements: \(seen) transactions, owned=\(owned), granted=\(self.grantedProductIDs.count)")
        isPro = owned || !grantedProductIDs.isEmpty
    }

    func product(_ id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }
}
