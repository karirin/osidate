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
            if newIconURL != currentIconURL {
                currentIconURL = newIconURL
                loadedImage = nil
                loadImageIfNeeded()
            }
        }
    }
    
    private func loadImageIfNeeded() {
        // iconURLがない場合は何もしない
        guard let iconURL = character.iconURL,
              !iconURL.isEmpty else {
            isLoading = false
            loadedImage = nil
            return
        }
        
        // 既に同じURLの画像を読み込んでいる場合はスキップ
        if currentIconURL == iconURL && loadedImage != nil {
            return
        }
        
        currentIconURL = iconURL
        isLoading = true
        loadedImage = nil
        
        guard let url = URL(string: iconURL) else {
            isLoading = false
            return
        }
        
        print("アイコン画像を読み込み中: \(iconURL)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("アイコン画像の読み込みエラー: \(error.localizedDescription)")
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    print("アイコン画像の読み込み成功")
                    loadedImage = image
                } else {
                    print("アイコン画像データの変換に失敗")
                }
            }
        }.resume()
    }
}
