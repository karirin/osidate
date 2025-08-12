//
//  CharacterIconView.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI

struct CharacterIconView: View {
    let character: Character
    let size: CGFloat
    let enableFloating: Bool // 🌟 新規追加：アニメーション制御パラメータ

    @State private var isFloating = false
    @State private var iconImage: UIImage? = nil
    @State private var isLoading = false
    
    // デフォルトでアニメーションを有効にするイニシャライザ
    init(character: Character, size: CGFloat, enableFloating: Bool = true) {
        self.character = character
        self.size = size
        self.enableFloating = enableFloating
    }
    
    var body: some View {
        ZStack {
            if let iconImage = iconImage {
                // カスタムアイコン画像を表示
                Image(uiImage: iconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .offset(y: enableFloating && isFloating ? -8 : enableFloating ? 8 : 0) // 🌟 アニメーション制御
                    .animation(
                        enableFloating ? .easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true) : .none, // 🌟 アニメーション制御
                        value: isFloating
                    )
                    .onAppear {
                        if enableFloating {
                            withAnimation(.easeInOut(duration: 2.5)
                                            .repeatForever(autoreverses: true)) {
                                isFloating = true
                            }
                        }
                    }
            } else if isLoading {
                // ローディング中
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                // デフォルトアイコン
                defaultIcon
                    .offset(y: enableFloating && isFloating ? -8 : enableFloating ? 8 : 0) // 🌟 アニメーション制御
                    .animation(
                        enableFloating ? .easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true) : .none, // 🌟 アニメーション制御
                        value: isFloating
                    )
                    .onAppear {
                        if enableFloating {
                            withAnimation(.easeInOut(duration: 2.5)
                                            .repeatForever(autoreverses: true)) {
                                isFloating = true
                            }
                        }
                    }
            }
        }
        .onAppear {
            loadIconIfNeeded()
        }
        .onChange(of: character.iconURL) { newIconURL in
            // アイコンURLが変更された時に再読み込み
            loadIconIfNeeded()
        }
        .onChange(of: character.id) { newCharacterId in
            // キャラクターIDが変更された時に再読み込み
            iconImage = nil
            loadIconIfNeeded()
        }
        .id("\(character.id)_\(character.iconURL ?? "default")") // 一意のIDを生成
    }
    
    private var defaultIcon: some View {
        Circle()
            .fill(Color.brown)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: character.iconName)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.white)
            )
    }
    
    private func loadIconIfNeeded() {
        // アイコンURLがない、または空の場合はデフォルトアイコンを使用
        guard let iconURL = character.iconURL,
              !iconURL.isEmpty,
              let url = URL(string: iconURL) else {
            print("CharacterIconView: アイコンURLが空またはキャラクターが無効 - デフォルトアイコンを表示")
            iconImage = nil
            return
        }
        
        // 既に同じURLの画像を読み込み済みの場合はスキップ
        if iconImage != nil && character.iconURL == iconURL {
            return
        }
        
        print("CharacterIconView: アイコン画像を読み込み中 - \(iconURL)")
        isLoading = true
        
        // 非同期でアイコンを読み込み
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
    ContentView(viewModel: RomanceAppViewModel())
}
