//
//  TopView.swift - キャラクター切り替え監視強化版
//  osidate
//

import SwiftUI
import Firebase
import FirebaseAuth

struct TopView: View {
    @StateObject private var characterRegistry = CharacterRegistry()
    @StateObject private var romanceViewModel = RomanceAppViewModel()
    @State private var hasInitialized = false
    @State private var currentCharacterId = ""
    
    var body: some View {
        ZStack {
            if characterRegistry.isLoading {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else {
                // Main app with tab navigation
                TabView {
                    ContentView(viewModel: romanceViewModel)
                        .tabItem {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("チャット")
                        }
                        .id("chat_\(currentCharacterId)") // 🔧 修正：タブごとに一意のIDを付与
                    
                    DateSelectorView(viewModel: romanceViewModel)
                        .tabItem {
                            Image(systemName: "heart.circle.fill")
                            Text("デート")
                        }
                        .id("date_\(currentCharacterId)") // 🔧 修正：タブごとに一意のIDを付与
                    
                    SettingsView(viewModel: romanceViewModel)
                        .tabItem {
                            Image(systemName: "person.text.rectangle")
                            Text("推しの編集")
                        }
                        .id("settings_\(currentCharacterId)") // 🔧 修正：タブごとに一意のIDを付与
                    
                    CharacterSelectorView(
                        characterRegistry: characterRegistry,
                        selectedCharacterId: .constant(characterRegistry.activeCharacterId)
                    )
                    .tabItem {
                        Image(systemName: "person.2")
                        Text("推しの変更")
                    }
                }
                .id("main_tab_\(currentCharacterId)") // 🔧 修正：TabView全体にも一意のIDを付与
            }
        }
        .onChange(of: characterRegistry.activeCharacterId) { newCharacterId in
            handleCharacterChange(newCharacterId: newCharacterId)
        }
        .onChange(of: characterRegistry.characters.count) { _ in
            // キャラクター数が変更された時（新規作成・削除）の処理
            handleCharacterListChange()
        }
        .onAppear {
            initializeApp()
        }
    }
    
    // 🔧 修正：キャラクター変更時の処理を強化
    private func handleCharacterChange(newCharacterId: String) {
        print("\n🔄 ==================== TopView: キャラクター変更検出 ====================")
        print("📤 前のキャラクターID: \(currentCharacterId)")
        print("📥 新しいキャラクターID: \(newCharacterId)")
        
        // IDが実際に変更された場合のみ処理
        guard newCharacterId != currentCharacterId else {
            print("⚠️ 同じキャラクターIDのため処理をスキップ")
            return
        }
        
        currentCharacterId = newCharacterId
        
        if let activeCharacter = characterRegistry.getActiveCharacter() {
            print("✅ アクティブキャラクター取得成功: \(activeCharacter.name)")
            
            // RomanceAppViewModelに切り替えを通知
            romanceViewModel.switchToCharacter(activeCharacter)
            
            // 🔧 修正：少し遅延してから強制的にUI更新を実行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                romanceViewModel.forceRefreshCharacterIcon()
                romanceViewModel.forceUpdateCharacterProperties()
            }
            
            // さらに遅延してもう一度更新（確実にするため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                romanceViewModel.forceRefreshCharacterIcon()
            }
        } else {
            print("❌ アクティブキャラクターの取得に失敗")
        }
        
        print("==================== TopView: キャラクター変更処理完了 ====================\n")
    }
    
    // 🔧 修正：キャラクターリスト変更時の処理
    private func handleCharacterListChange() {
        print("📝 キャラクターリストが変更されました（現在の数: \(characterRegistry.characters.count)）")
        
        // 現在のアクティブキャラクターが存在するかチェック
        if !characterRegistry.activeCharacterId.isEmpty,
           let activeCharacter = characterRegistry.getActiveCharacter() {
            
            // アクティブキャラクターが存在する場合、最新の状態に更新
            romanceViewModel.switchToCharacter(activeCharacter)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                romanceViewModel.forceRefreshCharacterIcon()
            }
        }
    }
    
    // 🔧 修正：アプリ初期化処理の改善
    private func initializeApp() {
        print("🚀 TopView: アプリ初期化開始")
        
        // 初期化フラグをチェック
        guard !hasInitialized else {
            print("⚠️ 既に初期化済みのため処理をスキップ")
            return
        }
        
        hasInitialized = true
        currentCharacterId = characterRegistry.activeCharacterId
        
        if let activeCharacter = characterRegistry.getActiveCharacter() {
            print("✅ 初期アクティブキャラクター: \(activeCharacter.name)")
            romanceViewModel.switchToCharacter(activeCharacter)
            
            // 初期化時も強制的にUI更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                romanceViewModel.forceRefreshCharacterIcon()
            }
        } else {
            print("ℹ️ アクティブキャラクターなし（新規ユーザーまたはキャラクター未作成）")
        }
        
        print("🚀 TopView: アプリ初期化完了")
    }
    
    // MARK: - View Components
    
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
    
    private var mainAppView: some View {
        TabView {
            ContentView(viewModel: romanceViewModel)
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("チャット")
                }
            
            DateSelectorView(viewModel: romanceViewModel)
                .tabItem {
                    Image(systemName: "heart.circle.fill")
                    Text("デート")
                }
            
            SettingsView(viewModel: romanceViewModel)
                .tabItem {
                    Image(systemName: "person.text.rectangle")
                    Text("推しの編集")
                }
        }
    }
    
    // 🔧 修正：デバッグ用メソッドを追加
    private func debugCurrentState() {
        print("\n🔍 ==================== TopView: 現在の状態 ====================")
        print("📊 CharacterRegistry状態:")
        print("   - 読み込み中: \(characterRegistry.isLoading)")
        print("   - キャラクター数: \(characterRegistry.characters.count)")
        print("   - アクティブキャラクターID: \(characterRegistry.activeCharacterId)")
        
        if let activeChar = characterRegistry.getActiveCharacter() {
            print("   - アクティブキャラクター名: \(activeChar.name)")
            print("   - アイコンURL: \(activeChar.iconURL ?? "なし")")
        }
        
        print("📊 RomanceViewModel状態:")
        print("   - キャラクター名: \(romanceViewModel.character.name)")
        print("   - キャラクターID: \(romanceViewModel.character.id)")
        print("   - アイコンURL: \(romanceViewModel.character.iconURL ?? "なし")")
        print("   - 認証状態: \(romanceViewModel.isAuthenticated)")
        
        print("📊 TopView状態:")
        print("   - 初期化済み: \(hasInitialized)")
        print("   - 現在のキャラクターID: \(currentCharacterId)")
        print("==================== 状態確認完了 ====================\n")
    }
}

#Preview {
    TopView()
}
