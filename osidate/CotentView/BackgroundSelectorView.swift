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
    @State private var previewScale: CGFloat = 1.0
    @State private var showingPreview: Bool = false
    
    // MARK: - Animation States
    @State private var shimmerOffset: CGFloat = -100
    @State private var cardAppearOffset: CGFloat = 50
    @State private var cardAppearOpacity: Double = 0
    
    // MARK: - Preset Backgrounds
    private let presetBackgrounds = PresetBackground.availableBackgrounds
    
    // MARK: - Design Constants
    private var primaryColor: Color {
        Color(.systemBlue)
    }
    
    private var accentColor: Color {
        Color(.systemPurple)
    }
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [
                        backgroundColor,
                        primaryColor.opacity(0.05),
                        accentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 32) {
                        // ヘッダーセクション
                        headerSection
                        
                        // 現在の背景プレビュー
                        currentBackgroundPreview
                        
                        // プリセット選択セクション
                        presetBackgroundsSection
                        
                        // カスタム背景セクション
                        customBackgroundSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.top, 10)
                }
            }
            .navigationTitle("背景を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        generateHapticFeedback()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(primaryColor)
                }
            }
            .alert("通知", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
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
                        maskShape: .rectangle,
                        configuration: cropConfig
                    ) { cropped in
                        if let cropped {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
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
                animateCardsAppearance()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(primaryColor)
                
                Text("背景をカスタマイズ")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text("お気に入りの背景を選んで、あなただけの特別な空間を作りましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: cardAppearOffset)
    }
    
    // MARK: - Current Background Preview
    private var currentBackgroundPreview: some View {
        VStack(spacing: 20) {
            Text("現在の背景")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ZStack {
                // メインプレビュー
                Group {
                    if let customBackgroundImage {
                        Image(uiImage: customBackgroundImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 40, weight: .light))
                                        .foregroundColor(primaryColor.opacity(0.7))
                                    
                                    Text("背景未設定")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.75, height: UIScreen.main.bounds.height * 0.35)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [primaryColor.opacity(0.3), accentColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: primaryColor.opacity(0.2),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .scaleEffect(previewScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: previewScale)
                
                // アップロード中オーバーレイ
                if imageManager.isUploading {
                    modernProgressOverlay
                }
                
                // プレビューボタン
                if customBackgroundImage != nil {
                    VStack {
                        HStack {
                            Spacer()
                            previewButton
                        }
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .onTapGesture {
                generateHapticFeedback()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    previewScale = 0.95
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        previewScale = 1.0
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: cardAppearOffset)
    }
    
    // MARK: - Preview Button
    private var previewButton: some View {
        Button(action: {
            generateHapticFeedback()
            showingPreview.toggle()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Image(systemName: "eye.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(primaryColor)
            }
        }
        .scaleEffect(showingPreview ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingPreview)
    }
    
    // MARK: - Modern Progress Overlay
    private var modernProgressOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
            
            VStack(spacing: 20) {
                // カスタムプログレスリング
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: imageManager.uploadProgress)
                        .stroke(
                            LinearGradient(
                                colors: [primaryColor, accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: imageManager.uploadProgress)
                    
                    Text("\(Int(imageManager.uploadProgress * 100))%")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(primaryColor)
                }
                
                VStack(spacing: 8) {
                    Text("アップロード中")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("しばらくお待ちください...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Preset Backgrounds Section
    private var presetBackgroundsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("プリセット背景")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("美しいプリセット背景から選択")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(accentColor)
                    .rotationEffect(.degrees(shimmerOffset / 10))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: shimmerOffset)
            }
            .padding(.horizontal, 20)
            
            LazyVGrid(
                columns: Array(repeating: .init(.flexible(), spacing: 16), count: 4),
                spacing: 16
            ) {
                ForEach(Array(presetBackgrounds.enumerated()), id: \.offset) { idx, preset in
                    presetBackgroundCard(preset: preset, index: idx)
                }
            }
            .padding(.horizontal, 20)
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: cardAppearOffset)
    }
    
    // MARK: - Preset Background Card
    private func presetBackgroundCard(preset: PresetBackground, index: Int) -> some View {
        Button {
            generateHapticFeedback()
            selectPresetBackground(preset: preset, index: index)
        } label: {
            ZStack {
                // 背景画像
                Image(preset.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // オーバーレイ
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.3))
                
                // 選択状態のオーバーレイ
                if selectedPresetIndex == index {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [primaryColor, accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(primaryColor.opacity(0.1))
                        )
                    
                    // チェックマーク
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(primaryColor)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                }
                
                // 背景名
                VStack {
                    Spacer()
                    HStack {
                        Text(preset.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .scaleEffect(selectedPresetIndex == index ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPresetIndex)
        .shadow(
            color: selectedPresetIndex == index ? primaryColor.opacity(0.3) : Color.black.opacity(0.1),
            radius: selectedPresetIndex == index ? 12 : 4,
            x: 0,
            y: selectedPresetIndex == index ? 6 : 2
        )
    }
    
    // MARK: - Custom Background Section
    private var customBackgroundSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("カスタム背景")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("お気に入りの写真を背景に設定")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "photo.badge.plus")
                    .font(.title3)
                    .foregroundColor(primaryColor)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                // フォトライブラリボタン
                customActionButton(
                    icon: "photo.on.rectangle.angled",
                    title: "フォトライブラリから選択",
                    subtitle: "美しい写真を背景に設定しましょう",
                    color: primaryColor,
                    isDisabled: imageManager.isUploading
                ) {
                    generateHapticFeedback()
                    showingImagePicker = true
                }
                
                // リセットボタン
                customActionButton(
                    icon: "arrow.clockwise",
                    title: "背景をリセット",
                    subtitle: "デフォルトの背景に戻します",
                    color: .red,
                    isDisabled: imageManager.isUploading || (viewModel.character.backgroundURL ?? "").isEmpty
                ) {
                    generateHapticFeedback()
                    resetBackground()
                }
            }
            .padding(.horizontal, 20)
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: cardAppearOffset)
    }
    
    // MARK: - Custom Action Button
    private func customActionButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(cardColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
        .scaleEffect(isDisabled ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

// MARK: - PresetBackground Extension
extension PresetBackground {
    var displayName: String {
        switch imageName {
        case "背景画像1": return "ロマンチック"
        case "背景画像2": return "ナチュラル"
        case "背景画像3": return "エレガント"
        default: return "背景"
        }
    }
}

// MARK: - Private Helpers
private extension BackgroundSelectorView {
    
    var cropConfig: SwiftyCropConfiguration {
        var cfg = SwiftyCropConfiguration(
            rectAspectRatio: 9.0 / 16.0,
            texts: .init(
                cancelButton: "キャンセル",
                interactionInstructions: "",
                saveButton: "適用"
            )
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
            let name = viewModel.character.backgroundName
            if let img = UIImage(named: name) {
                withAnimation(.easeInOut) {
                    customBackgroundImage = img
                }
            }
            if let idx = PresetBackground.availableBackgrounds.firstIndex(where: { $0.imageName == name }) {
                selectedPresetIndex = idx
            }
        }
    }
    
    func selectPresetBackground(preset: PresetBackground, index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            selectedPresetIndex = index
            customBackgroundImage = UIImage(named: preset.imageName)
            viewModel.character.backgroundURL = nil
            viewModel.character.backgroundName = preset.imageName
            viewModel.updateCharacterSettings()
        }
    }
    
    func resetBackground() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            customBackgroundImage = nil
            viewModel.character.backgroundURL = nil
            viewModel.character.backgroundName = "defaultBG"
            viewModel.updateCharacterSettings()
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
    
    func generateHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func animateCardsAppearance() {
        // 初期状態設定
        cardAppearOffset = 50
        cardAppearOpacity = 0
        
        // アニメーション開始
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            cardAppearOffset = 0
            cardAppearOpacity = 1
        }
        
        // シマーアニメーション開始
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            shimmerOffset = 100
        }
    }
}

// MARK: - Preview
#Preview {
    BackgroundSelectorView(viewModel: RomanceAppViewModel())
}


struct PresetBackground: Identifiable {
    let id = UUID()
    let imageName: String          // Assets に登録した画像名
    
    // プリセットに使う画像をここに追加
    static let availableBackgrounds: [PresetBackground] = [
        .init(imageName: "背景画像1"),
        .init(imageName: "背景画像2"),
        .init(imageName: "背景画像3"),
        .init(imageName: "背景画像1"),
        .init(imageName: "背景画像2"),
        .init(imageName: "背景画像3"),
        .init(imageName: "背景画像2"),
        .init(imageName: "背景画像3")
    ]
}

// MARK: - Private Helpers
//private extension BackgroundSelectorView {
//    
//    var cropConfig: SwiftyCropConfiguration {
//        var cfg = SwiftyCropConfiguration(
//            rectAspectRatio: 9.0 / 16.0, texts: .init(cancelButton: "キャンセル",
//                                                      interactionInstructions: "",
//                                                      saveButton: "適用")
//        )
//        return cfg
//    }
//    
//    func loadCurrentBackground() {
//        if let url = viewModel.character.backgroundURL, !url.isEmpty {
//            imageManager.loadImage(from: url) { result in
//                if case .success(let img) = result {
//                    withAnimation(.easeInOut) {
//                        customBackgroundImage = img
//                    }
//                }
//            }
//        } else {
//            // ★ URL が無い場合は Assets の backgroundName からプレビュー生成
//            let name = viewModel.character.backgroundName
//            if let img = UIImage(named: name) {
//                withAnimation(.easeInOut) { customBackgroundImage = img }
//            }
//            // ★ 選択中ハイライトの初期化
//            if let idx = PresetBackground.availableBackgrounds.firstIndex(where: { $0.imageName == name }) {
//                selectedPresetIndex = idx
//            }
//        }
//    }
//    
//    func uploadBackground() {
//        guard let image = selectedImage,
//              let userId = viewModel.currentUserID else {
//            alertMessage = "アップロードに失敗しました"
//            showingAlert = true
//            return
//        }
//        
//        let path = "backgrounds/\(userId)_\(Date().timeIntervalSince1970).jpg"
//        
//        imageManager.uploadImage(image, path: path) { [weak viewModel] result in
//            switch result {
//            case .success(let url):
//                // 旧背景があれば削除
//                if let oldURL = viewModel?.character.backgroundURL,
//                   !oldURL.isEmpty,
//                   let oldPath = extractPath(from: oldURL) {
//                    imageManager.deleteImage(at: oldPath) { _ in }
//                }
//                
//                viewModel?.character.backgroundURL = url
//                viewModel?.updateCharacterSettings()
//                
//                alertMessage = "背景画像を更新しました"
//                showingAlert = true
//                selectedImage = nil
//                
//            case .failure(let err):
//                alertMessage = "アップロード失敗: \(err.localizedDescription)"
//                showingAlert = true
//            }
//        }
//    }
//    
//    func extractPath(from url: String) -> String? {
//        guard let comps = URLComponents(string: url),
//              let path = comps.path.components(separatedBy: "/o/").last?
//                .components(separatedBy: "?").first else { return nil }
//        return path.removingPercentEncoding
//    }
//}

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
    ContentView(viewModel: RomanceAppViewModel(), characterRegistry: CharacterRegistry())
}
