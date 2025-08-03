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
//    @State private var loadedImage: UIImage?
//    @State private var isLoading = false
//    @State private var currentIconURL: String? = nil
    
    var body: some View {
        ZStack{
            if let urlString = character.iconURL,
               let url = URL(string: urlString),
               !urlString.isEmpty {
                
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                        
                    case .failure(_):
                        defaultIcon   // 読み込み失敗時
                        
                    case .empty:
                        Circle()      // 読み込み中
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: size, height: size)
                            .overlay(ProgressView().scaleEffect(0.8))
                        
                    @unknown default:
                        defaultIcon
                    }
                }
                .id(urlString)
                
            } else {
                defaultIcon           // iconURL が無いとき
            }
        }
        .onAppear{
            print("character.iconURL    :\(character.iconURL ?? "nil")")
        }
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
    
    private func loadImageIfNeeded() {
        // iconURLがない場合は何もしない
        print("character.iconURL: \(character.iconURL)")
        guard let iconURL = character.iconURL,
              !iconURL.isEmpty else {
            print("CharacterIconView: アイコンURLが空 - デフォルトアイコンを表示")
            return
        }
        
        print("CharacterIconView: アイコン画像を読み込み中 - \(iconURL)")
    }
}
