//
//  SettingsView.swift
//  osidate
//
//  Modern redesigned version with user nickname feature
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
    @State private var croppingItem: CroppingItem?
    @State private var characterIcon: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var iconScale: CGFloat = 1.0
    
    private struct CroppingItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    // Header with character preview
                    characterHeaderView
                    
                    // Main settings sections
                    VStack(spacing: 16) {
                        characterSettingsSection
                        appearanceSettingsSection
                        userNicknameSettingsSection  // 🌟 新規追加
                        anniversarySettingsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
            }
            .background(Color(.systemGroupedBackground))
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
                VStack{
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
                                // 🌟 アニメーションを無効にしてCharacterIconViewを使用
                                CharacterIconView(character: viewModel.character, size: 100, enableFloating: false)
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
                        Circle()
                            .fill(intimacyColor)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 40, y: 40)
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
                    Text("タップで推しの画像を変更できます")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
            }
            .scaleEffect(iconScale)
            .disabled(imageManager.isUploading)
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
                    icon: "person.crop.circle.badge.plus",
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

    // MARK: - 🌟 User Nickname Settings Section
    private var userNicknameSettingsSection: some View {
        ModernSectionView(title: "あなたの呼び名設定", icon: "person.badge.plus") {
            VStack(spacing: 16) {
                // Nickname input field - 常に表示
                ModernSettingRow(
                    icon: "textformat.alt",
                    title: "呼び名"
                ) {
                    TextField("呼び名を入力", text: $viewModel.character.userNickname)
                        .textFieldStyle(ModernTextFieldStyle())
                        .focused($isInputFocused)
                        .onChange(of: viewModel.character.userNickname) { newValue in
                            // 20文字制限
                            if newValue.count > 20 {
                                viewModel.character.userNickname = String(newValue.prefix(20))
                            }
                            
                            // 呼び名が入力された場合は自動的にuseNicknameをtrueに設定
                            if !newValue.isEmpty && !viewModel.character.useNickname {
                                viewModel.character.useNickname = true
                                sendNicknameChangeMessage(enabled: true)
                            }
                            // 呼び名が空になった場合は自動的にuseNicknameをfalseに設定
                            else if newValue.isEmpty && viewModel.character.useNickname {
                                viewModel.character.useNickname = false
                                sendNicknameChangeMessage(enabled: false)
                            }
                            
                            viewModel.updateCharacterSettings()
                        }
                        .onSubmit {
                            if !viewModel.character.userNickname.isEmpty {
                                sendNicknameSetMessage()
                            }
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
    
    // MARK: - Helper Properties
    private var intimacyColor: Color {
        return viewModel.character.intimacyStage.color
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

    private func getNicknameSuggestions() -> [String] {
        let intimacyLevel = viewModel.character.intimacyLevel
        
        switch intimacyLevel {
        case 0...100:
            return ["さん", "くん", "お友達", "パートナー", "相棒", "バディ"]
        case 101...300:
            return ["ちゃん", "君", "お疲れ様", "大切な人", "特別な人", "親友"]
        case 301...700:
            return ["愛しい人", "ダーリン", "ハニー", "大好きな人", "恋人", "スイート"]
        case 701...1300:
            return ["最愛の人", "運命の人", "愛する人", "マイラブ", "宝物", "天使"]
        case 1301...2000:
            return ["魂の伴侶", "永遠の愛", "命の人", "奇跡", "光", "希望"]
        default:
            return ["無限の愛", "永遠", "唯一無二", "全て", "世界", "宇宙"]
        }
    }

    private func getIntimacyBasedPreview() -> String {
        let nickname = viewModel.character.userDisplayName
        let intimacyLevel = viewModel.character.intimacyLevel
        
        switch intimacyLevel {
        case 0...100:
            return "\(nickname)、今度一緒にお出かけしませんか？"
        case 101...300:
            return "\(nickname)のことをもっと知りたいです"
        case 301...700:
            return "\(nickname)、愛してるよ💕"
        case 701...1300:
            return "\(nickname)がいてくれて本当に幸せです"
        case 1301...2000:
            return "\(nickname)、あなたは私の全てです"
        default:
            return "\(nickname)、私たちの愛は永遠ですね♾️"
        }
    }

    private func suggestDefaultNickname() {
        let suggestions = getNicknameSuggestions()
        if let defaultSuggestion = suggestions.first {
            viewModel.character.userNickname = defaultSuggestion
        }
    }

    private func sendNicknameChangeMessage(enabled: Bool) {
        let message: String
        
        if enabled {
            let nickname = viewModel.character.userNickname.isEmpty ? "特別な呼び名" : viewModel.character.userNickname
            message = "これからは\(nickname)って呼ばせてもらいますね💕 特別な呼び名で呼べるなんて、なんだか嬉しいです✨"
        } else {
            message = "分かりました。これからは普通に「あなた」って呼びますね。でも、心の中ではいつでも特別な存在ですよ💕"
        }
        
        // ViewModelにメッセージ送信を依頼
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.sendSystemMessage(message)
        }
    }

    private func sendNicknameSetMessage() {
        let nickname = viewModel.character.userNickname
        guard !nickname.isEmpty else { return }
        
        let message = "\(nickname)...素敵な響きですね💕 これから\(nickname)って呼ばせていただきます。特別な呼び名をつけてもらえて、とても嬉しいです✨"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.sendSystemMessage(message)
        }
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

// MARK: - Supporting Views

struct SuggestionButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PreviewMessageBubble: View {
    let text: String
    let isFromAI: Bool
    
    var body: some View {
        HStack {
            if !isFromAI {
                Spacer()
            }
            
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isFromAI ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                .foregroundColor(.primary)
                .cornerRadius(12)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isFromAI ? .leading : .trailing)
            
            if isFromAI {
                Spacer()
            }
        }
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
    }
}

#Preview {
    SettingsView(viewModel: RomanceAppViewModel())
}
