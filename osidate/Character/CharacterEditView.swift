//
//  CharacterEditView.swift
//  osidate
//
//  編集ボタンクリック時のみ更新、自動入力処理を削除
//

import SwiftUI
import Foundation
import SwiftyCrop

struct CharacterEditView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingResetIntimacyAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingResetUserDefaultsAlert = false
    @State private var isDataSyncing = false
    @FocusState private var isInputFocused: Bool
    
    // 🌟 編集用の一時的な状態変数（元のデータは変更しない）
    @State private var tempName: String = ""
    @State private var tempPersonality: String = ""
    @State private var tempSpeakingStyle: String = ""
    @State private var tempUserNickname: String = ""
    @State private var tempUseNickname: Bool = false
    @State private var tempBirthday: Date? = nil
    @State private var tempAnniversaryDate: Date? = nil
    @State private var tempIconURL: String? = nil // 🔧 アイコンURL用の一時変数を追加
    
    // 🌟 バリデーション用のアラート状態
    @State private var showingNameValidationAlert = false
    @State private var showingPersonalityValidationAlert = false
    @State private var showingSpeakingStyleValidationAlert = false
    
    // 🌟 変更検知フラグ
    @State private var hasChanges = false
    
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
                        userNicknameSettingsSection
                        anniversarySettingsSection
                        
                        // 🌟 保存・キャンセルボタン
                        saveButtonsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitle("推しを編集", displayMode: .inline)
            .navigationBarItems(
                trailing:
                    Button("編集") {
                        saveChanges()
                    }
                    .padding(.leading,10)
                    .padding(.trailing)
                    .padding(.vertical, 4)
                    .background(hasChanges ? Color.blue : Color(.systemGray4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!hasChanges)
            )
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
                ImageEditPickerView { pickedImage in
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
                                hasChanges = true // 🌟 画像変更も変更フラグを立てる
                            }
                            uploadImage()
                        }
                        croppingItem = nil
                    }
                    .drawingGroup()
                }
                .navigationBarHidden(true)
            }
            // 🌟 バリデーションアラートを修正（自動入力処理を削除）
            .alert("名前は必須です", isPresented: $showingNameValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("推しの名前は1文字以上入力してください。")
            }
            .alert("性格設定は必須です", isPresented: $showingPersonalityValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("推しの性格は1文字以上入力してください。")
            }
            .alert("話し方設定は必須です", isPresented: $showingSpeakingStyleValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("推しの話し方は1文字以上入力してください。")
            }
            .alert("通知", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadCurrentIcon()
                initializeTemporaryValues() // 🌟 一時的な値を初期化
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // 🌟 一時的な値を初期化
    private func initializeTemporaryValues() {
        tempName = viewModel.character.name
        tempPersonality = viewModel.character.personality
        tempSpeakingStyle = viewModel.character.speakingStyle
        tempUserNickname = viewModel.character.userNickname
        tempUseNickname = viewModel.character.useNickname
        tempBirthday = viewModel.character.birthday
        tempAnniversaryDate = viewModel.character.anniversaryDate
        tempIconURL = viewModel.character.iconURL // 🔧 アイコンURLも初期化
        hasChanges = false
    }
    
    // 🌟 変更を検知する関数 🔧 アイコンURLの変更も検知
    private func detectChanges() {
        let oldHasChanges = hasChanges
        
        hasChanges = (tempName != viewModel.character.name) ||
                    (tempPersonality != viewModel.character.personality) ||
                    (tempSpeakingStyle != viewModel.character.speakingStyle) ||
                    (tempUserNickname != viewModel.character.userNickname) ||
                    (tempUseNickname != viewModel.character.useNickname) ||
                    (tempBirthday != viewModel.character.birthday) ||
                    (tempAnniversaryDate != viewModel.character.anniversaryDate) ||
                    (tempIconURL != viewModel.character.iconURL) // 🔧 アイコンURLの変更も検知
        
        // デバッグ用
        if oldHasChanges != hasChanges {
            print("🔍 変更検知: \(hasChanges)")
        }
    }
    
    // 🌟 保存・キャンセルボタンセクション
    private var saveButtonsSection: some View {
        VStack(spacing: 12) {
            if hasChanges {
                HStack(spacing: 12) {
                    // 保存ボタン
                    Button("保存") {
                        saveChanges()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isFormValid ? Color.blue : Color(.systemGray4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!isFormValid)
                }
                .padding(.top, 16)
            }
            
            if hasChanges {
                Text("未保存の変更があります")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    // 🌟 フォームの有効性をチェック
    private var isFormValid: Bool {
        return !tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !tempPersonality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !tempSpeakingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // 🌟 変更を保存する 🔧 アイコンURLも保存対象に追加
    private func saveChanges() {
        // バリデーション
        if tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showingNameValidationAlert = true
            return
        }
        
        if tempPersonality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showingPersonalityValidationAlert = true
            return
        }
        
        if tempSpeakingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showingSpeakingStyleValidationAlert = true
            return
        }
        
        // 実際のデータに反映
        viewModel.character.name = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.character.personality = tempPersonality.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.character.speakingStyle = tempSpeakingStyle.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.character.userNickname = tempUserNickname
        viewModel.character.useNickname = tempUseNickname
        viewModel.character.birthday = tempBirthday
        viewModel.character.anniversaryDate = tempAnniversaryDate
        
        // 🔧 アイコンURLも保存
        if let tempIconURL = tempIconURL {
            viewModel.character.iconURL = tempIconURL
        }
        
        // ViewModelの更新メソッドを呼び出し
        viewModel.updateCharacterSettings()
        
        // 変更フラグをリセット
        hasChanges = false
        
        // 成功メッセージ
        alertMessage = "設定を保存しました"
        showingAlert = true
        
        print("✅ キャラクター設定を保存しました")
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
        ModernSectionView(title: "推し設定", icon: "person.circle") {
            VStack(spacing: 16) {
                // Name field - 🌟 修正：自動入力処理を削除
                ModernSettingRow(
                    icon: "textformat",
                    title: "名前",
                    subtitle: "推しの呼び名"
                ) {
                    TextField("名前を入力", text: $tempName)
                        .textFieldStyle(ModernEditTextFieldStyle())
                        .focused($isInputFocused)
                        .onChange(of: tempName) { _ in
                            detectChanges() // 🌟 変更検知のみ
                        }
                }
                
                Divider()
                
                // Personality editor - 🌟 修正：自動入力処理を削除
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundColor(.pink)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("性格")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("推しの個性を設定")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TextEditor(text: $tempPersonality)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .focused($isInputFocused)
                        .onChange(of: tempPersonality) { _ in
                            detectChanges() // 🌟 変更検知のみ
                        }
                }
                
                Divider()
                
                // Speaking style editor - 🌟 修正：自動入力処理を削除
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
                    
                    TextEditor(text: $tempSpeakingStyle)
                        .frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .focused($isInputFocused)
                        .onChange(of: tempSpeakingStyle) { _ in
                            detectChanges() // 🌟 変更検知のみ
                        }
                }
            }
        }
    }

    // MARK: - User Nickname Settings Section
    private var userNicknameSettingsSection: some View {
        ModernSectionView(title: "あなたの呼び名設定", icon: "person.badge.plus") {
            VStack(spacing: 16) {
                // Nickname input field - 🌟 修正：一時的な値を使用
                ModernSettingRow(
                    icon: "textformat.alt",
                    title: "呼び名"
                ) {
                    TextField("呼び名を入力", text: $tempUserNickname)
                        .textFieldStyle(ModernEditTextFieldStyle())
                        .focused($isInputFocused)
                        .onChange(of: tempUserNickname) { newValue in
                            // 20文字制限
                            if newValue.count > 20 {
                                tempUserNickname = String(newValue.prefix(20))
                            }
                            
                            // 呼び名が入力された場合は自動的にuseNicknameをtrueに設定
                            if !newValue.isEmpty && !tempUseNickname {
                                tempUseNickname = true
                            }
                            // 呼び名が空になった場合は自動的にuseNicknameをfalseに設定
                            else if newValue.isEmpty && tempUseNickname {
                                tempUseNickname = false
                            }
                            
                            detectChanges() // 🌟 変更検知
                        }
                }
            }
        }
    }
    
    // MARK: - Anniversary Settings
    private var anniversarySettingsSection: some View {
        ModernSectionView(title: "記念日設定", icon: "calendar.badge.plus") {
            VStack(spacing: 16) {
                // Birthday setting - 🌟 修正：一時的な値を使用
                ModernSettingRow(
                    icon: "gift",
                    title: "誕生日",
                    subtitle: tempBirthday != nil ? dateFormatter.string(from: tempBirthday!) : "未設定"
                ) {
                    if tempBirthday != nil {
                        DatePicker("", selection: Binding(
                            get: { tempBirthday ?? Date() },
                            set: { newValue in
                                tempBirthday = newValue
                                detectChanges() // 🌟 変更検知
                            }
                        ), displayedComponents: [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    } else {
                        Button("設定") {
                            tempBirthday = Date()
                            detectChanges() // 🌟 変更検知
                        }
                        .buttonStyle(ModernButtonStyle(color: .blue))
                    }
                }
                
                if tempBirthday != nil {
                    Divider()
                    
                    Button {
                        tempBirthday = nil
                        detectChanges() // 🌟 変更検知
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
                
                // Anniversary setting - 🌟 修正：一時的な値を使用
                ModernSettingRow(
                    icon: "heart.circle",
                    title: "記念日",
                    subtitle: tempAnniversaryDate != nil ? dateFormatter.string(from: tempAnniversaryDate!) : "未設定"
                ) {
                    if tempAnniversaryDate != nil {
                        DatePicker("", selection: Binding(
                            get: { tempAnniversaryDate ?? Date() },
                            set: { newValue in
                                tempAnniversaryDate = newValue
                                detectChanges() // 🌟 変更検知
                            }
                        ), displayedComponents: [.date])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    } else {
                        Button("設定") {
                            tempAnniversaryDate = Date()
                            detectChanges() // 🌟 変更検知
                        }
                        .buttonStyle(ModernButtonStyle(color: .pink))
                    }
                }
                
                if tempAnniversaryDate != nil {
                    Divider()
                    
                    Button {
                        tempAnniversaryDate = nil
                        detectChanges() // 🌟 変更検知
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
            tempUserNickname = defaultSuggestion // 🌟 一時的な値を更新
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
    
    // 🔧 修正：アップロード成功時にtempIconURLを設定し、変更検知を行う
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
                    
                    // 🔧 修正：一時的な変数にURLを保存し、変更検知を行う
                    tempIconURL = downloadURL
                    characterIcon = image
                    selectedImage = nil
                    detectChanges() // 🔧 変更検知を追加
                    
                    alertMessage = "アイコンがアップロードされました。保存ボタンを押して設定を完了してください。"
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

// MARK: - ModernEditTextFieldStyle
struct ModernEditTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

// MARK: - ImageEditPickerView
struct ImageEditPickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImageEditPickerView
        
        init(_ parent: ImageEditPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
//    CharacterEditView(viewModel: RomanceAppViewModel())
    TopView()
}
