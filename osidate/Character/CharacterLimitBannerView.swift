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
            if !limitInfo.isSubscribed {
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
                        
                        // アップグレードボタン
                        Button(action: onUpgradePressed) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.caption)
                                Text("アップグレード")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(gradient)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(.secondarySystemBackground),
                                gradientColors.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    
                    // 警告バー（制限近づき時）
                    if let warningText = limitInfo.warningText {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text(warningText)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.1))
                    }
                }
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(gradient.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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

#Preview("通常状態") {
    VStack(spacing: 16) {
        CharacterLimitBannerView(
            limitInfo: CharacterLimitInfo(
                currentCount: 2,
                maxCount: 3,
                canCreateMore: true,
                isSubscribed: false
            ),
            onUpgradePressed: { }
        )
        
        CharacterLimitBannerView(
            limitInfo: CharacterLimitInfo(
                currentCount: 3,
                maxCount: 3,
                canCreateMore: false,
                isSubscribed: false
            ),
            onUpgradePressed: { }
        )
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("プレミアム") {
    CharacterLimitBannerView(
        limitInfo: CharacterLimitInfo(
            currentCount: 5,
            maxCount: nil,
            canCreateMore: true,
            isSubscribed: true
        ),
        onUpgradePressed: { }
    )
    .padding()
    .background(Color(.systemBackground))
}
