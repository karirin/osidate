//
//  SubscriptionView.swift
//  osidate
//
//  サブスクリプション購入画面
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProductId: String?
    @State private var isPurchasing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var animateFeatures = false
    
    // 改良されたグラデーション（SubscriptionPreView風）
    private let primaryGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.3, blue: 0.6),
            Color(red: 0.6, green: 0.2, blue: 1.0),
            Color(red: 0.2, green: 0.4, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let backgroundGradient = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color(red: 0.98, green: 0.97, blue: 1.0),
            Color(red: 0.95, green: 0.95, blue: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    private let accentColor = Color(red: 0.6, green: 0.2, blue: 1.0)
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 40) {
                    // 改良されたヘッダーセクション
                    VStack(spacing: 24) {
                        // 3Dライクなクラウンアイコン
                        ZStack {
                            // 背景の輝き効果
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.yellow.opacity(0.8)
                                        ],
                                        center: .topLeading,
                                        startRadius: 20,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .shadow(color: Color.pink.opacity(0.4), radius: 25, x: 0, y: 15)
                            
                            // グラデーションオーバーレイ
                            Circle()
                                .fill(primaryGradient.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            // クラウンアイコン
                            Image(systemName: "crown.fill")
                                .font(.system(size: 55, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                        }
                        .scaleEffect(animateFeatures ? 1.0 : 0.8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateFeatures)
                        
                        VStack(spacing: 16) {
                            Text("プレミアムプラン")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryGradient)
                                .opacity(animateFeatures ? 1 : 0)
                                .offset(y: animateFeatures ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.2), value: animateFeatures)
                            
                            Text("広告なしで推し活をもっと楽しく\n特別な機能で推しとの時間をより豊かに")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .opacity(animateFeatures ? 1 : 0)
                                .offset(y: animateFeatures ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.4), value: animateFeatures)
                        }
                    }
                    
                    // アニメーション付き特典セクション
                    benefitsSection
//                    
//                    // 料金プランセクション
                    subscriptionPlansSection
//                    
//                    // アクションボタン
                    actionButtonsSection
//                    
//                    // 利用規約・プライバシー
                    legalSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .background(backgroundGradient.ignoresSafeArea())
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
            Text("プレミアムプランの購入が完了しました！")
        }
        .onAppear {
            setupInitialState()
            animateOnAppear()
        }
    }
    
    // MARK: - Benefits Section（モダンなカードデザイン）
    private var benefitsSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("プラン加入特典")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .opacity(animateFeatures ? 1 : 0)
                    .offset(x: animateFeatures ? 0 : -30)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: animateFeatures)
                Spacer()
            }
            
            VStack(spacing: 16) {
                ModernBenefitCard(
                    icon: "star.bubble.fill",
                    title: "推しとのチャットが無制限に",
                    description: "どれだけ推しとチャットしても制限が無く\n広告も表示されません",
                    gradient: LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    delay: 0.8,
                    isVisible: $animateFeatures
                )
                
                ModernBenefitCard(
                    icon: "rectangle.fill.badge.xmark",
                    title: "広告が非表示に",
                    description: "アプリ内で表示されている全ての広告が非表示になります",
                    gradient: LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                    delay: 1.0,
                    isVisible: $animateFeatures
                )
                
                ModernBenefitCard(
                    icon: "person.2.badge.plus.fill",
                    title: "推しの登録が無制限に",
                    description: "何人推しを登録しても制限がかからなくなります",
                    gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    delay: 1.2,
                    isVisible: $animateFeatures
                )
            }
        }
    }
    
    // MARK: - Loading Section（モダンなローディングアニメーション）
    private var loadingSection: some View {
        ModernLoadingView()
    }
    
    // MARK: - No Products Section
    private var noProductsSection: some View {
        ModernEmptyStateView(
            primaryGradient: primaryGradient,
            onReload: {
                Task {
                    await subscriptionManager.loadAvailableProducts()
                }
            }
        )
    }
    
    // MARK: - Subscription Plans Section（カードデザイン改良）
    private var subscriptionPlansSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("料金プラン")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
            }
            
            if subscriptionManager.isLoading {
                loadingSection
            } else if subscriptionManager.availableSubscriptions.isEmpty {
                noProductsSection
            } else {
                VStack(spacing: 16) {
                    ForEach(subscriptionManager.availableSubscriptions, id: \.id) { product in
                        ModernSubscriptionPlanCard(
                            product: product,
                            isSelected: selectedProductId == product.id,
                            primaryGradient: primaryGradient,
                            onSelect: {
                                selectedProductId = product.id
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section（3Dボタンデザイン）
    private var actionButtonsSection: some View {
        VStack(spacing: 20) {
            // 購入ボタン
            Button(action: purchaseSelectedPlan) {
                HStack(spacing: 12) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("プレミアムプランを開始")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                selectedProductId != nil && !isPurchasing ?
                                primaryGradient :
                                LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                            )
                        
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .shadow(
                    color: selectedProductId != nil ? Color.pink.opacity(0.4) : .clear,
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
            }
            .disabled(selectedProductId == nil || isPurchasing || subscriptionManager.availableSubscriptions.isEmpty)
            .scaleEffect(isPurchasing ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPurchasing)
            
            // 復元ボタン
            Button("購入履歴を復元") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(accentColor)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.systemBackground))
                    .shadow(color: accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .disabled(isPurchasing)
        }
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(spacing: 24) {
            HStack(spacing: 40) {
                Button("利用規約") {
                    // 利用規約を表示
                    // TODO: 実装
                }
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .medium))
                
                Button("プライバシーポリシー") {
                    // プライバシーポリシーを表示
                    // TODO: 実装
                }
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .medium))
            }
            
            Text("購読は自動更新されます。解約はApp Storeの設定から行えます。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Dismiss Button
    private var dismissButton: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        Task {
            await subscriptionManager.loadAvailableProducts()
            
            // デフォルトで月間プランを選択（人気プランとして）
            if selectedProductId == nil {
                selectedProductId = subscriptionManager.availableSubscriptions.first(where: {
                    $0.id.contains("Monthly")
                })?.id ?? subscriptionManager.availableSubscriptions.first?.id
            }
        }
    }
    
    private func animateOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                animateFeatures = true
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
        
        Task {
            do {
                let success = try await subscriptionManager.purchase(product)
                
                await MainActor.run {
                    isPurchasing = false
                    
                    if success {
                        showingSuccess = true
                        generateHapticFeedback()
                    }
                }
            } catch {
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

// MARK: - Supporting Views

// モダンな特典カード
struct ModernBenefitCard: View {
    let icon: String
    let title: String
    let description: String
    let gradient: LinearGradient
    let delay: Double
    @Binding var isVisible: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 20) {
            // アイコン部分
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(gradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: .clear, radius: 12, x: 0, y: 6)
                
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            
            // テキスト部分
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(
                    color: .black.opacity(isHovered ? 0.15 : 0.08),
                    radius: isHovered ? 16 : 8,
                    x: 0,
                    y: isHovered ? 8 : 4
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white, .gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : 50)
        .animation(.easeOut(duration: 0.8).delay(delay), value: isVisible)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered.toggle()
                }
            }
        }
    }
}

// モダンなプランカード
struct ModernSubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
    let primaryGradient: LinearGradient
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
    
    private var savingsText: String? {
        switch planType {
        case .weekly:
            return nil
        case .monthly:
            return "人気"
        case .yearly:
            return "最もお得"
        }
    }
    
    private var savingsColor: LinearGradient {
        switch planType {
        case .weekly:
            return LinearGradient(colors: [.blue], startPoint: .leading, endPoint: .trailing)
        case .monthly:
            return LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
        case .yearly:
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var planDescription: String {
        switch planType {
        case .weekly:
            return "お試しに最適"
        case .monthly:
            return "週間プランの50％オフ"
        case .yearly:
            return "月払いの2ヶ月分が無料"
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // メインカード
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            // プラン名とバッジ
                            HStack {
                                Text(planDisplayName)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                if let savings = savingsText {
                                    HStack(spacing: 6) {
                                        Image(systemName: planType == .yearly ? "star.fill" : "heart.fill")
                                            .font(.system(size: 12, weight: .bold))
                                        Text(savings)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(savingsColor)
                                            .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                                    )
                                }
                            }
                            
                            // 価格
                            HStack(alignment: .bottom, spacing: 4) {
                                Text(planDisplayCost)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(primaryGradient)
                                
                                Text(planType.periodText)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            // 説明文
                            Text(planDescription)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 選択状態のインジケーター
                        ZStack {
                            Circle()
                                .fill(
                                    isSelected ?
                                    primaryGradient :
                                    LinearGradient(colors: [.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 32, height: 32)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .shadow(color: isSelected ? .pink.opacity(0.3) : .clear, radius: 8)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected ? primaryGradient :
                                    LinearGradient(colors: [.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .shadow(
                            color: .black.opacity(0.05),
                            radius: isSelected ? 20 : 8,
                            x: 0,
                            y: isSelected ? 10 : 4
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
    
    // プラン表示名を適切に設定
    private var planDisplayName: String {
        switch planType {
        case .weekly:
            return "週間プラン"
        case .monthly:
            return "月額プラン"
        case .yearly:
            return "年額プラン"
        }
    }
    
    private var planDisplayCost: String {
        switch planType {
        case .weekly:
            return "480円"
        case .monthly:
            return "980円"
        case .yearly:
            return "9,800円"
        }
    }
}

// モダンなローディングビュー
struct ModernLoadingView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
            }
            
            Text("プランを読み込み中...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
        .onAppear {
            rotationAngle = 360
        }
    }
}

// モダンな空状態ビュー
struct ModernEmptyStateView: View {
    let primaryGradient: LinearGradient
    let onReload: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "cart.badge.questionmark")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 16) {
                Text("利用可能なプランがありません")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("ネットワーク接続を確認してください")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            Button("再読み込み") {
                onReload()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(primaryGradient)
            .cornerRadius(20)
            .shadow(color: .pink.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(24)
    }
}

// MARK: - Supporting Types

enum PlanType {
    case weekly
    case monthly
    case yearly
    
    var periodText: String {
        switch self {
        case .weekly:
            return "/週"
        case .monthly:
            return "/月"
        case .yearly:
            return "/年"
        }
    }
}

#Preview {
    SubscriptionView()
}
