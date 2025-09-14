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
    
    private let primaryGradient = LinearGradient(
        colors: [Color.pink, Color.purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // ヘッダーセクション
                    headerSection
                    
                    // 特典セクション
                    benefitsSection
                    
                    // 料金プランセクション
                    if !subscriptionManager.availableSubscriptions.isEmpty {
                        subscriptionPlansSection
                    } else if subscriptionManager.isLoading {
                        loadingSection
                    } else {
                        noProductsSection
                    }
                    
                    // アクションボタン
                    actionButtonsSection
                    
                    // 利用規約・プライバシー
                    legalSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.pink.opacity(0.05),
                        Color.purple.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("プレミアムプラン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
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
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(primaryGradient.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(primaryGradient)
            }
            
            VStack(spacing: 12) {
                Text("プレミアムプラン")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(primaryGradient)
                
                Text("広告なしで推し活をもっと楽しく\n特別な機能で推しとの時間をより豊かに")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(spacing: 20) {
            Text("プラン加入特典")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                BenefitRow(
                    icon: "message.fill",
                    iconBackground: Color.purple.opacity(0.2),
                    iconColor: Color.purple,
                    title: "推しとのチャットが無制限に",
                    description: "どれだけ推しとチャットしても制限が無く\n広告も表示されません"
                )
                
                BenefitRow(
                    icon: "xmark.circle.fill",
                    iconBackground: Color.red.opacity(0.2),
                    iconColor: Color.red,
                    title: "広告が非表示に",
                    description: "アプリ内で表示されている全ての広告が\n非表示になります"
                )
                
                BenefitRow(
                    icon: "person.2.fill",
                    iconBackground: Color.blue.opacity(0.2),
                    iconColor: Color.blue,
                    title: "推しの登録が無制限に",
                    description: "何人推しを登録しても制限がかからなくなります"
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Loading Section
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("プランを読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
    }
    
    // MARK: - No Products Section
    private var noProductsSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("プランを読み込めませんでした")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("ネットワーク接続を確認してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("再読み込み") {
                Task {
                    await subscriptionManager.loadAvailableProducts()
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .frame(height: 200)
    }
    
    // MARK: - Subscription Plans Section
    private var subscriptionPlansSection: some View {
        VStack(spacing: 16) {
            Text("料金プラン")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(subscriptionManager.availableSubscriptions, id: \.id) { product in
                    SubscriptionPlanCard(
                        product: product,
                        isSelected: selectedProductId == product.id,
                        onSelect: {
                            selectedProductId = product.id
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // 購入ボタン
            Button(action: purchaseSelectedPlan) {
                HStack(spacing: 12) {
                    if isPurchasing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.title3)
                    }
                    
                    Text(isPurchasing ? "処理中..." : "プレミアムプランを開始")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedProductId != nil && !isPurchasing ?
                    primaryGradient :
                    LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(
                    color: selectedProductId != nil ? Color.pink.opacity(0.3) : .clear,
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .disabled(selectedProductId == nil || isPurchasing || subscriptionManager.availableSubscriptions.isEmpty)
            
            // 復元ボタン
            Button("購入履歴を復元") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .disabled(isPurchasing)
        }
    }
    
    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("購入することで利用規約とプライバシーポリシーに同意したものとみなされます")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("利用規約") {
                    // 利用規約を表示
                    // TODO: 実装
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("プライバシーポリシー") {
                    // プライバシーポリシーを表示
                    // TODO: 実装
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        Task {
            await subscriptionManager.loadAvailableProducts()
            
            // デフォルトで月間プランを選択（人気プランとして）
            if selectedProductId == nil {
                selectedProductId = subscriptionManager.availableSubscriptions.first(where: {
                    $0.id.contains("monthly")
                })?.id ?? subscriptionManager.availableSubscriptions.first?.id
            }
        }
    }
    
    private func purchaseSelectedPlan() {
        guard let productId = selectedProductId,
              let product = subscriptionManager.availableSubscriptions.first(where: { $0.id == productId }) else {
            return
        }
        
        isPurchasing = true
        
        Task {
            do {
                let success = try await subscriptionManager.purchase(product)
                
                await MainActor.run {
                    isPurchasing = false
                    
                    if success {
                        // 購入成功
                        showingSuccess = true
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
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let iconBackground: Color
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct SubscriptionPlanCard: View {
    let product: Product
    let isSelected: Bool
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
    
    private var savingsColor: Color {
        switch planType {
        case .weekly:
            return .blue
        case .monthly:
            return .blue
        case .yearly:
            return .orange
        }
    }
    
    private var planDescription: String {
        switch planType {
        case .weekly:
            return "お試しに最適"
        case .monthly:
            return "週間プランの50%オフ"
        case .yearly:
            return "月払いの2ヶ月分が無料"
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // メインコンテンツ
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        // プラン名とバッジ
                        HStack(spacing: 8) {
                            Text(planDisplayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let savings = savingsText {
                                Text(savings)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(savingsColor)
                                    )
                            }
                        }
                        
                        // 価格
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(planDisplayCost)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(planType.periodText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // 説明文
                        Text(planDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 選択状態のインジケーター
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected ? Color.clear : Color.gray.opacity(0.3),
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.pink, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ?
                                LinearGradient(
                                    colors: [Color.pink, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
    
    // 価格をフォーマット
    private var formattedPrice: String {
        let price = product.price
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "¥\(price)"
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
