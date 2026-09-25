//
//  CharacterSelectorView.swift
//  osidate
//
//  Created by Apple on 2025/08/11.
//

import SwiftUI
import Foundation
import FirebaseDatabase
import FirebaseAuth

struct CharacterSelectorView: View {
    @ObservedObject var characterRegistry: CharacterRegistry
    @Binding var selectedCharacterId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingAddCharacter = false
    @State private var showingDeleteConfirmation = false
    @State private var characterToDelete: Character?
    @State private var searchText = ""
    @State private var showingSearchBar = false
    @State private var animationOffset: CGFloat = 50
    @State private var animationOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -100
    
    // 🌟 サブスクリプション関連の状態
    @State private var showingSubscriptionView = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // フィルタリングされたキャラクター
    private var filteredCharacters: [Character] {
        if searchText.isEmpty {
            return characterRegistry.characters
        } else {
            return characterRegistry.characters.filter { character in
                character.name.localizedCaseInsensitiveContains(searchText) ||
                character.personality.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
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
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [
                        backgroundColor,
                        primaryColor.opacity(0.03),
                        accentColor.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if characterRegistry.isLoading {
                     modernLoadingView
                 } else {
                     VStack(spacing: 0) {
                         // ヘッダーセクション
                         headerSection
                         
                         // 🌟 キャラクター制限表示セクション
                         characterLimitSection
                         
                         // 検索バー（条件付き表示）
                         if showingSearchBar {
                             searchSection
                                 .transition(.move(edge: .top).combined(with: .opacity))
                         }
                         
                         // メインコンテンツ
                         if filteredCharacters.isEmpty && searchText.isEmpty {
                             emptyStateView
                         } else if filteredCharacters.isEmpty && !searchText.isEmpty {
                             noSearchResultsView
                         } else {
                             characterGridView
                         }
                     }
                 }
             }
             .navigationTitle("")
             .navigationBarHidden(true)
             .sheet(isPresented: $showingAddCharacter) {
                 AddCharacterView(characterRegistry: characterRegistry)
             }
             // 🌟 サブスクリプション画面
             .sheet(isPresented: $showingSubscriptionView) {
                 SubscriptionView(source: .characterLimit)
             }
             // 🌟 制限アラート
             .alert("キャラクター数制限", isPresented: $characterRegistry.showingCharacterLimitAlert) {
                 Button("プレミアムプラン") {
                     showingSubscriptionView = true
                 }
                 Button("キャンセル", role: .cancel) { }
             } message: {
                 Text("無料版では\(characterRegistry.getCharacterLimitInfo().maxCount ?? 0)人までしか推しを登録できません。プレミアムプランで無制限に楽しめます！")
             }
             .alert("推しを削除", isPresented: $showingDeleteConfirmation) {
                 Button("削除", role: .destructive) {
                     if let character = characterToDelete {
                         withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                             characterRegistry.deleteCharacter(character)
                         }
                     }
                 }
                 Button("キャンセル", role: .cancel) { }
             } message: {
                 if let character = characterToDelete {
                     Text("「\(character.name)」を削除しますか？\nこの操作は取り消せません。")
                 }
             }
             .onAppear {
                 animateAppearance()
             }
         }
         .navigationViewStyle(StackNavigationViewStyle())
     }
    
    private var characterLimitSection: some View {
        let limitInfo = characterRegistry.getCharacterLimitInfo()
        
        return Group {
            if !limitInfo.isSubscribed && !limitInfo.isSpecialUser {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.blue)
                        
                        Text(limitInfo.displayText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("プレミアム") {
                            showingSubscriptionView = true
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    // 制限近づきの警告
                    if let warningText = limitInfo.warningText {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text(warningText)
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            } else if limitInfo.isSpecialUser {
                // 🌟 特別ユーザー向けの表示
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.gold)
                        
                        Text("特別アカウント: 無制限")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "infinity")
                            .font(.title3)
                            .foregroundColor(.gold)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.gold.opacity(0.1), Color.orange.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - ヘッダーセクション
    private var headerSection: some View {
        VStack(spacing: 20) {
            // タイトルと閉じるボタン
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("推しを選択")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("あなたの大切な推しを選んでください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // 検索ボタン
                    if !filteredCharacters.isEmpty || !searchText.isEmpty {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingSearchBar.toggle()
                                if !showingSearchBar {
                                    searchText = ""
                                }
                            }
                        }) {
                            Image(systemName: showingSearchBar ? "xmark" : "magnifyingglass")
                                .font(.title3)
                                .foregroundColor(showingSearchBar ? .red : primaryColor)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: animationOffset)
    }
    
    // MARK: - 検索セクション
    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("推しの名前や性格で検索...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .submitLabel(.search)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - モダンローディングビュー
    private var modernLoadingView: some View {
        VStack(spacing: 30) {
            // アニメーション付きアイコン
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.7), accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 20, height: 20)
                        .scaleEffect(shimmerOffset > 0 ? 1.2 : 0.8)
                        .opacity(shimmerOffset > 0 ? 0.8 : 0.4)
                        .offset(x: CGFloat(index - 1) * 40)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: shimmerOffset
                        )
                }
            }
            
            VStack(spacing: 12) {
                Text("推しを読み込み中...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("あなたの大切な推したちを準備しています")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                shimmerOffset = 100
            }
        }
    }
    
    // MARK: - 空の状態ビュー
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // イラスト風アイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor.opacity(0.1), accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(shimmerOffset > 0 ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: shimmerOffset)
                
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(primaryColor)
            }
            
            VStack(spacing: 16) {
                Text("まだ推しがいません")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // 🌟 修正: 分岐を関数に分離
                buttonAndTextContent
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            // フローティング追加ボタン
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingAddButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                }
            }
        )
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animationOffset)
    }

    // 🌟 修正: 条件分岐を別の computed property に分離
    private var buttonAndTextContent: some View {
        let limitInfo = characterRegistry.getCharacterLimitInfo()
        
        return Group {
            // テキスト表示
            Group {
                if limitInfo.isSpecialUser {
                    Text("特別アカウントなので\n無制限に推しを追加できます！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                } else if limitInfo.canCreateMore {
                    Text("右下の + ボタンから\n新しい推しを追加してみてください！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                } else {
                    Text("無料版では\(limitInfo.maxCount ?? 0)人まで。\nプレミアムプランで無制限に楽しめます！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            // CTA ボタン
            Group {
                if limitInfo.isSpecialUser {
                    createSpecialUserButton(limitInfo: limitInfo)
                } else if limitInfo.canCreateMore {
                    createStandardUserButton(limitInfo: limitInfo)
                } else {
                    createUpgradeButton(limitInfo: limitInfo)
                }
            }
        }
    }

    // 🌟 各ボタンを個別の関数に分離
    private func createSpecialUserButton(limitInfo: CharacterLimitInfo) -> some View {
        Button(action: {
            showingAddCharacter = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                Text("最初の推しを追加")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.gold, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: Color.gold.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .scaleEffect(shimmerOffset > 0 ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: shimmerOffset)
    }

    private func createStandardUserButton(limitInfo: CharacterLimitInfo) -> some View {
        Button(action: {
            showingAddCharacter = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("最初の推しを追加")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [primaryColor, accentColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: primaryColor.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .scaleEffect(shimmerOffset > 0 ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: shimmerOffset)
    }

    private func createUpgradeButton(limitInfo: CharacterLimitInfo) -> some View {
        Button(action: {
            showingSubscriptionView = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                Text("プレミアムプランで無制限に")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: Color.blue.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .scaleEffect(shimmerOffset > 0 ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: shimmerOffset)
    }
    
    // MARK: - 検索結果なしビュー
    private var noSearchResultsView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("見つかりませんでした")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("「\(searchText)」に一致する推しがいません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("検索をクリア") {
                    searchText = ""
                }
                .font(.subheadline)
                .foregroundColor(primaryColor)
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - キャラクターグリッドビュー
    private var characterGridView: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: 16), count: 3),
                spacing: 0
            ) {
                ForEach(Array(filteredCharacters.enumerated()), id: \.element.id) { index, character in
                    ModernCharacterCard(
                        character: character,
                        isSelected: character.id == selectedCharacterId,
                        onSelect: {
                            selectCharacter(character)
                        },
                        onDelete: {
                            characterToDelete = character
                            showingDeleteConfirmation = true
                        }
                    )
                    .offset(y: animationOffset)
                    .opacity(animationOpacity)
                    .padding(.top)
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.8)
                        .delay(0.4 + Double(index) * 0.1),
                        value: animationOffset
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // フローティングボタンのスペース
        }
        .overlay(
            // フローティング追加ボタン
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingAddButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                }
            }
        )
    }
    
    // MARK: - 修正されたフローティング追加ボタン
    private var floatingAddButton: some View {
        let limitInfo = characterRegistry.getCharacterLimitInfo()
        let canCreate = limitInfo.canCreateMore
        
        return Button(action: {
            if canCreate {
                showingAddCharacter = true
            } else {
                showingSubscriptionView = true
            }
        }) {
            ZStack {
                Circle()
                    .fill(
                        canCreate ?
                        LinearGradient(
                            colors: limitInfo.isSpecialUser ? [.gold, .orange] : [primaryColor, accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.gray.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: primaryColor.opacity(0.4), radius: 15, x: 0, y: 8)
                
                if canCreate {
                    Image(systemName: limitInfo.isSpecialUser ? "crown.fill" : "plus")
                        .font(.system(size: limitInfo.isSpecialUser ? 20 : 24, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .scaleEffect(shimmerOffset > 0 ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: shimmerOffset)
    }

    
    // MARK: - Helper Functions
    private func selectCharacter(_ character: Character) {
        print("🔄 キャラクター選択: \(character.name) (ID: \(character.id))")
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedCharacterId = character.id
            characterRegistry.setActiveCharacter(character.id)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
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
}

// MARK: - StatisticCard コンポーネント
//struct StatisticCard: View {
//    let title: String
//    let value: String
//    let icon: String
//    let color: Color
//    
//    var body: some View {
//        VStack(spacing: 8) {
//            Image(systemName: icon)
//                .font(.title2)
//                .foregroundColor(color)
//            
//            Text(value)
//                .font(.title3)
//                .fontWeight(.bold)
//                .foregroundColor(.primary)
//            
//            Text(title)
//                .font(.caption)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 12)
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
//    }
//}

struct ModernCharacterCard: View {
    let character: Character
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var iconImage: UIImage? = nil
    @State private var showDeleteButton = false
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                // メインカード
                VStack(spacing: 16) {
                    // キャラクターアイコン
                    characterIconView
                    
                    // キャラクター情報
                    characterInfoView
                    
                    // 親密度情報
                    intimacyInfoView
                    
                    // 選択状態インジケーター
//                    if isSelected {
//                        selectedIndicator
//                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected
                                    ? LinearGradient(
                                        colors: [character.intimacyStage.color, character.intimacyStage.color.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 3
                                )
                        )
                        .shadow(
                            color: isSelected ? character.intimacyStage.color.opacity(0.3) : Color.black.opacity(0.1),
                            radius: isSelected ? 15 : 8,
                            x: 0,
                            y: isSelected ? 8 : 4
                        )
                )
                
                // 削除ボタン
                if showDeleteButton {
                    VStack {
                        HStack {
                            Spacer()
                            deleteButton
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            onSelect()
        }
        .onLongPressGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showDeleteButton.toggle()
            }
        }
        .onAppear {
            loadCharacterIcon()
        }
        .id(character.id)
    }
    
    private var characterIconView: some View {
        ZStack {
            Circle()
                .fill(character.intimacyStage.color.opacity(0.1))
                .frame(width: 70, height: 70)
            
            if let iconImage = iconImage {
                Image(uiImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else if let iconURL = character.iconURL,
                      !iconURL.isEmpty,
                      let url = URL(string: iconURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
            } else {
                Image(systemName: character.iconName)
                    .font(.system(size: 35))
                    .foregroundColor(character.intimacyStage.color)
            }
            
            if isSelected {
                Circle()
                    .stroke(character.intimacyStage.color, lineWidth: 3)
                    .frame(width: 70, height: 70)
            }
        }
    }
    
    private var characterInfoView: some View {
        VStack(spacing: 6) {
            Text(character.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
    
    private var intimacyInfoView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                    VStack {
                        Text("親密度")
                        Text("\(character.intimacyLevel)")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(character.intimacyStage.color)
            }
            
            Text(character.intimacyTitle)
                .font(.caption2)
                .foregroundColor(character.intimacyStage.color)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
    
    private var selectedIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(character.intimacyStage.color)
            
            Text("選択中")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(character.intimacyStage.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(character.intimacyStage.color.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var deleteButton: some View {
        Button(action: onDelete) {
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: 32, height: 32)
                    .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private func loadCharacterIcon() {
        guard let iconURL = character.iconURL,
              !iconURL.isEmpty,
              let url = URL(string: iconURL) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    self.iconImage = UIImage(data: data)
                }
            } catch {
                print("キャラクターアイコン読み込みエラー: \(error.localizedDescription)")
            }
        }
    }
}

struct CharacterCardView: View {
    let character: Character
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var iconImage: UIImage? = nil
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                // Character Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? .blue.opacity(0.2) : .gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    // 🔧 修正：アイコン表示の改善
                    if let iconImage = iconImage {
                        Image(uiImage: iconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    } else if let iconURL = character.iconURL,
                              !iconURL.isEmpty,
                              let url = URL(string: iconURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                                .onAppear {
                                    // 読み込み成功時にローカル状態も更新
                                    loadImageToState(from: url)
                                }
                        } placeholder: {
                            Circle()
                                .fill(.gray.opacity(0.3))
                                .frame(width: 70, height: 70)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        }
                    } else {
                        Image(systemName: character.iconName)
                            .font(.system(size: 35))
                            .foregroundColor(isSelected ? .blue : .primary)
                    }
                    
                    if isSelected {
                        Circle()
                            .stroke(.blue, lineWidth: 3)
                            .frame(width: 80, height: 80)
                    }
                }
                
                // Character Info
                VStack(spacing: 4) {
                    Text(character.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Lv.\(character.intimacyLevel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(character.intimacyTitle)
                        .font(.caption2)
                        .foregroundColor(character.intimacyStage.color)
                        .lineLimit(1)
                }
                
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("選択中")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .overlay(
                // Delete button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                                .background(Circle().fill(.white))
                        }
                        .offset(x: 8, y: -8)
                    }
                    Spacer()
                }
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            // タップ時のフィードバック
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            onSelect()
        }
        .onAppear {
            // アイコン画像をローカル状態に読み込み
            if let iconURL = character.iconURL,
               !iconURL.isEmpty,
               let url = URL(string: iconURL) {
                loadImageToState(from: url)
            }
        }
        .id(character.id) // キャラクターIDでViewを一意化
    }
    
    // 🔧 修正：画像をローカル状態に読み込む
    private func loadImageToState(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    self.iconImage = UIImage(data: data)
                }
            } catch {
                print("CharacterCardView: アイコン読み込みエラー - \(error.localizedDescription)")
            }
        }
    }
}

//
//  Fixed AddCharacterView.swift
//  osidate
//
//  アイコンアップロード機能付きの推し追加画面（weak selfエラー修正版）
//

import SwiftUI
import SwiftyCrop

struct AddCharacterView: View {
    @ObservedObject var characterRegistry: CharacterRegistry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name = ""
    @State private var personality = ""
    @State private var speakingStyle = ""
    @State private var isCreating = false
    @State private var currentStep = 0
    @State private var animationOffset: CGFloat = 50
    @State private var animationOpacity: Double = 0
    @FocusState private var isInputFocused: Bool
    
    // 🌟 アイコン画像関連の状態
    @StateObject private var imageManager = ImageStorageManager()
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var characterIcon: UIImage?
    @State private var selectedImageForCropping: UIImage?
    @State private var croppingItem: CroppingItem?
    @State private var iconUploadURL: String?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // アイコンアニメーション用の状態
    @State private var iconScale: CGFloat = 1.0
    @State private var deleteButtonScale: CGFloat = 1.0
    
    @State private var showingSubscriptionView = false
    @State private var showingLimitAlert = false
    
    private struct CroppingItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    private let steps = ["基本情報", "アイコン", "性格設定", "話し方設定"]
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: return true // アイコンは任意なので常にOK
        case 2: return !personality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3: return !speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return false
        }
    }
    
    private var isFormComplete: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !personality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
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
    
    // SwiftyCrop設定
    private var cropConfig: SwiftyCropConfiguration {
        var cfg = SwiftyCropConfiguration(
            texts: .init(
                cancelButton: "キャンセル",
                interactionInstructions: "",
                saveButton: "適用"
            )
        )
        return cfg
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [
                        backgroundColor,
                        primaryColor.opacity(0.03),
                        accentColor.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isCreating {
                    creatingView
                } else {
                    VStack(spacing: 0) {
                        // ヘッダー
                        headerView
                        
                        // プログレスインジケーター
                        progressIndicatorView
                        
                        // ステップコンテンツ
                        stepContentView
                        
                        Spacer()
                        
                        // ナビゲーションボタン
                        navigationButtonsView
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView { pickedImage in
                    self.selectedImageForCropping = pickedImage
                }
            }
            .onChange(of: selectedImageForCropping) { img in
                guard let img else { return }
                guard croppingItem == nil else { return }
                croppingItem = CroppingItem(image: img)
            }
            .fullScreenCover(item: $croppingItem) { item in
                NavigationView {
                    SwiftyCropView(
                        imageToCrop: item.image,
                        maskShape: .circle,
                        configuration: cropConfig
                    ) { cropped in
                        if let cropped {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                selectedImage = cropped
                                characterIcon = cropped
                            }
                            uploadIconImage()
                        }
                        croppingItem = nil
                    }
                    .drawingGroup()
                }
                .navigationBarHidden(true)
            }
            .alert("通知", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                animateAppearance()
            }
            .onTapGesture {
                isInputFocused = false
            }
        }
    }
    
    // MARK: - ヘッダービュー
    private var headerView: some View {
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
                Text("新しい推しを追加")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("ステップ \(currentStep + 1) / \(steps.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: animationOffset)
    }
    
    // MARK: - プログレスインジケーター
    private var progressIndicatorView: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 8) {
                    // ステップサークル
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? primaryColor : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                        
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else if index == currentStep {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // ステップタイトル
                    Text(steps[index])
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(index <= currentStep ? primaryColor : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                
                // 接続線
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? primaryColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animationOffset)
    }
    
    // MARK: - ステップコンテンツビュー
    private var stepContentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                switch currentStep {
                case 0:
                    nameStepView
                case 1:
                    iconStepView // 🌟 新しいアイコン設定ステップ
                case 2:
                    personalityStepView
                case 3:
                    speakingStyleStepView
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
        }
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animationOffset)
    }
    
    // MARK: - ステップ1: 名前入力
    private var nameStepView: some View {
        VStack(spacing: 24) {
            // アイコン
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(primaryColor)
            }
            
            VStack(spacing: 16) {
                Text("推しの名前を教えてください")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("あなたの大切な推しの名前を入力してください。\nいつでも変更可能です。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // 名前入力フィールド
            VStack(alignment: .leading, spacing: 8) {
                Text("名前")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                TextField("推しの名前を入力", text: $name)
                    .textFieldStyle(ModernTextFieldStyle())
                    .focused($isInputFocused)
                    .submitLabel(.next)
                    .onSubmit {
                        if isCurrentStepValid {
                            nextStep()
                        }
                    }
                
                if !name.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("素敵な名前ですね！")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // 提案例
            suggestionSection(
                title: "人気の名前例",
                suggestions: ["あかり", "みお", "ひなた", "さくら", "ゆい", "りお"],
                onSelect: { suggestion in
                    name = suggestion
                }
            )
        }
    }
    
    // MARK: - 🌟 ステップ2: アイコン設定
    private var iconStepView: some View {
        VStack(spacing: 24) {
            // アイコン
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(accentColor)
            }
            
            VStack(spacing: 16) {
                Text("\(name.isEmpty ? "推し" : name)のアイコンを設定しましょう")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("お気に入りの写真を設定できます。\n後からでも変更可能です。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // メインアイコンセクション
            VStack(spacing: 20) {
                ZStack {
                    // メインのアイコンボタン
                    Button(action: {
                        generateHapticFeedback()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            iconScale = 0.95
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                iconScale = 1.0
                            }
                        }
                        showingImagePicker = true
                    }) {
                        ZStack {
                            if let icon = characterIcon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 180, height: 180)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [primaryColor, accentColor],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 4
                                            )
                                    )
                                    .shadow(color: primaryColor.opacity(0.3), radius: 15, x: 0, y: 8)
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 180, height: 180)
                                    .overlay(
                                        VStack(spacing: 12) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 50, weight: .light))
                                                .foregroundColor(primaryColor.opacity(0.7))
                                            
                                            VStack(spacing: 4) {
                                                Text("画像を選択")
                                                    .font(.headline)
                                                    .fontWeight(.medium)
                                                Text("タップしてください")
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.secondary)
                                        }
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            }
                            
                            // アップロード中のオーバーレイ
                            if imageManager.isUploading {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 180, height: 180)
                                    .overlay(
                                        VStack(spacing: 15) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
                                                .scaleEffect(1.5)
                                            
                                            VStack(spacing: 2) {
                                                Text("アップロード中")
                                                    .font(.headline)
                                                    .fontWeight(.medium)
                                                Text("\(Int(imageManager.uploadProgress * 100))%")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .foregroundColor(primaryColor)
                                        }
                                    )
                            }
                        }
                    }
                    .scaleEffect(iconScale)
                    .disabled(imageManager.isUploading)
                    
                    // 削除ボタン（アイコンがある場合のみ表示）
                    if characterIcon != nil && !imageManager.isUploading {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    generateHapticFeedback()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        deleteButtonScale = 0.8
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            deleteButtonScale = 1.0
                                        }
                                    }
                                    deleteCurrentIcon()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 36, height: 36)
                                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                        
                                        Image(systemName: "xmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.red)
                                    }
                                }
                                .scaleEffect(deleteButtonScale)
                                .offset(x: 15, y: -15)
                            }
                            Spacer()
                        }
                        .frame(width: 180, height: 180)
                    }
                }
                
                // 状態表示テキスト
                Group {
                    if imageManager.isUploading {
                        HStack(spacing: 8) {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(primaryColor)
                            Text("画像をアップロード中...")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(primaryColor.opacity(0.1))
                        .cornerRadius(20)
                        
                    } else if selectedImage != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("画像が設定されました")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.1))
                        .cornerRadius(20)
                        
                    } else if characterIcon != nil {
                        Text("タップして画像を変更")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("画像を選択すると、より愛着が湧きますよ✨")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: imageManager.isUploading)
                .animation(.easeInOut(duration: 0.3), value: selectedImage)
            }
            
            // 使用方法カード
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(accentColor)
                    Text("使用方法")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    instructionRow(icon: "hand.tap.fill", text: "円形のアイコンエリアをタップして画像を選択")
                    instructionRow(icon: "crop", text: "選択後、画像をクロップして調整できます")
                    instructionRow(icon: "icloud.and.arrow.up.fill", text: "クロップ完了後、自動的にアップロードされます")
                    instructionRow(icon: "xmark.circle.fill", text: "右上のバツマークでアイコンを削除できます")
                    instructionRow(icon: "square.fill", text: "正方形の画像が推奨されます")
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - ステップ3: 性格設定（元のステップ2）
    private var personalityStepView: some View {
        VStack(spacing: 24) {
            // アイコン
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 16) {
                Text("\(name.isEmpty ? "推し" : name)の性格を教えてください")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("どんな性格の推しですか？\n詳しく教えてください。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // 性格入力フィールド
            VStack(alignment: .leading, spacing: 8) {
                Text("性格")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                ZStack(alignment: .topLeading) {
                    if personality.isEmpty {
                        Text("例：優しくて思いやりがある。いつも明るくて、周りの人を笑顔にしてくれる...")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $personality)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(personality.isEmpty ? Color(.systemGray4) : primaryColor, lineWidth: 1)
                        )
                        .focused($isInputFocused)
                }
                
                // 文字数カウンター
                HStack {
                    Spacer()
                    Text("\(personality.count)/500")
                        .font(.caption)
                        .foregroundColor(personality.count > 500 ? .red : .secondary)
                }
            }
            
            // 提案例
            suggestionSection(
                title: "性格の例",
                suggestions: ["優しい", "明るい", "クール", "天然", "しっかり者", "甘えん坊"],
                onSelect: { suggestion in
                    if personality.isEmpty {
                        personality = suggestion + "で、"
                    } else {
                        personality += suggestion + "で、"
                    }
                }
            )
        }
    }
    
    // MARK: - ステップ4: 話し方設定（元のステップ3）
    private var speakingStyleStepView: some View {
        VStack(spacing: 24) {
            // アイコン
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 16) {
                Text("\(name.isEmpty ? "推し" : name)の話し方を教えてください")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("どんな風に話す推しですか？\n会話のスタイルを設定してください。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // 話し方入力フィールド
            VStack(alignment: .leading, spacing: 8) {
                Text("話し方")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                ZStack(alignment: .topLeading) {
                    if speakingStyle.isEmpty {
                        Text("例：丁寧で温かい話し方をする。時々関西弁が出ることもある...")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $speakingStyle)
                        .font(.body)
                        .frame(minHeight: 120)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(speakingStyle.isEmpty ? Color(.systemGray4) : primaryColor, lineWidth: 1)
                        )
                        .focused($isInputFocused)
                }
                
                // 文字数カウンター
                HStack {
                    Spacer()
                    Text("\(speakingStyle.count)/500")
                        .font(.caption)
                        .foregroundColor(speakingStyle.count > 500 ? .red : .secondary)
                }
            }
            
            // 提案例
            suggestionSection(
                title: "話し方の例",
                suggestions: ["丁寧語", "タメ口", "関西弁", "方言", "クール", "フレンドリー"],
                onSelect: { suggestion in
                    if speakingStyle.isEmpty {
                        speakingStyle = suggestion + "で話し、"
                    } else {
                        speakingStyle += suggestion + "で話し、"
                    }
                }
            )
        }
    }
    
    // MARK: - 提案セクション
    private func suggestionSection(title: String, suggestions: [String], onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: {
                        onSelect(suggestion)
                    }) {
                        Text(suggestion)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(primaryColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(primaryColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - 説明行ヘルパー
    @ViewBuilder
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
    }
    
    // MARK: - ナビゲーションボタン
    private var navigationButtonsView: some View {
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
            Button(action: {
                if currentStep < steps.count - 1 {
                    nextStep()
                } else {
                    createCharacter()
                }
            }) {
                HStack(spacing: 8) {
                    Text(currentStep < steps.count - 1 ? "次へ" : "完了")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if currentStep < steps.count - 1 {
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
                    isCurrentStepValid
                    ? LinearGradient(
                        colors: [primaryColor, accentColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .shadow(
                    color: isCurrentStepValid ? primaryColor.opacity(0.3) : Color.clear,
                    radius: isCurrentStepValid ? 8 : 0,
                    x: 0,
                    y: 4
                )
            }
            .disabled(!isCurrentStepValid)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: animationOffset)
    }
    
    // MARK: - 作成中ビュー
    private var creatingView: some View {
        VStack(spacing: 30) {
            // アニメーション付きアイコン
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animationOpacity)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animationOpacity)
                
                if let icon = characterIcon {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(primaryColor)
                }
            }
            
            VStack(spacing: 16) {
                Text("\(name)を作成中...")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("あなたの新しい推しを準備しています")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if imageManager.isUploading {
                    VStack(spacing: 8) {
                        Text("アイコンをアップロード中...")
                            .font(.caption)
                            .foregroundColor(primaryColor)
                        
                        ProgressView(value: imageManager.uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: primaryColor))
                            .frame(width: 200)
                    }
                } else {
                    // プログレスバー
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(primaryColor)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    private func nextStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = min(currentStep + 1, steps.count - 1)
        }
        isInputFocused = false
    }
    
    private func previousStep() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = max(currentStep - 1, 0)
        }
        isInputFocused = false
    }
    
    private func createCharacter() {
        guard isFormComplete else { return }
        
        print("🎭 キャラクター作成開始")
        
        // 🌟 事前にキャラクター数制限をチェック
        let limitInfo = characterRegistry.getCharacterLimitInfo()
        if !limitInfo.canCreateMore {
            print("❌ キャラクター数制限により作成をブロック")
            showingLimitAlert = true
            return
        }
        
        isCreating = true
        
        // アイコンアップロードが完了していない場合は待機
        if imageManager.isUploading {
            waitForUploadCompletionAndCreateCharacter()
        } else {
            performCharacterCreation()
        }
    }
    
    private func waitForUploadCompletionAndCreateCharacter() {
        // アップロード状態を監視
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if !imageManager.isUploading {
                timer.invalidate()
                performCharacterCreation()
            }
        }
    }
    
    private func performCharacterCreation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 🌟 createNewCharacterの戻り値をチェック
            guard let newCharacter = characterRegistry.createNewCharacter(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                personality: personality.trimmingCharacters(in: .whitespacesAndNewlines),
                speakingStyle: speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines)
            ) else {
                print("❌ キャラクター作成失敗 - 制限に達している可能性")
                isCreating = false
                // 制限アラートは CharacterRegistry 側で表示されるのでここでは何もしない
                return
            }
            
            print("✅ キャラクター作成成功: \(newCharacter.name)")
            
            // アイコンURLが設定されている場合は適用
            if let iconURL = iconUploadURL {
                newCharacter.iconURL = iconURL
                characterRegistry.updateCharacter(newCharacter)
            }
            
            characterRegistry.setActiveCharacter(newCharacter.id)
            
            isCreating = false
            dismiss()
        }
    }
    
    private func animateAppearance() {
        animationOffset = 50
        animationOpacity = 0
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            animationOffset = 0
            animationOpacity = 1
        }
    }
    
    // MARK: - 🌟 アイコンアップロード関連メソッド（修正版）
    
    private func uploadIconImage() {
        guard let image = selectedImage else {
            DispatchQueue.main.async {
                alertMessage = "画像のアップロードに失敗しました"
                showingAlert = true
            }
            return
        }
        
        // 仮のユーザーIDを生成（実際のアプリではFirebase認証のUIDを使用）
        let ownerId = Auth.auth().currentUser?.uid ?? UUID().uuidString
        let imagePath = "character_icons/\(ownerId)_\(UUID().uuidString)_\(Date().timeIntervalSince1970).jpg"
        
        // 🔧 修正: weak selfを削除し、直接Binding経由で状態を更新
        imageManager.uploadImage(image, path: imagePath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let downloadURL):
                    iconUploadURL = downloadURL
                    characterIcon = image
                    selectedImage = nil
                    
                    alertMessage = "アイコンが正常にアップロードされました"
                    showingAlert = true
                    
                case .failure(let error):
                    alertMessage = "アップロードエラー: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func deleteCurrentIcon() {
        guard let iconURL = iconUploadURL,
              !iconURL.isEmpty,
              let imagePath = extractPathFromURL(iconURL) else {
            
            // ローカルアイコンのみを削除
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                characterIcon = nil
                selectedImage = nil
                iconUploadURL = nil
            }
            return
        }
        
        // 🔧 修正: weak selfを削除し、直接Binding経由で状態を更新
        imageManager.deleteImage(at: imagePath) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        characterIcon = nil
                        selectedImage = nil
                        iconUploadURL = nil
                    }
                    
                    alertMessage = "アイコンが削除されました"
                    showingAlert = true
                    
                case .failure(let error):
                    alertMessage = "削除エラー: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func extractPathFromURL(_ url: String) -> String? {
        guard let urlComponents = URLComponents(string: url),
              let path = urlComponents.path.components(separatedBy: "/o/").last?.components(separatedBy: "?").first else {
            return nil
        }
        return path.removingPercentEncoding
    }
    
    private func generateHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - ModernTextFieldStyle

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

// MARK: - ImagePickerView

struct ImagePickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CharacterSelectorView(
        characterRegistry: CharacterRegistry(),
        selectedCharacterId: .constant("")
    )
}
