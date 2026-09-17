import Foundation
import Observation
import StoreKit

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

    private var updates: Task<Void, Never>?

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
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .userCancelled, .pending:
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

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProductID(rawValue: transaction.productID) != nil, transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    func product(_ id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }
}
