//
//  TopView.swift - デートセレクタ統合修正版
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
                    ContentView(viewModel: romanceViewModel, characterRegistry: characterRegistry)
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
        }
        .onChange(of: characterRegistry.activeCharacterId) { newCharacterId in
            currentCharacterId = newCharacterId
            if let activeCharacter = characterRegistry.getActiveCharacter() {
                romanceViewModel.switchToCharacter(activeCharacter)
            }
        }
        .onAppear {
            currentCharacterId = characterRegistry.activeCharacterId
            if let activeCharacter = characterRegistry.getActiveCharacter() {
                romanceViewModel.switchToCharacter(activeCharacter)
            }
        }
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
            ContentView(viewModel: romanceViewModel, characterRegistry: characterRegistry)
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
}

#Preview {
    TopView()
}
