//
//  BackgroundSelectorView.swift
//  osidate
//
//  Created by Apple on 2025/08/04.
//

import SwiftUI
import SwiftyCrop

struct BackgroundSelectorView: View {
    // MARK: - Dependencies
    @ObservedObject var viewModel: RomanceAppViewModel
    @StateObject private var imageManager = ImageStorageManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Image Picker & Cropper
    @State private var showingImagePicker        = false
    @State private var selectedImage: UIImage?   = nil
    @State private var selectedImageForCropping: UIImage? = nil
    @State private var croppingImage: UIImage?   = nil
    @State private var customBackgroundImage: UIImage? = nil
    
    // MARK: - UI State
    @State private var showingAlert  = false
    @State private var alertMessage  = ""
    @State private var selectedPresetIndex: Int = 0
    @State private var backgroundScale: CGFloat = 1.0
    
    // MARK: - Preset Backgrounds
    private let presetBackgrounds = PresetBackground.availableBackgrounds
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 現在の背景プレビュー
                    ZStack {
                        if let customBackgroundImage {
                            Image(uiImage: customBackgroundImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width * 0.6,
                                       height: UIScreen.main.bounds.height * 0.3)
                                .clipped()
                                .cornerRadius(20)
                                .shadow(radius: 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .scaleEffect(backgroundScale)
                                .animation(.spring(response: 0.4,
                                                   dampingFraction: 0.7), value: backgroundScale)
                            
                            if imageManager.isUploading {
                                ProgressOverlay(progress: imageManager.uploadProgress)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray5))
                                .frame(width: UIScreen.main.bounds.width * 0.6,
                                       height: UIScreen.main.bounds.height * 0.3)
                                .overlay(
                                    Text("背景未設定")
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    .padding(.top)
                    
                    // プリセット選択
                    VStack(alignment: .leading, spacing: 12) {
                        Text("プリセット背景")
                            .font(.headline)
                            .padding(.leading, 20)
                        
                        LazyVGrid(columns: Array(repeating: .init(.flexible(),
                                                                  spacing: 12), count: 3),
                                   spacing: 12) {
                            ForEach(Array(presetBackgrounds.enumerated()), id: \.offset) { idx, preset in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedPresetIndex = idx
                                        customBackgroundImage = UIImage(named: preset.imageName)
                                        viewModel.character.backgroundURL = nil
                                        viewModel.character.backgroundName = preset.imageName
                                        viewModel.updateCharacterSettings()
                                    }
                                } label: {
                                    Image(preset.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedPresetIndex == idx ?
                                                        Color.accentColor : Color.clear,
                                                        lineWidth: 3)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // カスタム画像ボタン
                    VStack(spacing: 16) {
                        Divider()
                        Button(action: { showingImagePicker = true }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("フォトライブラリから選択")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(imageManager.isUploading)
                        
                        Button(role: .destructive) {
                            customBackgroundImage = nil
                            viewModel.character.backgroundURL = nil
                            viewModel.updateCharacterSettings()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("背景をリセット")
                            }
                        }
                        .disabled(imageManager.isUploading ||
                                  (viewModel.character.backgroundURL ?? "").isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("背景を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
            .alert("通知",
                   isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: { Text(alertMessage) }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView { image in
                    selectedImageForCropping = image
                }
            }
            .onChange(of: selectedImageForCropping) { img in
                guard let img else { return }
                croppingImage = img
            }
            .fullScreenCover(item: $croppingImage) { img in
                NavigationView {
                    SwiftyCropView(
                        imageToCrop: img,
                        maskShape: .rectangle,          // ★ .rect → .rectangle
                        configuration: cropConfig       // ★ 余分な引数を削除
                    ) { cropped in
                        if let cropped {
                            withAnimation(.spring(response: 0.5,
                                                   dampingFraction: 0.7)) {
                                selectedImage = cropped
                                customBackgroundImage = cropped
                            }
                            uploadBackground()
                        }
                        croppingImage = nil
                    }
                    .navigationBarHidden(true)
                    .drawingGroup()
                }
            }
            .onAppear {
                loadCurrentBackground()
            }
        }
    }
}

struct PresetBackground: Identifiable {
    let id = UUID()
    let imageName: String          // Assets に登録した画像名
    
    // プリセットに使う画像をここに追加
    static let availableBackgrounds: [PresetBackground] = [
        .init(imageName: "背景画像1"),
        .init(imageName: "背景画像2"),
        .init(imageName: "背景画像3")
    ]
}

// MARK: - Private Helpers
private extension BackgroundSelectorView {
    
    var cropConfig: SwiftyCropConfiguration {
        var cfg = SwiftyCropConfiguration(
            rectAspectRatio: 9.0 / 16.0, texts: .init(cancelButton: "キャンセル",
                                                      interactionInstructions: "",
                                                      saveButton: "適用")
        )
        return cfg
    }
    
    func loadCurrentBackground() {
        if let url = viewModel.character.backgroundURL, !url.isEmpty {
            imageManager.loadImage(from: url) { result in
                if case .success(let img) = result {
                    withAnimation(.easeInOut) {
                        customBackgroundImage = img
                    }
                }
            }
        } else {
            // ★ URL が無い場合は Assets の backgroundName からプレビュー生成
            let name = viewModel.character.backgroundName
            if let img = UIImage(named: name) {
                withAnimation(.easeInOut) { customBackgroundImage = img }
            }
            // ★ 選択中ハイライトの初期化
            if let idx = PresetBackground.availableBackgrounds.firstIndex(where: { $0.imageName == name }) {
                selectedPresetIndex = idx
            }
        }
    }
    
    func uploadBackground() {
        guard let image = selectedImage,
              let userId = viewModel.currentUserID else {
            alertMessage = "アップロードに失敗しました"
            showingAlert = true
            return
        }
        
        let path = "backgrounds/\(userId)_\(Date().timeIntervalSince1970).jpg"
        
        imageManager.uploadImage(image, path: path) { [weak viewModel] result in
            switch result {
            case .success(let url):
                // 旧背景があれば削除
                if let oldURL = viewModel?.character.backgroundURL,
                   !oldURL.isEmpty,
                   let oldPath = extractPath(from: oldURL) {
                    imageManager.deleteImage(at: oldPath) { _ in }
                }
                
                viewModel?.character.backgroundURL = url
                viewModel?.updateCharacterSettings()
                
                alertMessage = "背景画像を更新しました"
                showingAlert = true
                selectedImage = nil
                
            case .failure(let err):
                alertMessage = "アップロード失敗: \(err.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    func extractPath(from url: String) -> String? {
        guard let comps = URLComponents(string: url),
              let path = comps.path.components(separatedBy: "/o/").last?
                .components(separatedBy: "?").first else { return nil }
        return path.removingPercentEncoding
    }
}

// MARK: - Components
private struct ProgressOverlay: View {
    let progress: Double
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 120, height: 120)
            .overlay(
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            )
    }
}

// MARK: - Preview
#Preview {
//    BackgroundSelectorView(viewModel: RomanceAppViewModel())
    ContentView(viewModel: RomanceAppViewModel())
}
