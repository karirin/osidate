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
        .padding(.bottom, 16)
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
                
                Text("右下の + ボタンから\n新しい推しを追加してみてください！")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                // CTA ボタン
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
            
            Spacer()
            
            // 追加ボタン（フローティング）
            floatingAddButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animationOffset)
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
                spacing: 20
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
                    .padding(.top, 5)
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
    
    // MARK: - フローティング追加ボタン
    private var floatingAddButton: some View {
        Button(action: {
            showingAddCharacter = true
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: primaryColor.opacity(0.4), radius: 15, x: 0, y: 8)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
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

struct StatisticCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

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

// MARK: - Add Character View
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
    
    private let steps = ["基本情報", "性格設定", "話し方設定"]
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: return !personality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: return !speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    personalityStepView
                case 2:
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
    
    // MARK: - ステップ2: 性格設定
    private var personalityStepView: some View {
        VStack(spacing: 24) {
            // アイコン
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 40))
                    .foregroundColor(accentColor)
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
    
    // MARK: - ステップ3: 話し方設定
    private var speakingStyleStepView: some View {
        VStack(spacing: 24) {
            // アイコン
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
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
                
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(primaryColor)
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
                
                // プログレスバー
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(primaryColor)
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
        
        isCreating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let newCharacter = characterRegistry.createNewCharacter(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                personality: personality.trimmingCharacters(in: .whitespacesAndNewlines),
                speakingStyle: speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
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
}

#Preview {
    CharacterSelectorView(
        characterRegistry: CharacterRegistry(),
        selectedCharacterId: .constant("")
    )
}
