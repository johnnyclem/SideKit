import Foundation
import StoreKit

/// StoreKit 2 non-consumable Pro unlock + offline-safe restore (SK-044).
/// Free tier stays useful: 1 deck focus, basic FX, hardware link. Pro unlocks dual-deck
/// advanced (hot cues/loops/±16% pitch), full FX depth control, and snapshots (SK-045/046).
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static let proProductId = "com.johnnyclem.SideKit.pro"

    @Published private(set) var isPro: Bool
    @Published private(set) var product: Product?
    @Published var purchaseError: String?

    private let entitlementKey = "sk.pro.entitled"
    private var updatesTask: Task<Void, Never>?

    private init() {
        isPro = UserDefaults.standard.bool(forKey: entitlementKey)
        updatesTask = Task { [weak self] in await self?.observeTransactionUpdates() }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlement()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        guard let products = try? await Product.products(for: [Self.proProductId]) else { return }
        product = products.first
    }

    /// Restores offline: `Transaction.currentEntitlements` reflects the on-device receipt
    /// cache, no network call required (SK-044 acceptance: "restore offline-safe").
    func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.proProductId {
                entitled = true
            }
        }
        setEntitled(entitled)
    }

    func purchase() async {
        guard let product else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    setEntitled(true)
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Try again or restore purchases."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            // Offline-safe: fall through to local entitlement check regardless.
        }
        await refreshEntitlement()
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result, transaction.productID == Self.proProductId {
                setEntitled(true)
                await transaction.finish()
            }
        }
    }

    private func setEntitled(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: entitlementKey)
    }
}
