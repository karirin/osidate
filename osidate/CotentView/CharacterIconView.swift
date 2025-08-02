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
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var currentIconURL: String? = nil
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                // デフォルトアイコン
                Circle()
                    .fill(Color.brown)
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: character.iconName)
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.white)
                    )
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: character.iconURL) { newIconURL in
            // URLが変更された場合、古い画像をクリアして新しい画像を読み込む
            print("CharacterIconView: アイコンURL変更検知 - \(newIconURL ?? "nil")")
            currentIconURL = newIconURL
            loadedImage = nil
            loadImageIfNeeded()
        }
        // 追加: idを使用して強制的に再描画
        .id(character.iconURL ?? "default")
    }
    
    private func loadImageIfNeeded() {
        // iconURLがない場合は何もしない
        guard let iconURL = character.iconURL,
              !iconURL.isEmpty else {
            print("CharacterIconView: アイコンURLが空 - デフォルトアイコンを表示")
            isLoading = false
            loadedImage = nil
            return
        }
        
        // 既に同じURLの画像を読み込んでいる場合はスキップ
        if currentIconURL == iconURL && loadedImage != nil {
            print("CharacterIconView: 同じURL - スキップ")
            return
        }
        
        currentIconURL = iconURL
        isLoading = true
        loadedImage = nil
        
        guard let url = URL(string: iconURL) else {
            print("CharacterIconView: 無効なURL - \(iconURL)")
            isLoading = false
            return
        }
        
        print("CharacterIconView: アイコン画像を読み込み中 - \(iconURL)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("CharacterIconView: アイコン画像の読み込みエラー - \(error.localizedDescription)")
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    print("CharacterIconView: アイコン画像の読み込み成功")
                    // 現在のURLと一致する場合のみ更新
                    if iconURL == currentIconURL {
                        loadedImage = image
                    }
                } else {
                    print("CharacterIconView: アイコン画像データの変換に失敗")
                }
            }
        }.resume()
    }
}
