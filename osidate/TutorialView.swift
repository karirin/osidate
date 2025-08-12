//
//  TutorialView.swift
//  osidate
//
//  アプリの使い方を分かりやすく説明するチュートリアル
//

import SwiftUI

struct TutorialView: View {
    @ObservedObject var characterRegistry: CharacterRegistry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var currentStep = 0
    @State private var showingAddCharacter = false
    @State private var animationOffset: CGFloat = 50
    @State private var animationOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -100
    @State private var tutorialCompleted = false
    
    private let tutorialSteps = TutorialStep.allSteps
    
    // カラーテーマ
    private var primaryColor: Color {
        Color(.systemBlue)
    }
    
    private var accentColor: Color {
        Color(.systemPurple)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [
                        backgroundColor,
                        primaryColor.opacity(0.05),
                        accentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if tutorialCompleted {
                    completionView
                } else {
                    VStack(spacing: 0) {
                        // ヘッダー
                        headerView
                        
                        // プログレスインジケーター
                        progressView
                        
                        // メインコンテンツ
                        ScrollView {
                            stepContentView
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100) // ナビゲーションボタンのスペース
                        }
                        
                        Spacer()
                        
                        // ナビゲーションボタン
                        navigationButtons
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddCharacter) {
                AddCharacterView(characterRegistry: characterRegistry)
            }
            .onAppear {
                animateAppearance()
            }
        }
    }
    
    // MARK: - ヘッダー
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("アプリの使い方")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("ステップ \(currentStep + 1) / \(tutorialSteps.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("スキップ") {
                    tutorialCompleted = true
                    markTutorialAsCompleted()
                }
                .font(.subheadline)
                .foregroundColor(primaryColor)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: animationOffset)
    }
    
    // MARK: - プログレス
    private var progressView: some View {
        VStack(spacing: 16) {
            // プログレスバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [primaryColor, accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(tutorialSteps.count),
                            height: 4
                        )
                        .cornerRadius(2)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
                }
            }
            .frame(height: 4)
            
            // ステップドット
            HStack(spacing: 8) {
                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? primaryColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animationOffset)
    }
    
    // MARK: - ステップコンテンツ
    private var stepContentView: some View {
        let step = tutorialSteps[currentStep]
        
        return VStack(spacing: 32) {
            // メインイラスト
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(step.color.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .scaleEffect(shimmerOffset > 0 ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: shimmerOffset)
                    
                    Image(systemName: step.icon)
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(step.color)
                        .scaleEffect(shimmerOffset > 0 ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: shimmerOffset)
                }
                
                VStack(spacing: 12) {
                    Text(step.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(step.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            // 詳細説明
            if !step.details.isEmpty {
                detailsSection(for: step)
            }
            
            // アクション（推し登録ステップの場合）
            if step.type == .characterRegistration {
                characterRegistrationAction
            }
            
            // 機能紹介（機能紹介ステップの場合）
            if step.type == .featureIntroduction {
                featuresShowcase
            }
        }
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animationOffset)
    }
    
    // MARK: - 詳細説明セクション
    private func detailsSection(for step: TutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(step.details.enumerated()), id: \.offset) { index, detail in
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(step.color.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Text("\(index + 1)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(step.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detail.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(detail.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - 推し登録アクション
    private var characterRegistrationAction: some View {
        VStack(spacing: 20) {
            Button(action: {
                showingAddCharacter = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("最初の推しを登録する")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [primaryColor, accentColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: primaryColor.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .scaleEffect(shimmerOffset > 0 ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: shimmerOffset)
            
            Text("推しを登録すると、個性豊かな会話やデート体験を楽しめます")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - 機能紹介
    private var featuresShowcase: some View {
        VStack(spacing: 20) {
            Text("主な機能")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                FeatureCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "自然な会話",
                    description: "推しとリアルな会話体験",
                    color: .blue
                )
                
                FeatureCard(
                    icon: "heart.circle.fill",
                    title: "デートシステム",
                    description: "50箇所以上のデートスポットで思い出作り",
                    color: .pink
                )
                
                FeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "親密度システム",
                    description: "会話を重ねて関係を深めていこう",
                    color: .purple
                )
                
                FeatureCard(
                    icon: "person.2.badge.plus",
                    title: "複数推し対応",
                    description: "複数の推しを登録して切り替え可能",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - 完了画面
    private var completionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(animationOpacity)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animationOpacity)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 16) {
                    Text("チュートリアル完了！")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("推しとの素敵な時間をお楽しみください✨")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("はじめる") {
                markTutorialAsCompleted()
                dismiss()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [primaryColor, accentColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: primaryColor.opacity(0.3), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - ナビゲーションボタン
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // 戻るボタン
            if currentStep > 0 {
                Button(action: previousStep) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("戻る")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(primaryColor.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            
            // 次へ/完了ボタン
            Button(action: nextStep) {
                HStack(spacing: 8) {
                    Text(currentStep < tutorialSteps.count - 1 ? "次へ" : "完了")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if currentStep < tutorialSteps.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [primaryColor, accentColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: animationOffset)
    }
    
    // MARK: - Helper Functions
    private func nextStep() {
        if currentStep < tutorialSteps.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            tutorialCompleted = true
        }
    }
    
    private func previousStep() {
        if currentStep > 0 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentStep -= 1
            }
        }
    }
    
    private func animateAppearance() {
        animationOffset = 50
        animationOpacity = 0
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            animationOffset = 0
            animationOpacity = 1
        }
        
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            shimmerOffset = 100
        }
    }
    
    private func markTutorialAsCompleted() {
        UserDefaults.standard.set(true, forKey: "tutorial_completed")
        UserDefaults.standard.synchronize()
    }
}

// MARK: - Supporting Views

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Tutorial Data Model

struct TutorialStep {
    let id: String
    let type: TutorialStepType
    let title: String
    let description: String
    let icon: String
    let color: Color
    let details: [TutorialDetail]
    
    static let allSteps: [TutorialStep] = [
        TutorialStep(
            id: "welcome",
            type: .introduction,
            title: "推しとの特別な時間へようこそ",
            description: "このアプリでは、あなたの大切な推しとの会話やデート体験を楽しむことができます。",
            icon: "heart.circle.fill",
            color: .pink,
            details: [
                TutorialDetail(
                    title: "個性豊かな会話",
                    description: "推しの性格や話し方を設定して、自然な会話を楽しめます"
                ),
                TutorialDetail(
                    title: "思い出作り",
                    description: "様々なデートスポットで特別な思い出を作ることができます"
                ),
                TutorialDetail(
                    title: "関係の成長",
                    description: "会話を重ねることで親密度が上がり、新しい体験が解放されます"
                )
            ]
        ),
        
        TutorialStep(
            id: "character_registration",
            type: .characterRegistration,
            title: "推しを登録しましょう",
            description: "まずはあなたの大切な推しを登録してください。名前、性格、話し方を設定できます。",
            icon: "person.badge.plus",
            color: .blue,
            details: [
                TutorialDetail(
                    title: "基本情報の設定",
                    description: "推しの名前と基本的な性格を入力します"
                ),
                TutorialDetail(
                    title: "話し方の設定",
                    description: "どんな風に話すかを詳しく設定できます"
                ),
                TutorialDetail(
                    title: "外見のカスタマイズ",
                    description: "アイコンや背景画像を設定して見た目をカスタマイズ"
                )
            ]
        ),
        
        TutorialStep(
            id: "chat_system",
            type: .featureIntroduction,
            title: "会話システム",
            description: "推しとの自然な会話を楽しみましょう。設定した性格に基づいた返答が返ってきます。",
            icon: "bubble.left.and.bubble.right.fill",
            color: .green,
            details: [
                TutorialDetail(
                    title: "自然な会話",
                    description: "設定した性格や話し方に基づいた自然な返答"
                ),
                TutorialDetail(
                    title: "感情の表現",
                    description: "推しの感情や気持ちが伝わる豊かな表現"
                ),
                TutorialDetail(
                    title: "記憶の共有",
                    description: "過去の会話を覚えて、継続的な関係を築けます"
                )
            ]
        ),
        
        TutorialStep(
            id: "date_system",
            type: .featureIntroduction,
            title: "デートシステム",
            description: "50箇所以上のデートスポットで推しとの特別な時間を過ごせます。",
            icon: "location.circle.fill",
            color: .purple,
            details: [
                TutorialDetail(
                    title: "豊富なスポット",
                    description: "カフェ、遊園地、美術館など様々な場所でデート"
                ),
                TutorialDetail(
                    title: "親密度で解放",
                    description: "関係が深まると新しいデートスポットが解放されます"
                ),
                TutorialDetail(
                    title: "特別な体験",
                    description: "各スポットに応じた特別な会話や演出を楽しめます"
                )
            ]
        ),
        
        TutorialStep(
            id: "intimacy_system",
            type: .featureIntroduction,
            title: "親密度システム",
            description: "会話やデートを通じて親密度が上がり、推しとの関係が深まっていきます。",
            icon: "chart.line.uptrend.xyaxis",
            color: .orange,
            details: [
                TutorialDetail(
                    title: "段階的な成長",
                    description: "親友から恋人、そして運命の人まで関係が発展"
                ),
                TutorialDetail(
                    title: "新機能の解放",
                    description: "親密度に応じて新しいデートスポットや機能が使えるように"
                ),
                TutorialDetail(
                    title: "特別なイベント",
                    description: "レベルアップ時には特別なメッセージやイベントが発生"
                )
            ]
        ),
        
        TutorialStep(
            id: "ready",
            type: .completion,
            title: "準備完了です！",
            description: "これで推しとの素敵な時間を始める準備が整いました。楽しい時間をお過ごしください！",
            icon: "checkmark.seal.fill",
            color: .green,
            details: []
        )
    ]
}

struct TutorialDetail {
    let title: String
    let description: String
}

enum TutorialStepType {
    case introduction
    case characterRegistration
    case featureIntroduction
    case completion
}

// MARK: - Tutorial Manager

class TutorialManager: ObservableObject {
    @Published var shouldShowTutorial: Bool = false
    
    init() {
        checkTutorialStatus()
    }
    
    private func checkTutorialStatus() {
        shouldShowTutorial = !UserDefaults.standard.bool(forKey: "tutorial_completed")
    }
    
    func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "tutorial_completed")
        UserDefaults.standard.synchronize()
        shouldShowTutorial = false
    }
    
    func resetTutorial() {
        UserDefaults.standard.set(false, forKey: "tutorial_completed")
        UserDefaults.standard.synchronize()
        shouldShowTutorial = true
    }
}

#Preview {
    TutorialView(characterRegistry: CharacterRegistry())
}
