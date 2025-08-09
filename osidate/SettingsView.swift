//
//  SettingsView.swift
//  osidate
//
//  Modern redesigned version with improved UI/UX
//

import SwiftUI
import Foundation
import SwiftyCrop

struct SettingsView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingResetIntimacyAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingResetUserDefaultsAlert = false
    @State private var isDataSyncing = false
    @FocusState private var isInputFocused: Bool
    
    // Image picker and cropping states
    @StateObject private var imageManager = ImageStorageManager()
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedImageForCropping: UIImage?
    @State private var croppingImage: UIImage?
    @State private var characterIcon: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var iconScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with character preview
                    characterHeaderView
                    
                    // Main settings sections
                    VStack(spacing: 16) {
                        appearanceSettingsSection
                        characterSettingsSection
                        anniversarySettingsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.immediately) // iOS16+
            .contentShape(Rectangle())             // VStack以外でもタップを拾えるように
            .onTapGesture {                        // 画面タップでフォーカス解除
                isInputFocused = false
            }
            .background(Color(.systemGroupedBackground))
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button {
//                        dismiss()
//                    } label: {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.title2)
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
            .setupAlerts()
            .sheet(isPresented: $viewModel.showingBackgroundSelector) {
                BackgroundSelectorView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView { pickedImage in
                    self.selectedImageForCropping = pickedImage
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
                        croppingImage = nil
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
    
    // MARK: - Header
    private var characterHeaderView: some View {
        VStack(spacing: 16) {
            // Character icon with glow effect - clickable for editing
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
                    Circle()
                        .fill(intimacyColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 8)
                    
                    if let icon = characterIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(intimacyColor, lineWidth: 3)
                            )
                            .shadow(color: intimacyColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    } else {
                        ZStack {
                            CharacterIconView(character: viewModel.character, size: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(intimacyColor, lineWidth: 3)
                                )
                                .shadow(color: intimacyColor.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            // Edit overlay
                            Circle()
                                .fill(.black.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        Text("編集")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                )
                        }
                    }
                    
                    // Upload overlay
                    if imageManager.isUploading {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 100, height: 100)
                            .overlay(
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: intimacyColor))
                                        .scaleEffect(1.2)
                                    Text("\(Int(imageManager.uploadProgress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(intimacyColor)
                                        .fontWeight(.medium)
                                }
                            )
                    }
                }
            }
            .scaleEffect(iconScale)
            .disabled(imageManager.isUploading)
            
            VStack(spacing: 4) {
                Text(viewModel.character.name.isEmpty ? "未設定" : viewModel.character.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("親密度 \(viewModel.character.intimacyLevel)")
                        .font(.subheadline)
                        .foregroundColor(intimacyColor)
                        .fontWeight(.medium)
                    
                    if imageManager.isUploading {
                        Text("• アップロード中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    private var hasCustomBackground: Bool {
        return viewModel.character.backgroundURL != nil && !viewModel.character.backgroundURL!.isEmpty
    }
    
    private var appearanceSettingsSection: some View {
        ModernSectionView(title: "外観設定", icon: "paintbrush.pointed") {
            VStack(spacing: 16) {
                // Character icon editor
                ModernSettingRow(
                    icon: "person.crop.circle.badge.camera",
                    title: "アイコン設定",
                    subtitle: characterIcon != nil ? "カスタムアイコンが設定されています" : "デフォルトアイコンを使用中"
                ) {
                    Button {
                        generateHapticFeedback()
                        showingImagePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            if imageManager.isUploading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("アップロード中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.blue)
                                Text("編集")
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(imageManager.isUploading)
                }
                
                Divider()
                
                // Background editor
                ModernSettingRow(
                    icon: "photo.on.rectangle.angled",
                    title: "背景設定",
                    subtitle: hasCustomBackground ? "カスタム背景が設定されています" : "プリセット背景を使用中"
                ) {
                    Button {
                        generateHapticFeedback()
                        viewModel.showingBackgroundSelector = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paintbrush.pointed.fill")
                                .foregroundColor(.purple)
                            Text("編集")
                                .foregroundColor(.purple)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Show current background preview if custom background is set
                if hasCustomBackground {
                    Divider()
                    
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("現在の背景")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("カスタム画像を使用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Small background preview
                        Group {
                            if let backgroundURL = viewModel.character.backgroundURL,
                               let url = URL(string: backgroundURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(0.6)
                                        )
                                }
                            } else {
                                Image(viewModel.character.backgroundName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                        }
                        .frame(width: 60, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Character Settings
    private var characterSettingsSection: some View {
        ModernSectionView(title: "キャラクター設定", icon: "person.circle") {
            VStack(spacing: 16) {
                // Name field
                ModernSettingRow(
                    icon: "textformat",
                    title: "名前",
                    subtitle: "キャラクターの呼び名"
                ) {
                    TextField("名前を入力", text: $viewModel.character.name)
                        .textFieldStyle(ModernTextFieldStyle())
                        .focused($isInputFocused)
                        .onChange(of: viewModel.character.name) { _ in
                            viewModel.updateCharacterSettings()
                        }
                }
                
                Divider()
                
                // Personality editor
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundColor(.pink)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("性格")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("キャラクターの個性を設定")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TextEditor(text: $viewModel.character.personality)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .focused($isInputFocused)
                        .onChange(of: viewModel.character.personality) { _ in
                            viewModel.updateCharacterSettings()
                        }
                }
                
                Divider()
                
                // Speaking style editor
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("話し方")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("会話のスタイルを設定")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TextEditor(text: $viewModel.character.speakingStyle)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .focused($isInputFocused) 
                        .onChange(of: viewModel.character.speakingStyle) { _ in
                            viewModel.updateCharacterSettings()
                        }
                }
            }
        }
    }
    
    // MARK: - Anniversary Settings
    private var anniversarySettingsSection: some View {
        ModernSectionView(title: "記念日設定", icon: "calendar.badge.plus") {
            VStack(spacing: 16) {
                // Birthday setting
                birthdaySettingRow
                
                if viewModel.character.birthday != nil {
                    Divider()
                    
                    Button {
                        viewModel.character.birthday = nil
                        viewModel.updateCharacterSettings()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("誕生日を削除")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                
                Divider()
                
                // Anniversary setting
                anniversarySettingRow
                
                if viewModel.character.anniversaryDate != nil {
                    Divider()
                    
                    Button {
                        viewModel.character.anniversaryDate = nil
                        viewModel.updateCharacterSettings()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("記念日を削除")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var birthdaySettingRow: some View {
        ModernSettingRow(
            icon: "gift",
            title: "誕生日",
            subtitle: viewModel.character.birthday != nil ? dateFormatter.string(from: viewModel.character.birthday!) : "未設定"
        ) {
            if viewModel.character.birthday != nil {
                DatePicker("", selection: Binding(
                    get: { viewModel.character.birthday ?? Date() },
                    set: { newValue in
                        viewModel.character.birthday = newValue
                        viewModel.updateCharacterSettings()
                    }
                ), displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
            } else {
                Button("設定") {
                    viewModel.character.birthday = Date()
                    viewModel.updateCharacterSettings()
                }
                .buttonStyle(ModernButtonStyle(color: .blue))
            }
        }
    }
    
    private var anniversarySettingRow: some View {
        ModernSettingRow(
            icon: "heart.circle",
            title: "記念日",
            subtitle: viewModel.character.anniversaryDate != nil ? dateFormatter.string(from: viewModel.character.anniversaryDate!) : "未設定"
        ) {
            if viewModel.character.anniversaryDate != nil {
                DatePicker("", selection: Binding(
                    get: { viewModel.character.anniversaryDate ?? Date() },
                    set: { newValue in
                        viewModel.character.anniversaryDate = newValue
                        viewModel.updateCharacterSettings()
                    }
                ), displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
            } else {
                Button("設定") {
                    viewModel.character.anniversaryDate = Date()
                    viewModel.updateCharacterSettings()
                }
                .buttonStyle(ModernButtonStyle(color: .pink))
            }
        }
    }
    
    // MARK: - Intimacy Section
    private var intimacySection: some View {
        ModernSectionView(title: "親密度", icon: "heart.fill") {
            VStack(spacing: 16) {
                // Intimacy level display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("現在の親密度")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Text("\(viewModel.character.intimacyLevel)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(intimacyColor)
                            Text("/ 100")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(intimacyColor.opacity(0.2), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.character.intimacyLevel) / 100)
                            .stroke(intimacyColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(viewModel.character.intimacyLevel)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(intimacyColor)
                    }
                }
                
                Divider()
                
                Button {
                    showingResetIntimacyAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.orange)
                        Text("親密度をリセット")
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Data Management
    private var dataManagementSection: some View {
        ModernSectionView(title: "データ管理", icon: "externaldrive") {
            VStack(spacing: 16) {
                ModernSettingRow(
                    icon: "icloud.and.arrow.up",
                    title: "データ同期",
                    subtitle: isDataSyncing ? "同期中..." : "クラウドとの同期状態"
                ) {
                    if isDataSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Divider()
                
                Button {
                    showingResetUserDefaultsAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        Text("UserDefaultsをリセット")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                
                Divider()
                
                Button {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                        Text("すべてのデータを削除")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Account Section
    private var accountSection: some View {
        ModernSectionView(title: "アカウント", icon: "person.crop.circle") {
            Button {
                showingSignOutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    Text("ログアウト")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    private var intimacyColor: Color {
        switch viewModel.character.intimacyLevel {
        case 0...10: return .gray
        case 11...30: return .blue
        case 31...60: return .green
        case 61...100: return .pink
        default: return .red
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }
    
    // SwiftyCrop configuration
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
    
    // MARK: - Image Management Functions
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

// MARK: - Modern UI Components

struct ModernSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.title3)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ModernSettingRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let content: Content
    
    init(icon: String, title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            content
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

struct ModernButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Alert Extension
extension View {
    func setupAlerts() -> some View {
        self
            .alert("データを削除", isPresented: Binding.constant(false)) {
                Button("削除", role: .destructive) {
                    // Handle delete
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("すべての会話データとローカルデータが削除されます。この操作は取り消せません。")
            }
    }
}

// MARK: - UIImage extension for Identifiable protocol
extension UIImage: Identifiable {
    public var id: String {
        return UUID().uuidString
    }
}

#Preview {
    SettingsView(viewModel: RomanceAppViewModel())
}
