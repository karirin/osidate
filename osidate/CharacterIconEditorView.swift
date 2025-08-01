//
//  CharacterIconEditorView.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI

struct CharacterIconEditorView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @StateObject private var imageManager = ImageStorageManager()
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var characterIcon: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 現在のアイコン表示
                VStack(spacing: 15) {
                    Text("キャラクターアイコン")
                        .font(.headline)
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        ZStack {
                            if let icon = characterIcon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 3)
                                    )
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("タップして画像を選択")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                            
                            // アップロード中のオーバーレイ
                            if imageManager.isUploading {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        VStack {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            Text("\(Int(imageManager.uploadProgress * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    )
                            }
                        }
                    }
                    .disabled(imageManager.isUploading)
                    
                    if let selectedImage = selectedImage {
                        Text("新しい画像が選択されました")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // 操作ボタン
                VStack(spacing: 15) {
                    if selectedImage != nil {
                        Button(action: uploadImage) {
                            HStack {
                                if imageManager.isUploading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "icloud.and.arrow.up")
                                }
                                Text(imageManager.isUploading ? "アップロード中..." : "画像をアップロード")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(imageManager.isUploading ? Color.gray : Color.blue)
                            .cornerRadius(10)
                        }
                        .disabled(imageManager.isUploading)
                    }
                    
                    if characterIcon != nil {
                        Button(action: deleteCurrentIcon) {
                            HStack {
                                Image(systemName: "trash")
                                Text("現在のアイコンを削除")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                        .disabled(imageManager.isUploading)
                    }
                }
                
                // 使用方法の説明
                VStack(alignment: .leading, spacing: 8) {
                    Text("使用方法")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 円形のアイコンエリアをタップして画像を選択")
                        Text("• 正方形の画像が推奨されます")
                        Text("• ファイルサイズは10MB以下にしてください")
                        Text("• JPEG形式で保存されます")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationTitle("アイコン設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage)
            }
            .alert("通知", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadCurrentIcon()
            }
        }
    }
    
    private func loadCurrentIcon() {
        // 既存のアイコンURLがある場合は読み込む
        if let iconURL = viewModel.character.iconURL, !iconURL.isEmpty {
            imageManager.loadImage(from: iconURL) { result in
                switch result {
                case .success(let image):
                    characterIcon = image
                case .failure(let error):
                    print("アイコンの読み込みエラー: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func uploadImage() {
        guard let image = selectedImage,
              let userId = viewModel.currentUserID else {
            alertMessage = "画像のアップロードに失敗しました"
            showingAlert = true
            return
        }
        
        let imagePath = "character_icons/\(userId)_\(viewModel.character.id)_\(Date().timeIntervalSince1970).jpg"
        
        imageManager.uploadImage(image, path: imagePath) { [weak viewModel] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let downloadURL):
                    // 古いアイコンを削除（必要に応じて）
                    if let oldIconURL = viewModel?.character.iconURL,
                       !oldIconURL.isEmpty,
                       let oldPath = extractPathFromURL(oldIconURL) {
                        imageManager.deleteImage(at: oldPath) { _ in
                            // 削除結果は無視（エラーでも継続）
                        }
                    }
                    
                    // 新しいアイコンURLを保存
                    viewModel?.character.iconURL = downloadURL
                    viewModel?.updateCharacterSettings()
                    
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
        guard let iconURL = viewModel.character.iconURL,
              !iconURL.isEmpty,
              let imagePath = extractPathFromURL(iconURL) else {
            alertMessage = "削除するアイコンが見つかりません"
            showingAlert = true
            return
        }
        
        imageManager.deleteImage(at: imagePath) { [weak viewModel] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    viewModel?.character.iconURL = nil
                    viewModel?.updateCharacterSettings()
                    characterIcon = nil
                    selectedImage = nil
                    
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
        // Firebase StorageのURLからパスを抽出
        guard let urlComponents = URLComponents(string: url),
              let path = urlComponents.path.components(separatedBy: "/o/").last?.components(separatedBy: "?").first else {
            return nil
        }
        return path.removingPercentEncoding
    }
}

#Preview {
    CharacterIconEditorView(viewModel: RomanceAppViewModel())
}
