//
//  CharacterLimitBannerView.swift
//  osidate
//
//  キャラクター制限を表示するバナーコンポーネント
//

import SwiftUI

struct CharacterLimitBannerView: View {
    let limitInfo: CharacterLimitInfo
    let onUpgradePressed: () -> Void
    
    @State private var shimmerOffset: CGFloat = -100
    
    var body: some View {
        Group {
            // 🌟 特別ユーザーまたはサブスクリプション加入者以外に表示
            if !limitInfo.isSubscribed && !limitInfo.isSpecialUser {
                VStack(spacing: 0) {
                    // メインバナー
                    HStack(spacing: 16) {
                        // アイコン
                        ZStack {
                            Circle()
                                .fill(gradientColors.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(gradient)
                        }
                        
                        // テキスト情報
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(limitInfo.displayText)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                if limitInfo.currentCount >= (limitInfo.maxCount ?? 0) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Text("プレミアムプランで無制限に楽しめます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 無制限アイコン
                        HStack(spacing: 4) {
                            Image(systemName: "infinity")
                                .font(.caption)
                                .foregroundColor(.gold)
                            Text("無制限")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gold.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(.secondarySystemBackground),
                                Color.gold.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.gold.opacity(0.1), radius: 8, x: 0, y: 2)
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        shimmerOffset = 100
                    }
                }
            }
        }
    }
    
    private var gradientColors: Color {
        if limitInfo.currentCount >= (limitInfo.maxCount ?? 0) {
            return .orange
        } else {
            return .blue
        }
    }
    
    private var gradient: LinearGradient {
        if limitInfo.currentCount >= (limitInfo.maxCount ?? 0) {
            return LinearGradient(
                colors: [.orange, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - プレビュー

#Preview("特別ユーザー") {
    CharacterLimitBannerView(
        limitInfo: CharacterLimitInfo(
            currentCount: 10,
            maxCount: nil,
            canCreateMore: true,
            isSubscribed: false,
            isSpecialUser: true
        ),
        onUpgradePressed: { }
    )
    .padding()
    .background(Color(.systemBackground))
}

#Preview("プレミアム") {
    CharacterLimitBannerView(
        limitInfo: CharacterLimitInfo(
            currentCount: 5,
            maxCount: nil,
            canCreateMore: true,
            isSubscribed: true,
            isSpecialUser: false
        ),
        onUpgradePressed: { }
    )
    .padding()
    .background(Color(.systemBackground))
}

