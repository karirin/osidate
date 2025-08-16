//
//  CharacterIconView.swift - モダンデザイン更新版
//  osidate
//

import SwiftUI

struct CharacterIconView: View {
    let character: Character
    let size: CGFloat
    let enableFloating: Bool

    @State private var isFloating = false
    @State private var iconImage: UIImage? = nil
    @State private var isLoading = false
    @State private var animationTimer: Timer? = nil
    @State private var glowAnimation = false
    @State private var shimmerOffset: CGFloat = -100
    
    // デフォルトでアニメーションを有効にするイニシャライザ
    init(character: Character, size: CGFloat, enableFloating: Bool = true) {
        self.character = character
        self.size = size
        self.enableFloating = enableFloating
    }
    
    var body: some View {
        content
            .frame(width: size, height: size)
            .clipped()
            .clipShape(Circle())
            .offset(y: enableFloating ? (isFloating ? -8 : 8) : 0)
            .animation(
                enableFloating ?
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true) :
                .default,
                value: isFloating
            )
            .onAppear {
                startFloatingAnimation()
                loadIconIfNeeded()
                startShimmerAnimation()
            }
            .onDisappear {
                stopFloatingAnimation()
            }
            .onChange(of: character.iconURL) { newIconURL in
                loadIconIfNeeded()
            }
            .onChange(of: character.id) { newCharacterId in
                iconImage = nil
                loadIconIfNeeded()
                restartFloatingAnimation()
            }
            .onChange(of: enableFloating) { newValue in
                if newValue {
                    startFloatingAnimation()
                } else {
                    stopFloatingAnimation()
                }
            }
            .id("\(character.id)_\(character.iconURL ?? "default")_\(enableFloating)")
    }
    
    @ViewBuilder
    private var content: some View {
        if let iconImage = iconImage {
            customIconView(iconImage)
        } else if isLoading {
            loadingView
        } else {
            modernDefaultIcon
        }
    }
    
    // MARK: - 🌟 カスタムアイコンビュー（グラデーション境界線付き）
    private func customIconView(_ image: UIImage) -> some View {
        ZStack {
            // グロー効果
            Circle()
                .fill(character.intimacyStage.color.opacity(glowAnimation ? 0.3 : 0.1))
                .frame(width: size + 20, height: size + 20)
                .blur(radius: 10)
                .scaleEffect(glowAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowAnimation)
            
            // メイン画像
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    character.intimacyStage.color,
                                    character.intimacyStage.color.opacity(0.6),
                                    character.intimacyStage.color
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: character.intimacyStage.color.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - 🌟 モダンなデフォルトアイコン
    private var modernDefaultIcon: some View {
        ZStack {
            // 外側のグロー効果（より柔らかく）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            character.intimacyStage.color.opacity(glowAnimation ? 0.4 : 0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size + 30, height: size + 30)
                .blur(radius: 15)
                .scaleEffect(glowAnimation ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: glowAnimation)
            
            // メイン背景 - ニューモーフィズムスタイル
            Circle()
                .fill(
                    LinearGradient(
                        colors: getEnhancedGradientColors(),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // 内側シャドウ効果
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.black.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blur(radius: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 8, y: 8)
                .shadow(color: Color.white.opacity(0.8), radius: 20, x: -8, y: -8)
            
            // 動的シマーエフェクト（より洗練された）
//            Circle()
//                .fill(
//                    AngularGradient(
//                        colors: [
//                            Color.white.opacity(0),
//                            Color.white.opacity(0.6),
//                            Color.white.opacity(0),
//                            Color.white.opacity(0.3),
//                            Color.white.opacity(0)
//                        ],
//                        center: .center
//                    )
//                )
//                .frame(width: size * 0.9, height: size * 0.9)
//                .rotationEffect(.degrees(shimmerOffset))
//                .mask(Circle().frame(width: size, height: size))
//                .blendMode(.overlay)
            
            // メインコンテンツ
            VStack(spacing: size * 0.06) {
                // キャラクターアイコンエリア
                ZStack {
                    // アイコン背景 - グラスモーフィズム効果
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.65, height: size * 0.65)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                    
                    // SF Symbolsアイコン - 3D効果
                    ZStack {
                        // アイコンシャドウ
                        Image(systemName: getModernIconName())
                            .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.3))
                            .offset(x: 2, y: 2)
                            .blur(radius: 1)
                        
                        // メインアイコン
                        Image(systemName: getModernIconName())
                            .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: character.intimacyStage.color.opacity(0.6), radius: 3, x: 0, y: 1)
                    }
                    
                    // 親密度に応じたアクセント
                    if character.intimacyLevel >= 200 {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        character.intimacyStage.color.opacity(0.8),
                                        character.intimacyStage.color.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: size * 0.7, height: size * 0.7)
                            .rotationEffect(.degrees(glowAnimation ? 180 : 0))
                            .animation(.linear(duration: 6.0).repeatForever(autoreverses: false), value: glowAnimation)
                    }
                }
            }
            
            // 外側リング（高親密度）
            if character.intimacyLevel >= 500 {
                Circle()
                    .trim(from: 0, to: CGFloat(character.intimacyLevel) / 1000.0)
                    .stroke(
                        LinearGradient(
                            colors: [
                                character.intimacyStage.color.opacity(0.9),
                                character.intimacyStage.color.opacity(0.5),
                                character.intimacyStage.color.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: size + 12, height: size + 12)
                    .rotationEffect(.degrees(-90))
                    .overlay(
                        // プログレスリングの終端にドット
                        Circle()
                            .fill(character.intimacyStage.color)
                            .frame(width: 8, height: 8)
                            .offset(y: -(size + 12) / 2)
                            .rotationEffect(.degrees(CGFloat(character.intimacyLevel) / 1000.0 * 360 - 90))
                            .shadow(color: character.intimacyStage.color, radius: 4)
                    )
                    .shadow(color: character.intimacyStage.color.opacity(0.6), radius: 8, x: 0, y: 0)
            }
            
            // 最高レベルの特別効果
            if character.intimacyLevel >= 1000 {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(character.intimacyStage.color.opacity(0.6))
                        .frame(width: 4, height: 4)
                        .offset(y: -size * 0.6)
                        .rotationEffect(.degrees(Double(index) * 60 + (glowAnimation ? 360 : 0)))
                        .animation(
                            .linear(duration: 8.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.2),
                            value: glowAnimation
                        )
                        .blur(radius: 1)
                }
            }
        }
    }
    
    private func getEnhancedGradientColors() -> [Color] {
        switch character.intimacyStage {
        case .bestFriend:
            return [
                Color(red: 0.2, green: 0.6, blue: 1.0),
                Color(red: 0.4, green: 0.8, blue: 1.0),
//                Color(red: 0.0, green: 0.4, blue: 0.8)
            ]
        case .specialFriend:
            return [
                Color(red: 0.0, green: 0.8, blue: 1.0),
                Color(red: 0.4, green: 1.0, blue: 0.8),
//                Color(red: 0.0, green: 0.6, blue: 0.9)
            ]
        case .loveCandidate:
            return [
                Color(red: 0.0, green: 0.9, blue: 0.6),
                Color(red: 0.4, green: 1.0, blue: 0.8),
//                Color(red: 0.0, green: 0.7, blue: 0.4)
            ]
        case .lover:
            return [
                Color(red: 1.0, green: 0.4, blue: 0.7),
                Color(red: 1.0, green: 0.6, blue: 0.8),
//                Color(red: 0.8, green: 0.2, blue: 0.5)
            ]
        case .deepBondLover:
            return [
                Color(red: 0.9, green: 0.2, blue: 0.4),
                Color(red: 1.0, green: 0.5, blue: 0.6),
//                Color(red: 0.7, green: 0.1, blue: 0.3)
            ]
        case .soulConnectedLover:
            return [
                Color(red: 0.6, green: 0.3, blue: 1.0),
                Color(red: 0.8, green: 0.5, blue: 1.0),
//                Color(red: 0.4, green: 0.1, blue: 0.8)
            ]
        case .destinyLover:
            return [
                Color(red: 1.0, green: 0.6, blue: 0.2),
                Color(red: 1.0, green: 0.8, blue: 0.4),
//                Color(red: 0.9, green: 0.4, blue: 0.0)
            ]
        case .uniqueExistence:
            return [
                Color(red: 1.0, green: 0.8, blue: 0.2),
                Color(red: 1.0, green: 0.9, blue: 0.5),
//                Color(red: 0.8, green: 0.6, blue: 0.0)
            ]
        case .soulmate:
            return [
                Color(red: 0.4, green: 0.2, blue: 1.0),
                Color(red: 0.6, green: 0.4, blue: 1.0),
//                Color(red: 0.2, green: 0.0, blue: 0.8)
            ]
        case .eternalPromise:
            return [
                Color(red: 0.2, green: 0.8, blue: 0.8),
                Color(red: 0.4, green: 1.0, blue: 1.0),
//                Color(red: 0.0, green: 0.6, blue: 0.6)
            ]
        case .destinyPartner:
            return [
                Color(red: 0.4, green: 1.0, blue: 0.6),
                Color(red: 0.6, green: 1.0, blue: 0.8),
//                Color(red: 0.2, green: 0.8, blue: 0.4)
            ]
        case .oneHeart:
            return [
                Color(red: 0.8, green: 0.2, blue: 1.0),
                Color(red: 0.9, green: 0.5, blue: 1.0),
//                Color(red: 0.6, green: 0.0, blue: 0.8)
            ]
        case .miracleBond:
            return [
                Color(red: 1.0, green: 0.4, blue: 0.8),
                Color(red: 1.0, green: 0.7, blue: 0.9),
//                Color(red: 0.8, green: 0.0, blue: 0.6)
            ]
        case .sacredLove:
            return [
                Color(red: 1.0, green: 0.5, blue: 0.2),
                Color(red: 1.0, green: 0.7, blue: 0.4),
//                Color(red: 0.8, green: 0.3, blue: 0.0)
            ]
        case .ultimateLove:
            return [
                Color(red: 1.0, green: 0.0, blue: 0.5),
                Color(red: 1.0, green: 0.4, blue: 0.7),
                Color(red: 0.8, green: 0.2, blue: 1.0),
                Color(red: 0.6, green: 0.4, blue: 1.0),
//                Color(red: 0.4, green: 0.6, blue: 1.0)
            ]
        }
    }

//    @ViewBuilder
//    private var intimacyIndicator: some View {
//        let heartCount = getHeartCount()
//        let maxHearts = 5
//        
//        HStack(spacing: size * 0.02) {
//            ForEach(0..<maxHearts, id: \.self) { index in
//                let isFilled = index < heartCount
//                let isPartial = index == heartCount && character.intimacyLevel % 200 > 100
//                
//                ZStack {
//                    // 背景ハート
//                    Image(systemName: "heart")
//                        .font(.system(size: size * 0.07, weight: .medium))
//                        .foregroundColor(.white.opacity(0.3))
//                    
//                    // フィルハート
//                    if isFilled {
//                        Image(systemName: "heart.fill")
//                            .font(.system(size: size * 0.07, weight: .medium))
//                            .foregroundStyle(
//                                LinearGradient(
//                                    colors: [
//                                        character.intimacyStage.color,
//                                        character.intimacyStage.color.opacity(0.8)
//                                    ],
//                                    startPoint: .topLeading,
//                                    endPoint: .bottomTrailing
//                                )
//                            )
//                            .shadow(color: character.intimacyStage.color.opacity(0.6), radius: 2)
//                            .scaleEffect(glowAnimation ? 1.1 : 1.0)
//                            .animation(
//                                .easeInOut(duration: 2.0)
//                                .repeatForever(autoreverses: true)
//                                .delay(Double(index) * 0.2),
//                                value: glowAnimation
//                            )
//                    } else if isPartial {
//                        Image(systemName: "heart.lefthalf.filled")
//                            .font(.system(size: size * 0.07, weight: .medium))
//                            .foregroundColor(character.intimacyStage.color)
//                            .shadow(color: character.intimacyStage.color.opacity(0.4), radius: 1)
//                    }
//                }
//            }
//        }
//    }
    // MARK: - 🌟 ローディングビュー
    private var loadingView: some View {
        ZStack {
            // 背景
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // ローディングアニメーション
            VStack(spacing: size * 0.1) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: character.intimacyStage.color))
                    .scaleEffect(size > 100 ? 1.2 : 0.8)
                
                if size > 80 {
                    Text("読み込み中...")
                        .font(.system(size: size * 0.08, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - ヘルパーメソッド
    
    private func getDefaultGradientColors() -> [Color] {
        switch character.intimacyStage {
        case .bestFriend:
            return [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)]
        case .specialFriend:
            return [Color.cyan.opacity(0.8), Color.mint.opacity(0.6)]
        case .loveCandidate:
            return [Color.green.opacity(0.8), Color.mint.opacity(0.6)]
        case .lover:
            return [Color.pink.opacity(0.8), Color.red.opacity(0.6)]
        case .deepBondLover:
            return [Color.red.opacity(0.8), Color.pink.opacity(0.6)]
        case .soulConnectedLover:
            return [Color.purple.opacity(0.8), Color.pink.opacity(0.6)]
        case .destinyLover:
            return [Color.orange.opacity(0.8), Color.yellow.opacity(0.6)]
        case .uniqueExistence:
            return [Color.yellow.opacity(0.8), Color.orange.opacity(0.6)]
        case .soulmate:
            return [Color.indigo.opacity(0.8), Color.purple.opacity(0.6)]
        case .eternalPromise:
            return [Color.teal.opacity(0.8), Color.cyan.opacity(0.6)]
        case .destinyPartner:
            return [Color.mint.opacity(0.8), Color.green.opacity(0.6)]
        case .oneHeart:
            return [Color.purple.opacity(0.8), Color.indigo.opacity(0.6)]
        case .miracleBond:
            return [Color.pink.opacity(0.8), Color.purple.opacity(0.6)]
        case .sacredLove:
            return [Color.orange.opacity(0.8), Color.red.opacity(0.6)]
        case .ultimateLove:
            return [
                Color.red.opacity(0.9),
                Color.pink.opacity(0.7),
                Color.purple.opacity(0.8),
                Color.blue.opacity(0.6)
            ]
        }
    }
    
    private func getModernIconName() -> String {
        switch character.intimacyStage {
        case .bestFriend:
            return "person.fill"
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
    
    // MARK: - アニメーション管理メソッド
    
    private func startFloatingAnimation() {
        guard enableFloating else { return }
        
        stopFloatingAnimation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                self.isFloating = true
            }
        }
        
        // グロー効果開始
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowAnimation = true
        }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            DispatchQueue.main.async {
                guard self.enableFloating else { return }
                
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    self.isFloating.toggle()
                }
            }
        }
    }
    
    private func stopFloatingAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isFloating = false
            glowAnimation = false
        }
    }
    
    private func restartFloatingAnimation() {
        guard enableFloating else { return }
        
        stopFloatingAnimation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startFloatingAnimation()
        }
    }
    
    private func startShimmerAnimation() {
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            shimmerOffset = size + 100
        }
    }
    
    private func loadIconIfNeeded() {
        guard let iconURL = character.iconURL,
              !iconURL.isEmpty,
              let url = URL(string: iconURL) else {
            print("CharacterIconView: アイコンURLが空またはキャラクターが無効 - デフォルトアイコンを表示")
            iconImage = nil
            return
        }
        
        if iconImage != nil && character.iconURL == iconURL {
            return
        }
        
        print("CharacterIconView: アイコン画像を読み込み中 - \(iconURL)")
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    if let loadedImage = UIImage(data: data) {
                        self.iconImage = loadedImage
                        print("CharacterIconView: アイコン読み込み成功")
                    } else {
                        print("CharacterIconView: アイコンデータの変換に失敗")
                        self.iconImage = nil
                    }
                    self.isLoading = false
                }
            } catch {
                print("CharacterIconView: アイコン読み込みエラー - \(error.localizedDescription)")
                await MainActor.run {
                    self.iconImage = nil
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        // 親友レベル
        CharacterIconView(
            character: Character(
                name: "テスト親友",
                personality: "優しい",
                speakingStyle: "丁寧",
                iconName: "person.circle.fill"
            ),
            size: 200,
            enableFloating: true
        )
        
        // 恋人レベル
//        CharacterIconView(
//            character: {
//                var char = Character(
//                    name: "テスト恋人",
//                    personality: "ロマンチック",
//                    speakingStyle: "愛情深い",
//                    iconName: "heart.circle.fill"
//                )
//                char.intimacyLevel = 400
//                return char
//            }(),
//            size: 100,
//            enableFloating: true
//        )
//        
//        // 究極の愛レベル
//        CharacterIconView(
//            character: {
//                var char = Character(
//                    name: "テスト究極",
//                    personality: "神聖",
//                    speakingStyle: "超越的",
//                    iconName: "flame.fill"
//                )
//                char.intimacyLevel = 5000
//                return char
//            }(),
//            size: 80,
//            enableFloating: false
//        )
    }
    .padding()
    .background(Color.black.opacity(0.1))
}
