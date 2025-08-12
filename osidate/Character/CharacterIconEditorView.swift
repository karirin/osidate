//
//  CharacterIconEditorView.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI
import SwiftyCrop

struct CharacterIconEditorView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @StateObject private var imageManager = ImageStorageManager()
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var characterIcon: UIImage?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private struct CroppingItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    // クロップ機能用の状態
    @State private var selectedImageForCropping: UIImage?
    @State private var croppingItem: CroppingItem?
    
    // アニメーション用の状態
    @State private var iconScale: CGFloat = 1.0
    @State private var deleteButtonScale: CGFloat = 1.0
    
    // カラーテーマ
    private var primaryColor: Color {
        Color(.systemPink)
    }
    
    private var accentColor: Color {
        Color(.systemPurple)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6)
    }
    
    private var cardColor: Color {
        Color(.secondarySystemBackground)
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
                backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
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
                                instructionRow(icon: "doc.fill", text: "ファイルサイズは10MB以下にしてください")
                            }
                        }
                        .padding(20)
                        .background(cardColor)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("アイコン設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(primaryColor)
                }
            }
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
                            uploadImage()
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
                loadCurrentIcon()
            }
        }
    }
    
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
    
    private func loadCurrentIcon() {
        if let iconURL = viewModel.character.iconURL, !iconURL.isEmpty {
            imageManager.loadImage(from: iconURL) { result in
                switch result {
                case .success(let image):
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        characterIcon = image
                    }
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
                    if let oldIconURL = viewModel?.character.iconURL,
                       !oldIconURL.isEmpty,
                       let oldPath = extractPathFromURL(oldIconURL) {
                        imageManager.deleteImage(at: oldPath) { _ in }
                    }
                    
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
                    
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        characterIcon = nil
                        selectedImage = nil
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

#Preview {
    CharacterIconEditorView(viewModel: RomanceAppViewModel())
}
