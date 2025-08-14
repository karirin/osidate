//
//  SplashScreenView.swift
//  osidate
//
//  アプリ起動時のスプラッシュスクリーン
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var currentPhase = 0
    @State private var heartScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var backgroundOpacity: Double = 0
    @State private var showSubtitle = false
    @State private var floatingOffset: CGFloat = 50
    @State private var shimmerOffset: CGFloat = -300
    @State private var rotationAngle: Double = 0
    
    // 完了コールバック
    let onSplashComplete: () -> Void
    
    private let splashPhases = [
        "", "", "", ""
    ]
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    Color.pink.opacity(0.3),
                    Color.purple.opacity(0.4),
                    Color.blue.opacity(0.3),
                    Color.pink.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(backgroundOpacity)
            .animation(.easeInOut(duration: 1.0), value: backgroundOpacity)
            
            // 動的背景パーティクル
            ForEach(0..<15, id: \.self) { index in
                BackgroundParticle(index: index, isAnimating: isAnimating)
            }
            
            VStack(spacing: 50) {
                Spacer()
                
                // メインロゴエリア
                ZStack {
                    // 外側のオーラリング
                    ForEach(0..<3, id: \.self) { ringIndex in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.pink.opacity(0.3),
                                        Color.purple.opacity(0.4),
                                        Color.blue.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 120 + CGFloat(ringIndex * 30))
                            .opacity(ringOpacity * (1.0 - Double(ringIndex) * 0.3))
                            .scaleEffect(heartScale + CGFloat(ringIndex) * 0.1)
                            .rotationEffect(.degrees(rotationAngle + Double(ringIndex * 60)))
                            .animation(
                                .easeInOut(duration: 2.0 + Double(ringIndex) * 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(ringIndex) * 0.3),
                                value: heartScale
                            )
                    }
                    
                    // 中央のメインロゴ
                    ZStack {
                        // 背景円
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.pink.opacity(0.8),
                                        Color.purple.opacity(0.9),
                                        Color.pink.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(
                                color: Color.pink.opacity(0.4),
                                radius: 20,
                                x: 0,
                                y: 10
                            )
                        
                        // ハートアイコン
                        Image(systemName: "heart.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        // シマー効果
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40, height: 100)
                            .offset(x: shimmerOffset)
                            .animation(
                                .linear(duration: 2.0)
                                .repeatForever(autoreverses: false),
                                value: shimmerOffset
                            )
                            .clipped()
                            .mask(Circle().frame(width: 100, height: 100))
                    }
                    .scaleEffect(logoScale)
//                    .rotationEffect(.degrees(rotationAngle * 0.1))
                    
                    // フローティングエモジ
                    ForEach(0..<4, id: \.self) { index in
                        Text(splashPhases[index])
                            .font(.title)
                            .opacity(currentPhase >= index ? 1.0 : 0.3)
                            .scaleEffect(currentPhase == index ? 1.3 : 1.0)
                            .offset(
                                x: cos(Double(index) * .pi / 2) * 70,
                                y: sin(Double(index) * .pi / 2) * 70 + floatingOffset
                            )
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(Double(index) * 0.2),
                                value: currentPhase
                            )
                            .animation(
                                .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                                value: floatingOffset
                            )
                    }
                }
                .frame(width: 200, height: 200)
                
                // アプリタイトル
                VStack(spacing: 16) {
                    Text("推しとの特別な時間")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.pink.opacity(0.9),
                                    Color.purple.opacity(0.9),
                                    Color.blue.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                        .scaleEffect(logoScale)
                    
                    if showSubtitle {
                        Text("あなただけの恋人体験アプリ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .opacity(textOpacity * 0.8)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                
                Spacer()
                
                // ローディングインジケーター
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.pink, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 8, height: 8)
                                .scaleEffect(isAnimating ? 1.0 : 0.6)
                                .opacity(isAnimating ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    
                    Text("起動中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(textOpacity * 0.6)
                }
                .opacity(textOpacity)
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startSplashAnimation()
        }
    }
    
    private func startSplashAnimation() {
        // Phase 1: 背景とリングのフェードイン (0-1秒)
        withAnimation(.easeInOut(duration: 0.8)) {
            backgroundOpacity = 1.0
            ringOpacity = 1.0
        }
        
        // Phase 2: ロゴのスケールアップ (0.5-1.5秒)
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.5)) {
            logoScale = 1.0
            heartScale = 1.0
        }
        
        // Phase 3: シマー効果開始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                shimmerOffset = 300
            }
        }
        
        // Phase 4: 回転アニメーション開始
        withAnimation(
            .linear(duration: 10.0)
            .repeatForever(autoreverses: false)
        ) {
            rotationAngle = 360
        }
        
        // Phase 5: フローティング開始
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
            .delay(1.0)
        ) {
            floatingOffset = -20
        }
        
        // Phase 6: テキストフェードイン (1.2-2秒)
        withAnimation(.easeInOut(duration: 0.8).delay(1.2)) {
            textOpacity = 1.0
        }
        
        // Phase 7: サブタイトル表示 (1.8秒)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.6)) {
                showSubtitle = true
            }
        }
        
        // Phase 8: ローディングドット開始 (2秒)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isAnimating = true
        }
        
        // Phase 9: エモジアニメーション (2.5-4秒)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            startEmojiSequence()
        }
        
        // Phase 10: スプラッシュ完了 (5秒後)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            completeSplash()
        }
    }
    
    private func startEmojiSequence() {
        for i in 0..<splashPhases.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    currentPhase = i
                }
            }
        }
    }
    
    private func completeSplash() {
        withAnimation(.easeInOut(duration: 0.8)) {
            // フェードアウト効果
            backgroundOpacity = 0
            textOpacity = 0
            logoScale = 1.2
            ringOpacity = 0
        }
        
        // アニメーション完了後にコールバック実行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onSplashComplete()
        }
    }
}

// 背景パーティクルコンポーネント
struct BackgroundParticle: View {
    let index: Int
    let isAnimating: Bool
    
    @State private var position = CGPoint.zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5
    
    private let particles = ["", "", "", "", ""]
    
    var body: some View {
        Text(particles[index % particles.count])
            .font(.caption)
            .opacity(opacity)
            .scaleEffect(scale)
            .position(position)
            .onAppear {
                startParticleAnimation()
            }
    }
    
    private func startParticleAnimation() {
        // ランダムな初期位置
        position = CGPoint(
            x: CGFloat.random(in: 50...350),
            y: CGFloat.random(in: 100...700)
        )
        
        withAnimation(
            .easeInOut(duration: Double.random(in: 3.0...6.0))
            .repeatForever(autoreverses: true)
            .delay(Double.random(in: 0...2.0))
        ) {
            opacity = Double.random(in: 0.3...0.8)
            scale = CGFloat.random(in: 0.8...1.5)
            
            // ゆっくりとした移動
            position.x += CGFloat.random(in: -50...50)
            position.y += CGFloat.random(in: -100...100)
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView{}
    }
}
