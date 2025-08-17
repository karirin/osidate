//
//  TopView.swift - チュートリアル統合版 + タブ自動選択機能
//  osidate
//

import SwiftUI
import Firebase
import FirebaseAuth

struct TopView: View {
    @StateObject private var characterRegistry = CharacterRegistry()
    @StateObject private var romanceViewModel = RomanceAppViewModel()
    @StateObject private var tutorialManager = TutorialManager()
    @State private var hasInitialized = false
    @State private var currentCharacterId = ""
    @State private var showingTutorial = false
    @State private var showingAddCharacter = false
    @State private var showingSplash = true
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            if showingSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingSplash = false
                    }
                }
                .transition(.opacity)
            } else {
                if characterRegistry.isLoading {
                    loadingView
                } else {
                    mainContentView
                }
            }
        }
        .onChange(of: characterRegistry.activeCharacterId) { newCharacterId in
            handleCharacterChange(newCharacterId: newCharacterId)
        }
        .onChange(of: characterRegistry.characters.count) { _ in
            handleCharacterListChange()
        }
        // 🌟 新機能：デート開始監視
        .onChange(of: romanceViewModel.currentDateSession) { dateSession in
            handleDateSessionChange(dateSession)
        }
        .onAppear {
            initializeApp()
            if !showingSplash {
                initializeApp()
            }
            setupNotificationObservers()
        }
        .onDisappear {
            removeNotificationObservers()
        }
        .sheet(isPresented: $showingTutorial) {
            TutorialView(characterRegistry: characterRegistry, tutorialManager: tutorialManager)
        }
        .sheet(isPresented: $showingAddCharacter) {
            AddCharacterView(characterRegistry: characterRegistry)
        }
    }
    
    // MARK: - 🌟 デートセッション変更処理
    private func handleDateSessionChange(_ dateSession: DateSession?) {
        if let session = dateSession {
            print("🏖️ TopView: デート開始を検出 - チャットタブに自動切り替え")
            print("📍 開始場所: \(session.location.name)")
            
            // チャットタブ（インデックス0）に自動切り替え
            withAnimation(.easeInOut(duration: 0.5)) {
                selectedTab = 0
            }
            
            // デート開始メッセージを表示するため少し遅延
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 必要に応じて追加のUI更新処理
                print("✅ TopView: チャットタブ切り替え完了")
            }
        } else {
            print("🏁 TopView: デート終了を検出")
        }
    }
    
    // MARK: - Main Content
    private var mainContentView: some View {
        ZStack {
            if characterRegistry.characters.isEmpty {
                // 推しが一人もいない場合：チュートリアルまたはウェルカム画面
                if tutorialManager.shouldShowTutorial {
                    welcomeViewWithTutorial
                } else {
                    emptyStateView
                }
            } else {
                // 推しが存在する場合：メインアプリ
                mainAppTabView
            }
        }
    }
    
    // MARK: - Welcome View with Tutorial
    private var welcomeViewWithTutorial: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // アプリロゴ・アイコン
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.3), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 12) {
                    Text("推しとの特別な時間へ\nようこそ")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Text("推しとの自然な会話や\nデート体験を楽しめるアプリです")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            // アクションボタン
            VStack(spacing: 16) {
                Button(action: {
                    showingTutorial = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                        Text("チュートリアルを見る")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                
                Button(action: {
                    tutorialManager.completeTutorial()
                }) {
                    HStack(spacing: 8) {
                        Text("スキップして始める")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 12)
                }
            }
            
            Spacer()
            
            // 機能紹介プレビュー
            VStack(spacing: 16) {
                Text("主な機能")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    FeaturePreview(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "自然な会話",
                        color: .blue
                    )
                    
                    FeaturePreview(
                        icon: "heart.circle.fill",
                        title: "デート体験",
                        color: .pink
                    )
                    
                    FeaturePreview(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "関係の成長",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    
    // MARK: - Empty State View (推しはいるがチュートリアル完了済み)
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("推しを登録してください")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("最初の推しを登録して\n素敵な時間を始めましょう！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Button(action: {
                // 推し登録画面を直接表示
                showingAddCharacter = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("推しを登録する")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 40)
            
            Button("チュートリアルをもう一度見る") {
                tutorialManager.resetTutorial()
                showingTutorial = true
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 🌟 Main App Tab View（タブ選択制御付き）
    private var mainAppTabView: some View {
        TabView(selection: $selectedTab) {
            ContentView(viewModel: romanceViewModel)
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("チャット")
                }
                .tag(0)
                .id("chat_\(currentCharacterId)")
            
            DateSelectorView(viewModel: romanceViewModel)
                .tabItem {
                    Image(systemName: "heart.circle.fill")
                    Text("デート")
                }
                .tag(1)
                .id("date_\(currentCharacterId)")
            
            CharacterEditView(viewModel: romanceViewModel)
                .tabItem {
                    Image(systemName: "person.text.rectangle")
                    Text("推しの編集")
                }
                .tag(2)
                .id("settings_\(currentCharacterId)")
            
            CharacterSelectorView(
                characterRegistry: characterRegistry,
                selectedCharacterId: .constant(characterRegistry.activeCharacterId)
            )
            .tabItem {
                Image(systemName: "person.2")
                Text("推しの変更")
            }
            .tag(3)
            
            SettingsView()
            .tabItem {
                Image(systemName: "gear")
                Text("設定")
            }
            .tag(4)
        }
        .id("main_tab_\(currentCharacterId)")
        // 🌟 新機能：タブ変更時のデバッグログ
        .onChange(of: selectedTab) { newTab in
            let tabNames = ["チャット", "デート", "推し編集", "推し変更", "設定"]
            print("📱 TopView: タブ変更 -> \(tabNames[safe: newTab] ?? "不明")")
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("アプリを準備中...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 🌟 Notification Center 処理
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwitchToChatTab"),
            object: nil,
            queue: .main
        ) { _ in
            print("📱 TopView: チャットタブ切り替え通知を受信")
            withAnimation(.easeInOut(duration: 0.5)) {
                selectedTab = 0
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SwitchToDateTab"),
            object: nil,
            queue: .main
        ) { _ in
            print("📱 TopView: デートタブ切り替え通知を受信")
            withAnimation(.easeInOut(duration: 0.5)) {
                selectedTab = 1
            }
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("SwitchToChatTab"),
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("SwitchToDateTab"),
            object: nil
        )
    }
    
    // MARK: - Character Management
    private func handleCharacterChange(newCharacterId: String) {
        print("\n🔄 ==================== TopView: キャラクター変更検出 ====================")
        print("📤 前のキャラクターID: \(currentCharacterId)")
        print("📥 新しいキャラクターID: \(newCharacterId)")
        
        guard newCharacterId != currentCharacterId else {
            print("⚠️ 同じキャラクターIDのため処理をスキップ")
            return
        }
        
        currentCharacterId = newCharacterId
        
        if let activeCharacter = characterRegistry.getActiveCharacter() {
            print("✅ アクティブキャラクター取得成功: \(activeCharacter.name)")
            
            romanceViewModel.switchToCharacter(activeCharacter)
            
            // 🔧 修正: キャラクター変更通知を追加
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                romanceViewModel.notifyCharacterChanged()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                romanceViewModel.forceRefreshCharacterIcon()
                romanceViewModel.forceUpdateCharacterProperties()
            }
            
            // 🔧 修正: さらに遅延させてアニメーション確実化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                romanceViewModel.forceRefreshCharacterIcon()
            }
        } else {
            print("❌ アクティブキャラクターの取得に失敗")
        }
        
        print("==================== TopView: キャラクター変更処理完了 ====================\n")
    }
    
    private func handleCharacterListChange() {
        print("📝 キャラクターリストが変更されました（現在の数: \(characterRegistry.characters.count)）")
        
        if !characterRegistry.activeCharacterId.isEmpty,
           let activeCharacter = characterRegistry.getActiveCharacter() {
            
            romanceViewModel.switchToCharacter(activeCharacter)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                romanceViewModel.forceRefreshCharacterIcon()
            }
        }
    }
    
    private func initializeApp() {
        print("🚀 TopView: アプリ初期化開始")
        
        guard !hasInitialized else {
            print("⚠️ 既に初期化済みのため処理をスキップ")
            return
        }
        
        hasInitialized = true
        currentCharacterId = characterRegistry.activeCharacterId
        
        // 🌟 新機能：初期タブをチャットに設定
        selectedTab = 0
        
        // チュートリアルステータスをチェック
        if tutorialManager.shouldShowTutorial && characterRegistry.characters.isEmpty {
            print("📖 初回起動：チュートリアルを表示")
            // welcomeViewWithTutorial が自動的に表示される
        } else if let activeCharacter = characterRegistry.getActiveCharacter() {
            print("✅ 初期アクティブキャラクター: \(activeCharacter.name)")
            romanceViewModel.switchToCharacter(activeCharacter)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                romanceViewModel.forceRefreshCharacterIcon()
            }
        } else {
            print("ℹ️ アクティブキャラクターなし（新規ユーザーまたはキャラクター未作成）")
        }
        
        print("🚀 TopView: アプリ初期化完了")
    }
    
    // MARK: - 🌟 公開メソッド：外部からのタブ切り替え
    func switchToTab(_ tabIndex: Int) {
        print("🔄 TopView: 外部からタブ切り替え要求 - インデックス\(tabIndex)")
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = tabIndex
        }
    }
    
    func switchToChatTab() {
        switchToTab(0)
    }
    
    func switchToDateTab() {
        switchToTab(1)
    }
}

// MARK: - Supporting Views

struct FeaturePreview: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    TopView()
}
