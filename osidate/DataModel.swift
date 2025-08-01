//
//  DataModel.swift
//  osidate
//
//  Updated for Firebase integration with image support
//

import SwiftUI
import Foundation

// MARK: - データモデル
struct Character: Codable, Identifiable {
    let id = UUID()
    var name: String
    var personality: String
    var speakingStyle: String
    var iconName: String
    var iconURL: String? // 新規追加：アップロードされた画像のURL
    var backgroundName: String
    var intimacyLevel: Int = 0
    var birthday: Date?
    var anniversaryDate: Date?
    
    var intimacyTitle: String {
        switch intimacyLevel {
        case 0...10: return "知り合い"
        case 11...30: return "友達"
        case 31...60: return "親友"
        case 61...100: return "恋人"
        default: return "運命の人"
        }
    }
    
    // アイコンが設定されているかどうか
    var hasCustomIcon: Bool {
        return iconURL != nil && !iconURL!.isEmpty
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    let text: String
    let isFromUser: Bool
    let timestamp: Date
    let dateLocation: String?
    
    init(text: String, isFromUser: Bool, timestamp: Date, dateLocation: String?) {
        self.id = UUID()
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.dateLocation = dateLocation
    }
    
    init(id: UUID, text: String, isFromUser: Bool, timestamp: Date, dateLocation: String?) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.dateLocation = dateLocation
    }
}

struct DateLocation: Identifiable {
    let id = UUID()
    let name: String
    let backgroundImage: String
    let requiredIntimacy: Int
    let description: String
}

// MARK: - カスタムアイコン表示用のView

struct CharacterIconView: View {
    let character: Character
    let size: CGFloat
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
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
        .onChange(of: character.iconURL) { _ in
            loadImageIfNeeded()
        }
    }
    
    private func loadImageIfNeeded() {
        guard let iconURL = character.iconURL,
              !iconURL.isEmpty,
              loadedImage == nil else { return }
        
        isLoading = true
        
        guard let url = URL(string: iconURL) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data, let image = UIImage(data: data) {
                    loadedImage = image
                }
            }
        }.resume()
    }
}
