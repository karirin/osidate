//
//  SubscriptionView.swift
//  osidate
//
//  サブスクリプション購入画面 - リニューアルデザイン
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    /// どこから開かれたか（source ごとの成約率計測用）
    var source: PaywallSource = .unknown
    
    @State private var selectedProductId: String?
    /// 無料トライアルの対象になっている商品ID → トライアル期間
    @State private var eligibleTrialPeriods: [String: Product.SubscriptionPeriod] = [:]
    @State private var didPurchase = false
    @State private var isPurchasing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var animateContent = false
    
    // ロマンチックなカラーパレット（画像に合わせた夜のビーチテーマ）
    private let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.85, green: 0.55, blue: 0.70),
            Color(red: 0.55, green: 0.45, blue: 0.75),
            Color(red: 0.25, green: 0.35, blue: 0.65)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let accentGold = Color(red: 0.95, green: 0.85, blue: 0.55)
    private let deepBlue = Color(red: 0.12, green: 0.18, blue: 0.35)
    private let softPink = Color(red: 0.95, green: 0.88, blue: 0.90)
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.12, blue: 0.25),
                        Color(red: 0.15, green: 0.18, blue: 0.35),
                        Color(red: 0.12, green: 0.15, blue: 0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ヘッダーバナー画像
                        headerBannerSection
                        
                        // メインコンテンツ
                        VStack(spacing: 20) {
                            // プレミアム特典セクション（横並びコンパクト）
                            benefitsSection
                                .padding(.top, -30)
                            
                            // 料金プランセクション
                            subscriptionPlansSection
                            
                            // 購入ボタン
                            actionButtonsSection
                            
                            // 利用規約・プライバシー
                            legalSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    dismissButton
                }
            }
        }
        .alert("エラー", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("購入完了", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("プレミアムプランの購入が完了しました！\n推しとの特別な時間をお楽しみください💕")
        }
        .onAppear {
            AnalyticsManager.logPaywallView(source: source.rawValue)
            setupInitialState()
            animateOnAppear()
        }
        .onDisappear {
            AnalyticsManager.logPaywallClose(source: source.rawValue, purchased: didPurchase)
        }
    }
    
    // MARK: - Header Banner Section
    private var headerBannerSection: some View {
        ZStack(alignment: .bottom) {
            // バナー画像
            Image("premium_header_banner")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: UIScreen.main.bounds.width)
                .frame(height: 240)
                .clipped()
                .overlay(
                    // 下部グラデーションオーバーレイ
                    LinearGradient(
                        colors: [
                            .clear,
                            .clear,
                            Color(red: 0.08, green: 0.12, blue: 0.25).opacity(0.7),
                            Color(red: 0.08, green: 0.12, blue: 0.25)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // ヘッダーテキストオーバーレイ
            VStack(spacing: 10) {
                // キラキラエフェクト
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("PREMIUM")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(3)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                }
                .foregroundColor(accentGold)
                .opacity(animateContent ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: animateContent)
                
                Text("推しとの特別な時間")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: animateContent)
                
                Text("広告なし・無制限で推し活をもっと楽しく")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: animateContent)
            }
            .padding(.bottom, 50)
        }
        .frame(height: 240)
    }
    
    // MARK: - Benefits Section（横並びコンパクト）
    private var benefitsSection: some View {
        HStack(spacing: 8) {
            CompactBenefitItem(
                icon: "bubble.left.and.bubble.right.fill",
                title: "チャット無制限",
                description: "推しと話し放題",
                color: Color.pink
            )
            
            CompactBenefitItem(
                icon: "rectangle.badge.xmark",
                title: "広告非表示",
                description: "全広告を削除",
                color: Color.orange
            )
            
            CompactBenefitItem(
                icon: "person.3.fill",
                title: "推し登録無制限",
                description: "何人でも追加OK",
                color: Color.cyan
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.15, green: 0.18, blue: 0.35).opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
        )
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: animateContent)
    }
    
    // MARK: - Subscription Plans Section
    private var subscriptionPlansSection: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isLoading {
                loadingSection
            } else if subscriptionManager.availableSubscriptions.isEmpty {
                noProductsSection
            } else {
                ForEach(subscriptionManager.availableSubscriptions.sorted(by: { plan1, plan2 in
                    let order: [String: Int] = ["Monthly": 0, "Yearly": 1, "Weekly": 2]
                    let p1Order = order.first { plan1.id.contains($0.key) }?.value ?? 3
                    let p2Order = order.first { plan2.id.contains($0.key) }?.value ?? 3
                    return p1Order < p2Order
                }), id: \.id) { product in
                    CompactPlanCard(
                        product: product,
                        isSelected: selectedProductId == product.id,
                        accentGold: accentGold,
                        trialPeriodText: eligibleTrialPeriods[product.id]?.japaneseText,
                        onSelect: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedProductId = product.id
                            }
                            AnalyticsManager.logPaywallPlanSelect(source: source.rawValue, productId: product.id)
                            generateHapticFeedback()
                        }
                    )
                }
            }
        }
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(0.3), value: animateContent)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // メイン購入ボタン
            Button(action: purchaseSelectedPlan) {
                HStack(spacing: 10) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: deepBlue))
                            .scaleEffect(1.0)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(selectedTrialPeriodText.map { "\($0)無料で試す" } ?? "プレミアムを始める")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(deepBlue)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 27)
                            .fill(
                                selectedProductId != nil && !isPurchasing ?
                                LinearGradient(
                                    colors: [accentGold, Color(red: 1.0, green: 0.9, blue: 0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                            )
                        
                        if selectedProductId != nil && !isPurchasing {
                            RoundedRectangle(cornerRadius: 27)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                    }
                )
                .shadow(
                    color: selectedProductId != nil ? accentGold.opacity(0.5) : .clear,
                    radius: 14,
                    x: 0,
                    y: 7
                )
            }
            .disabled(selectedProductId == nil || isPurchasing || subscriptionManager.availableSubscriptions.isEmpty)
            .scaleEffect(isPurchasing ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPurchasing)
            
            // トライアル後の料金を明示（App Store審査ガイドライン 3.1.2 対応）
            if let trialText = selectedTrialPeriodText, let product = selectedProduct {
                Text("\(trialText)無料、その後 \(product.displayPrice)\(planPeriodText(for: product))で自動更新。\n無料期間中に解約すれば料金はかかりません。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            // 復元ボタン
            Button("購入履歴を復元") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .padding(.vertical, 10)
            .disabled(isPurchasing)
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.4), value: animateContent)
    }
    
    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: accentGold))
                .scaleEffect(1.2)
            
            Text("プランを読み込み中...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(height: 140)
    }
    
    // MARK: - No Products Section
    private var noProductsSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.5))
            
            Text("プランを取得できませんでした")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Button("再読み込み") {
                Task {
                    await subscriptionManager.loadAvailableProducts()
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(deepBlue)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(accentGold)
            .cornerRadius(18)
        }
        .frame(height: 160)
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 28) {
                Button("利用規約") {
                    // TODO: 利用規約を表示
                }
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 12, weight: .medium))
                
                Button("プライバシーポリシー") {
                    // TODO: プライバシーポリシーを表示
                }
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 12, weight: .medium))
            }
            
            Text("購読は自動更新されます。解約はApp Storeの設定から行えます。")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.top, 4)
    }
    
    // MARK: - Dismiss Button
    private var dismissButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(9)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Private Methods
    
    private var selectedProduct: Product? {
        subscriptionManager.availableSubscriptions.first(where: { $0.id == selectedProductId })
    }
    
    private var selectedTrialPeriodText: String? {
        guard let productId = selectedProductId else { return nil }
        return eligibleTrialPeriods[productId]?.japaneseText
    }
    
    private func planPeriodText(for product: Product) -> String {
        if product.id.contains("Weekly") { return PlanType.weekly.periodText }
        if product.id.contains("Yearly") { return PlanType.yearly.periodText }
        return PlanType.monthly.periodText
    }
    
    /// App Store Connect で無料トライアルが設定され、かつユーザーが対象の商品を調べる
    private func loadTrialEligibility() async {
        var periods: [String: Product.SubscriptionPeriod] = [:]
        for product in subscriptionManager.availableSubscriptions {
            guard let subscription = product.subscription,
                  let offer = subscription.introductoryOffer,
                  offer.paymentMode == .freeTrial,
                  await subscription.isEligibleForIntroOffer else { continue }
            periods[product.id] = offer.period
        }
        eligibleTrialPeriods = periods
    }
    
    private func setupInitialState() {
        Task {
            await subscriptionManager.loadAvailableProducts()
            await loadTrialEligibility()
            
            if selectedProductId == nil {
                selectedProductId = subscriptionManager.availableSubscriptions.first(where: {
                    $0.id.contains("Monthly")
                })?.id ?? subscriptionManager.availableSubscriptions.first?.id
            }
        }
    }
    
    private func animateOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                animateContent = true
            }
        }
    }
    
    private func purchaseSelectedPlan() {
        guard let productId = selectedProductId,
              let product = subscriptionManager.availableSubscriptions.first(where: { $0.id == productId }) else {
            return
        }
        
        isPurchasing = true
        generateHapticFeedback()
        AnalyticsManager.logPurchaseStart(
            source: source.rawValue,
            productId: product.id,
            hasTrial: eligibleTrialPeriods[product.id] != nil
        )
        
        Task {
            do {
                let outcome = try await subscriptionManager.purchase(product)
                AnalyticsManager.logPurchaseResult(source: source.rawValue, productId: product.id, result: outcome.rawValue)
                
                await MainActor.run {
                    isPurchasing = false
                    
                    if outcome == .success {
                        didPurchase = true
                        showingSuccess = true
                        generateHapticFeedback()
                    }
                }
            } catch {
                AnalyticsManager.logPurchaseResult(source: source.rawValue, productId: product.id, result: "failed")
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = "購入に失敗しました: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Compact Benefit Item（横並び特典アイテム）
struct CompactBenefitItem: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Plan Card
struct CompactPlanCard: View {
    let product: Product
    let isSelected: Bool
    let accentGold: Color
    var trialPeriodText: String? = nil
    let onSelect: () -> Void
    
    private var planType: PlanType {
        if product.id.contains("Weekly") {
            return .weekly
        } else if product.id.contains("Monthly") {
            return .monthly
        } else if product.id.contains("Yearly") {
            return .yearly
        }
        return .monthly
    }
    
    private var badgeInfo: (text: String, color: LinearGradient)? {
        if let trialPeriodText {
            return ("\(trialPeriodText)無料", LinearGradient(colors: [Color.green, Color.teal], startPoint: .leading, endPoint: .trailing))
        }
        switch planType {
        case .weekly:
            return nil
        case .monthly:
            return ("おすすめ", LinearGradient(colors: [Color.pink, Color.purple], startPoint: .leading, endPoint: .trailing))
        case .yearly:
            return ("2ヶ月分お得", LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing))
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // 選択インジケーター
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? accentGold : Color.white.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(accentGold)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // プラン情報
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(planDisplayName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if let badge = badgeInfo {
                            Text(badge.text)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(badge.color)
                                )
                        }
                    }
                    
                    Text(trialPeriodText.map { "\($0)無料トライアル付き" } ?? planDescription)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
                
                Spacer()
                
                // 価格
                VStack(alignment: .trailing, spacing: 1) {
                    Text(planDisplayCost)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? accentGold : .white)
                    
                    Text(planType.periodText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected ?
                        Color.white.opacity(0.15) :
                        Color.white.opacity(0.06)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ?
                                accentGold.opacity(0.6) :
                                Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var planDisplayName: String {
        switch planType {
        case .weekly: return "週間プラン"
        case .monthly: return "月額プラン"
        case .yearly: return "年額プラン"
        }
    }
    
    private var planDisplayCost: String {
        switch planType {
        case .weekly: return "¥480"
        case .monthly: return "¥980"
        case .yearly: return "¥9,800"
        }
    }
    
    private var planDescription: String {
        switch planType {
        case .weekly: return "お試しに最適"
        case .monthly: return "週間の50%オフ"
        case .yearly: return "月額の2ヶ月分無料"
        }
    }
}

// MARK: - Supporting Types

/// ペイウォールを開いた導線
enum PaywallSource: String {
    case launch
    case onboarding
    case interstitial
    case dateAd = "date_ad"
    case characterLimit = "character_limit"
    case settings
    case unknown
}

struct PaywallRequest: Identifiable {
    let id = UUID()
    let source: PaywallSource
}

extension Product.SubscriptionPeriod {
    /// 「3日間」「1週間」などの表示用テキスト
    var japaneseText: String {
        switch unit {
        case .day: return "\(value)日間"
        // App Store Connect では7日間が「1週間」として返るため、日数で表示する
        case .week: return "\(value * 7)日間"
        case .month: return "\(value)ヶ月"
        case .year: return "\(value)年"
        @unknown default: return "\(value)日間"
        }
    }
}

enum PlanType {
    case weekly
    case monthly
    case yearly
    
    var periodText: String {
        switch self {
        case .weekly: return "/週"
        case .monthly: return "/月"
        case .yearly: return "/年"
        }
    }
}

#Preview {
    SubscriptionView()
}
