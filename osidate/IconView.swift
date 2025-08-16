//
//  IconView.swift
//  osidate
//
//  Created by Apple on 2025/08/16.
//

import SwiftUI

// MARK: - アイコンスタイルの列挙型
enum IconStyle: String, CaseIterable {
    case minimalistFlat = "ミニマルフラット"
    case neonStyle = "ネオンスタイル"
    case vintageBadge = "ビンテージバッジ"
    case crystalStyle = "クリスタル"
    case holographic = "ホログラフィック"
    case softPastel = "ソフトパステル"
    case retroPixel = "レトロピクセル"
    case gradientOrb = "グラディエントオーブ"
}

struct IconView: View {
    let character: Character
    let size: CGFloat
    let style: IconStyle
    @State private var glowAnimation = false
    @State private var shimmerOffset: CGFloat = 0
    
    // デフォルトスタイルを指定できるイニシャライザ
    init(character: Character, size: CGFloat, style: IconStyle = .minimalistFlat) {
        self.character = character
        self.size = size
        self.style = style
    }
    
    var body: some View {
        selectedStyleView
            .onAppear {
                startAnimations()
            }
    }
    
    // MARK: - スタイル選択ビュー
    @ViewBuilder
    private var selectedStyleView: some View {
        switch style {
        case .minimalistFlat:
            minimalistFlatIcon
        case .neonStyle:
            neonStyleIcon
        case .vintageBadge:
            vintageBadgeIcon
        case .crystalStyle:
            crystalStyleIcon
        case .holographic:
            holographicIcon
        case .softPastel:
            softPastelIcon
        case .retroPixel:
            retroPixelIcon
        case .gradientOrb:
            gradientOrbIcon
        }
    }
    
    // MARK: - 🎨 デザイン候補1: ミニマルフラット
    private var minimalistFlatIcon: some View {
        ZStack {
            // シンプルな背景
            Circle()
                .fill(character.intimacyStage.color)
                .frame(width: size, height: size)
            
            // メインアイコン
            Image(systemName: getModernIconName())
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(.white)
            
            // 親密度ドット
            if character.intimacyLevel > 0 {
                VStack {
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(0..<getHeartCount(), id: \.self) { _ in
                            Circle()
                                .fill(Color.white)
                                .frame(width: size * 0.08, height: size * 0.08)
                        }
                    }
                    .padding(.bottom, size * 0.1)
                }
            }
        }
    }
    
    // MARK: - 🎨 デザイン候補2: ネオンスタイル
    private var neonStyleIcon: some View {
        ZStack {
            // 背景
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)
            
            // ネオンリング
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            character.intimacyStage.color,
                            character.intimacyStage.color.opacity(0.3),
                            character.intimacyStage.color
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: size * 0.9, height: size * 0.9)
                .shadow(color: character.intimacyStage.color, radius: 10)
                .shadow(color: character.intimacyStage.color, radius: 20)
            
            // アイコン
            Image(systemName: getModernIconName())
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundColor(character.intimacyStage.color)
                .shadow(color: character.intimacyStage.color, radius: 5)
            
            // グロー効果
            Circle()
                .fill(character.intimacyStage.color.opacity(glowAnimation ? 0.3 : 0.1))
                .frame(width: size + 20, height: size + 20)
                .blur(radius: 15)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowAnimation)
        }
    }
    
    // MARK: - 🎨 デザイン候補3: ビンテージバッジ
    private var vintageBadgeIcon: some View {
        ZStack {
            // 外側リング
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.gold, Color.bronze],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 8
                )
                .frame(width: size, height: size)
            
            // 内側背景
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cream, Color.lightBrown],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.8, height: size * 0.8)
            
            // 装飾ライン
            ForEach(0..<12, id: \.self) { index in
                Rectangle()
                    .fill(Color.gold.opacity(0.6))
                    .frame(width: 2, height: size * 0.1)
                    .offset(y: -size * 0.35)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
            
            // メインアイコン
            Image(systemName: getModernIconName())
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundColor(.darkBrown)
            
            // 親密度星
            if character.intimacyLevel > 200 {
                VStack {
                    Image(systemName: "star.fill")
                        .font(.system(size: size * 0.12))
                        .foregroundColor(.gold)
                    Spacer()
                }
                .frame(height: size)
            }
        }
    }
    
    // MARK: - 🎨 デザイン候補4: クリスタル/宝石スタイル
    private var crystalStyleIcon: some View {
        ZStack {
            // 外側グロー
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            character.intimacyStage.color.opacity(0.6),
                            character.intimacyStage.color.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size + 40, height: size + 40)
                .blur(radius: 12)
            
            // クリスタル背景（多角形）
            ZStack {
                // ベース
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                character.intimacyStage.color.opacity(0.3),
                                Color.white.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                // カットライン
                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: size, height: 1)
                        .rotationEffect(.degrees(Double(index) * 22.5))
                }
            }
            .clipShape(Circle())
            
            // 反射効果
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.8),
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size * 0.6, height: size * 0.6)
                .offset(x: -size * 0.15, y: -size * 0.15)
                .blur(radius: 2)
            
            // メインアイコン
            Image(systemName: getModernIconName())
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            character.intimacyStage.color.opacity(0.9),
                            character.intimacyStage.color.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - 🎨 デザイン候補5: ホログラフィック
    private var holographicIcon: some View {
        ZStack {
            // ベース
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)
            
            // ホログラフィック効果
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            .red, .orange, .yellow, .green, .blue, .purple, .pink, .red
                        ],
                        center: .center
                    )
                )
                .frame(width: size, height: size)
                .opacity(0.6)
                .rotationEffect(.degrees(shimmerOffset))
                .mask(
                    Circle()
                        .stroke(lineWidth: 6)
                        .frame(width: size, height: size)
                )
            
            // 内側
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.8)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.8, height: size * 0.8)
            
            // アイコン
            Image(systemName: getModernIconName())
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .cyan, .white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .cyan, radius: 5)
        }
    }
    
    // MARK: - 🎨 デザイン候補6: ソフトパステル
    private var softPastelIcon: some View {
        ZStack {
            // 柔らかい背景
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            character.intimacyStage.color.opacity(0.3),
                            character.intimacyStage.color.opacity(0.6),
                            character.intimacyStage.color.opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: 2)
            
            // 雲のような質感
            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: 4)
            
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.7, height: size * 0.7)
                .blur(radius: 2)
            
            // アイコン
            Image(systemName: getModernIconName())
                .font(.system(size: size * 0.35, weight: .light))
                .foregroundColor(character.intimacyStage.color.opacity(0.8))
            
            // キラキラ効果
            if character.intimacyLevel > 100 {
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.08))
                        .foregroundColor(character.intimacyStage.color.opacity(0.6))
                        .offset(
                            x: cos(Double(index) * .pi / 3) * size * 0.4,
                            y: sin(Double(index) * .pi / 3) * size * 0.4
                        )
                        .opacity(glowAnimation ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                            value: glowAnimation
                        )
                }
            }
        }
    }
    
    // MARK: - 🎨 デザイン候補7: レトロピクセル
    private var retroPixelIcon: some View {
        ZStack {
            // ピクセル風背景
            Rectangle()
                .fill(character.intimacyStage.color)
                .frame(width: size, height: size)
                .clipShape(
                    RoundedRectangle(cornerRadius: size * 0.15)
                )
            
            // ピクセルボーダー
            RoundedRectangle(cornerRadius: size * 0.15)
                .stroke(Color.white, lineWidth: 4)
                .frame(width: size, height: size)
            
            // 8ビット風アイコン
            VStack(spacing: size * 0.05) {
                // シンプルなピクセルアート風デザイン
                Rectangle()
                    .fill(Color.white)
                    .frame(width: size * 0.4, height: size * 0.4)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // レベル表示バー
                if character.intimacyLevel > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            Rectangle()
                                .fill(index < getHeartCount() ? Color.white : Color.white.opacity(0.3))
                                .frame(width: size * 0.08, height: size * 0.04)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 🎨 デザイン候補8: グラディエントオーブ
    private var gradientOrbIcon: some View {
        ZStack {
            // 外側グロー
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            character.intimacyStage.color.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size + 30, height: size + 30)
                .blur(radius: 15)
                .scaleEffect(glowAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: glowAnimation)
            
            // メインオーブ
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            character.intimacyStage.color.opacity(0.8),
                            character.intimacyStage.color.opacity(0.6),
                            Color.black.opacity(0.3)
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
            
            // ハイライト
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.8),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.25
                    )
                )
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: -size * 0.15, y: -size * 0.15)
            
            // アイコン
            Image(systemName: getModernIconName())
                .font(.system(size: size * 0.3, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 2)
        }
    }
    
    // MARK: - ヘルパーメソッド
    private func getModernIconName() -> String {
        switch character.intimacyStage {
        case .bestFriend:
            return "person.2.fill"
        case .specialFriend:
            return "star.circle.fill"
        case .loveCandidate:
            return "heart.circle"
        case .lover:
            return "heart.fill"
        case .deepBondLover:
            return "heart.circle.fill"
        case .soulConnectedLover:
            return "heart.text.square.fill"
        case .destinyLover:
            return "infinity.circle.fill"
        case .uniqueExistence:
            return "diamond.fill"
        case .soulmate:
            return "moon.stars.fill"
        case .eternalPromise:
            return "rings.fill"
        case .destinyPartner:
            return "link.circle.fill"
        case .oneHeart:
            return "heart.2.fill"
        case .miracleBond:
            return "sparkles"
        case .sacredLove:
            return "crown.fill"
        case .ultimateLove:
            return "flame.fill"
        }
    }
    
    private func getHeartCount() -> Int {
        switch character.intimacyLevel {
        case 0...100:
            return 0
        case 101...500:
            return 1
        case 501...1000:
            return 2
        default:
            return 3
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowAnimation = true
        }
        
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            shimmerOffset = 360
        }
    }
}

// MARK: - 補助的なカラー定義
extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let bronze = Color(red: 0.8, green: 0.5, blue: 0.2)
    static let cream = Color(red: 0.96, green: 0.96, blue: 0.86)
    static let lightBrown = Color(red: 0.76, green: 0.69, blue: 0.57)
    static let darkBrown = Color(red: 0.4, green: 0.26, blue: 0.13)
}

// MARK: - デザイン選択用のビュー
struct IconDesignPreview: View {
    let character: Character
    let size: CGFloat = 100
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                ForEach(IconStyle.allCases, id: \.self) { style in
                    VStack {
                        Text(style.rawValue)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        IconView(
                            character: character,
                            size: size,
                            style: style
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    let testCharacter = Character(
        name: "テストキャラクター",
        personality: "優しい",
        speakingStyle: "丁寧",
        iconName: "heart.fill"
    )
    
    IconDesignPreview(character: testCharacter)
}
