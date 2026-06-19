import Combine
import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    static let monthlyProductID = "com.zdw.oneread.pro.monthly"
    static let yearlyProductID = "com.zdw.oneread.pro.yearly"

    static let productIDs = [
        monthlyProductID,
        yearlyProductID
    ]

    @Published private(set) var products: [Product] = []
    @Published private(set) var hasActiveEntitlement = false
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published var errorMessage: String?

#if DEBUG
    @Published private(set) var debugProOverride: Bool
#endif

    private let defaults: UserDefaults
    private var transactionUpdatesTask: Task<Void, Never>?
    private let debugOverrideKey = "subscriptionDebugProOverride"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
#if DEBUG
        self.debugProOverride = defaults.bool(forKey: debugOverrideKey)
#endif

        transactionUpdatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { return }

                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }

        Task {
            await refresh()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var isPro: Bool {
#if DEBUG
        hasActiveEntitlement || debugProOverride
#else
        hasActiveEntitlement
#endif
    }

    var statusLabel: String {
        isPro ? "Active" : "Free"
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedProducts = try await Product.products(for: Self.productIDs)
            products = loadedProducts.sorted(by: productSort)
        } catch {
            errorMessage = "Subscriptions are temporarily unavailable."
        }

        await refreshEntitlements()
        isLoading = false
    }

    func purchase(_ product: Product) async {
        purchasingProductID = product.id
        errorMessage = nil
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "The App Store could not verify this purchase."
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                errorMessage = "Your purchase is waiting for App Store approval."
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "The purchase could not be completed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro {
                errorMessage = "No active OneRead Pro subscription was found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

#if DEBUG
    func setDebugProOverride(_ enabled: Bool) {
        debugProOverride = enabled
        defaults.set(enabled, forKey: debugOverrideKey)
    }
#endif

    private func refreshEntitlements() async {
        var foundActiveSubscription = false

        for await verification in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded else {
                continue
            }

            if let expirationDate = transaction.expirationDate,
               expirationDate <= Date() {
                continue
            }

            foundActiveSubscription = true
            break
        }

        hasActiveEntitlement = foundActiveSubscription
    }

    private func productSort(_ lhs: Product, _ rhs: Product) -> Bool {
        let order = [
            Self.yearlyProductID: 0,
            Self.monthlyProductID: 1
        ]
        return order[lhs.id, default: 99] < order[rhs.id, default: 99]
    }
}

enum ReadingAccessPolicy {
    static let freePreviewParagraphCount = 1
    static let freeVocabularyCount = 3
    static let freeSavedWordCount = 2

    static func hasFullReadingAccess(
        level: ReadingLevel,
        articleRank: Int,
        isPro: Bool
    ) -> Bool {
        isPro || level == .level3 || (level == .level1 && articleRank == 1)
    }

    static func visibleParagraphs(
        from paragraphs: [LeveledParagraph],
        level: ReadingLevel,
        articleRank: Int,
        isPro: Bool
    ) -> [LeveledParagraph] {
        guard !hasFullReadingAccess(level: level, articleRank: articleRank, isPro: isPro) else {
            return paragraphs
        }
        return Array(paragraphs.prefix(freePreviewParagraphCount))
    }

    static func visibleVocabulary(
        from vocabulary: [ArticleVocabulary],
        isPro: Bool
    ) -> [ArticleVocabulary] {
        isPro ? vocabulary : Array(vocabulary.prefix(freeVocabularyCount))
    }

    static func canShowTranslation(paragraphIndex: Int, isPro: Bool) -> Bool {
        isPro || paragraphIndex == 0
    }

    static func canSaveWord(savedCount: Int, isPro: Bool) -> Bool {
        isPro || savedCount < freeSavedWordCount
    }
}
