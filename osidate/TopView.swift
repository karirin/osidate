//
//  TopView.swift - デートセレクタ統合修正版
//  osidate
//

import SwiftUI
import Firebase
import FirebaseAuth

struct TopView: View {
    @State private var selectedOshiId: String = "default"
    @State private var showWelcomeScreen = false
    @State private var oshiChange: Bool = false
    @State private var showAddOshiFlag = false
    
    @State private var hasLoadedProfileImages = false
    @State private var cachedImageURLs: [String: String] = [:]
    @State private var initialLoadCompleted = false
    @State private var observerHandle: DatabaseHandle?
    
    // 🔧 修正：共通のViewModelを使用
    @StateObject private var romanceViewModel = RomanceAppViewModel()
    
    var body: some View {
        ZStack {
            TabView {
                // メインチャットタブ
                HStack {
                    ContentView(viewModel: romanceViewModel)
                }
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .padding()
                    Text("チャット")
                        .padding()
                }
                
                // デートセレクタータブ
                ZStack {
                    DateSelectorView(viewModel: romanceViewModel)
                }
                .tabItem {
                    Image(systemName: "heart.circle.fill")
                        .frame(width:1,height:1)
                    Text("デート")
                }
                
                // 設定タブ
                ZStack {
                    SettingsView(viewModel: romanceViewModel)
                }
                .tabItem {
                    Image(systemName: "person.text.rectangle")
                        .frame(width:1,height:1)
                    Text("推しの編集")
                }
            }
        }
        .onAppear {
            if !initialLoadCompleted {
                initialLoadCompleted = true
                
                if !UserDefaults.standard.bool(forKey: "appLaunchedBefore") {
                    UserDefaults.standard.set(false, forKey: "tutorialCompleted")
                    UserDefaults.standard.set(true, forKey: "appLaunchedBefore")
                }
            }
        }
    }
}

#Preview {
    TopView()
}
