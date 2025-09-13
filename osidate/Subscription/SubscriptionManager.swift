//
//  SubscriptionManager.swift
//  osidate
//
//  サブスクリプション状態管理クラス
//

import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isSubscribed: Bool = false
    @Published var currentSubscription: Product?
    @Published var availableSubscriptions: [Product] = []
    @Published var isLoading: Bool = false
    
    // サブスクリプション商品ID（App Store Connectで設定した正確なIDを使用）
    private let subscriptionProductIDs = [
        "oshiKoiWeeklySub",    // ¥480/週
        "oshiKoiMonthlySub",   // ¥980/月
        "oshiKoiYearlySub"     // ¥9,800/年
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // アプリ起動時にサブスクリプション状態をチェック
        updateListenerTask = listenForTransactions()
        Task {
            await refreshSubscriptionStatus()
            await loadAvailableProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// サブスクリプション状態を更新
    func refreshSubscriptionStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 現在のサブスクリプション状態をチェック
            guard let result = try await Transaction.currentEntitlements.first(where: { transaction in
                switch transaction {
                case .verified(let transaction):
                    return subscriptionProductIDs.contains(transaction.productID) && !transaction.isUpgraded
                case .unverified:
                    return false
                }
            }) else {
                // サブスクリプションなし
                isSubscribed = false
                currentSubscription = nil
                print("📱 SubscriptionManager: サブスクリプションなし")
                return
            }
            
            switch result {
            case .verified(let transaction):
                // 有効なサブスクリプション
                await updateSubscriptionStatus(for: transaction)
                print("✅ SubscriptionManager: 有効なサブスクリプション確認 - \(transaction.productID)")
                
            case .unverified(_, let error):
                print("❌ SubscriptionManager: 未検証のサブスクリプション - \(error)")
                isSubscribed = false
                currentSubscription = nil
            }
        } catch {
            print("❌ SubscriptionManager: サブスクリプション状態の取得エラー - \(error)")
            isSubscribed = false
            currentSubscription = nil
        }
    }
    
    /// 利用可能な商品を読み込み（価格順でソート）
    func loadAvailableProducts() async {
        do {
            let products = try await Product.products(for: subscriptionProductIDs)
            // 週間→月間→年間の順序で表示するため、カスタムソート
            availableSubscriptions = products.sorted { product1, product2 in
                let order1 = getProductOrder(product1.id)
                let order2 = getProductOrder(product2.id)
                return order1 < order2
            }
            print("📦 SubscriptionManager: 利用可能な商品を読み込み - \(products.count)件")
            
            // デバッグ：商品情報を出力
            for product in availableSubscriptions {
                print("商品: \(product.displayName) - \(product.displayPrice) - ID: \(product.id)")
            }
        } catch {
            print("❌ SubscriptionManager: 商品読み込みエラー - \(error)")
        }
    }
    
    // 商品の表示順序を決定
    private func getProductOrder(_ productId: String) -> Int {
        switch productId {
        case "oshiKoiWeeklySub":
            return 0
        case "oshiKoiMonthlySub":
            return 1
        case "oshiKoiYearlySub":
            return 2
        default:
            return 999
        }
    }
    
    /// 購入処理
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await updateSubscriptionStatus(for: transaction)
                await transaction.finish()
                print("🎉 SubscriptionManager: 購入成功 - \(transaction.productID)")
                return true
                
            case .unverified(_, let error):
                print("❌ SubscriptionManager: 未検証の取引 - \(error)")
                throw SubscriptionError.verificationFailed
            }
            
        case .userCancelled:
            print("⚠️ SubscriptionManager: ユーザーがキャンセル")
            return false
            
        case .pending:
            print("⏳ SubscriptionManager: 購入保留中")
            return false
            
        @unknown default:
            print("❓ SubscriptionManager: 不明な結果")
            return false
        }
    }
    
    /// 復元処理
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            print("🔄 SubscriptionManager: 購入履歴を復元")
        } catch {
            print("❌ SubscriptionManager: 復元エラー - \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateSubscriptionStatus(for transaction: Transaction) async {
        // 商品情報を取得
        guard let product = availableSubscriptions.first(where: { $0.id == transaction.productID }) else {
            // 商品情報がない場合は再読み込み
            await loadAvailableProducts()
            guard let product = availableSubscriptions.first(where: { $0.id == transaction.productID }) else {
                isSubscribed = false
                currentSubscription = nil
                return
            }
            currentSubscription = product
            isSubscribed = true
            return
        }
        
        currentSubscription = product
        isSubscribed = true
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus(for: transaction)
                    await transaction.finish()
                    print("🔄 SubscriptionManager: 取引更新 - \(transaction.productID)")
                } catch {
                    print("❌ SubscriptionManager: 取引処理エラー - \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Supporting Types

enum SubscriptionError: LocalizedError {
    case verificationFailed
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "取引の検証に失敗しました"
        case .purchaseFailed:
            return "購入に失敗しました"
        }
    }
}

// MARK: - Convenience Extensions

extension SubscriptionManager {
    /// プレミアム機能が利用可能かどうか
    var isPremiumUser: Bool {
        return isSubscribed
    }
    
    /// 広告を表示すべきかどうか
    var shouldShowAds: Bool {
        return !isSubscribed
    }
    
    /// サブスクリプションの表示名
    var subscriptionDisplayName: String? {
        return currentSubscription?.displayName
    }
    
    /// 現在のプランタイプを取得
    var currentPlanType: PlanType? {
        guard let productId = currentSubscription?.id else { return nil }
        
        if productId.contains("weekly") {
            return .weekly
        } else if productId.contains("monthly") {
            return .monthly
        } else if productId.contains("yearly") {
            return .yearly
        }
        return nil
    }
}
