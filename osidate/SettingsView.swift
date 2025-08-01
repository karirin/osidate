//
//  SettingsView.swift
//  osidate
//
//  Updated for Firebase Auth integration
//

import SwiftUI
import Foundation

struct SettingsView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingResetIntimacyAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingResetUserDefaultsAlert = false
    @State private var isDataSyncing = false
    
    var body: some View {
        NavigationView {
            Form {
                // アカウント情報セクション
                accountInfoSection
                
                // キャラクター設定セクション
                characterSettingsSection
                
                // 記念日設定セクション
                anniversarySettingsSection
                
                // 親密度情報セクション
                intimacyInfoSection
                
                // 統計情報セクション
                statisticsSection
                
                // データ管理セクション
                dataManagementSection
                
                // 危険な操作セクション
                dangerZoneSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .alert("データを削除", isPresented: $showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    viewModel.clearAllData()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("すべての会話データとローカルデータが削除されます。この操作は取り消せません。")
            }
            .alert("親密度をリセット", isPresented: $showingResetIntimacyAlert) {
                Button("リセット", role: .destructive) {
                    viewModel.resetIntimacyLevel()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("親密度が0にリセットされます。メッセージは保持されます。")
            }
            .alert("ログアウト", isPresented: $showingSignOutAlert) {
                Button("ログアウト", role: .destructive) {
                    viewModel.signOut()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("ログアウトしますか？再度ログインが必要になります。")
            }
            .alert("UserDefaultsをリセット", isPresented: $showingResetUserDefaultsAlert) {
                Button("リセット", role: .destructive) {
                    viewModel.resetUserDefaults()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("保存されたキャラクターIDがリセットされます。次回起動時に新しいキャラクターが作成されます。")
            }
        }
    }
    
    private var accountInfoSection: some View {
        Section("アカウント情報") {
            if let userID = viewModel.currentUserID {
                HStack {
                    Text("ユーザーID")
                    Spacer()
                    Text("\(String(userID.prefix(8)))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("アカウントタイプ")
                    Spacer()
                    HStack {
                        if viewModel.isAnonymousUser {
                            Image(systemName: "person.crop.circle.dashed")
                                .foregroundColor(.orange)
                            Text("ゲスト")
                                .foregroundColor(.orange)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.green)
                            Text("登録済み")
                                .foregroundColor(.green)
                        }
                    }
                    .font(.caption)
                }
                
                if viewModel.isAnonymousUser {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ゲストアカウントについて")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text("• データは自動保存されます\n• アプリ削除時にデータが失われる可能性があります")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var characterSettingsSection: some View {
            Section("キャラクター設定") {
                // アイコン設定
                NavigationLink(destination: CharacterIconEditorView(viewModel: viewModel)) {
                    HStack {
                        Text("アイコン")
                        Spacer()
                        CharacterIconView(character: viewModel.character, size: 40)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("名前")
                    Spacer()
                    TextField("キャラクター名", text: $viewModel.character.name)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: viewModel.character.name) { _ in
                            viewModel.updateCharacterSettings()
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("性格")
                        .font(.headline)
                    TextEditor(text: $viewModel.character.personality)
                        .frame(minHeight: 60)
                        .onChange(of: viewModel.character.personality) { _ in
                            viewModel.updateCharacterSettings()
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("話し方")
                        .font(.headline)
                    TextEditor(text: $viewModel.character.speakingStyle)
                        .frame(minHeight: 60)
                        .onChange(of: viewModel.character.speakingStyle) { _ in
                            viewModel.updateCharacterSettings()
                        }
                }
            }
        }
    
    private var anniversarySettingsSection: some View {
        Section("記念日設定") {
            HStack {
                Text("誕生日")
                Spacer()
                if viewModel.character.birthday != nil {
                    DatePicker("", selection: Binding(
                        get: { viewModel.character.birthday ?? Date() },
                        set: { newValue in
                            viewModel.character.birthday = newValue
                            viewModel.updateCharacterSettings()
                        }
                    ), displayedComponents: [.date])
                    .labelsHidden()
                } else {
                    Button("設定") {
                        viewModel.character.birthday = Date()
                        viewModel.updateCharacterSettings()
                    }
                }
            }
            
            if viewModel.character.birthday != nil {
                Button("誕生日を削除", role: .destructive) {
                    viewModel.character.birthday = nil
                    viewModel.updateCharacterSettings()
                }
            }
            
            HStack {
                Text("記念日")
                Spacer()
                if viewModel.character.anniversaryDate != nil {
                    DatePicker("", selection: Binding(
                        get: { viewModel.character.anniversaryDate ?? Date() },
                        set: { newValue in
                            viewModel.character.anniversaryDate = newValue
                            viewModel.updateCharacterSettings()
                        }
                    ), displayedComponents: [.date])
                    .labelsHidden()
                } else {
                    Button("設定") {
                        viewModel.character.anniversaryDate = Date()
                        viewModel.updateCharacterSettings()
                    }
                }
            }
            
            if viewModel.character.anniversaryDate != nil {
                Button("記念日を削除", role: .destructive) {
                    viewModel.character.anniversaryDate = nil
                    viewModel.updateCharacterSettings()
                }
            }
        }
    }
    
    private var intimacyInfoSection: some View {
        Section("親密度情報") {
            HStack {
                Text("現在の親密度")
                Spacer()
                Text("\(viewModel.character.intimacyLevel)")
                    .fontWeight(.bold)
            }
            
            HStack {
                Text("関係レベル")
                Spacer()
                Text(viewModel.character.intimacyTitle)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("進捗")
                    Spacer()
                    Text("\(viewModel.character.intimacyLevel)/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: Double(min(viewModel.character.intimacyLevel, 100)), total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: intimacyColor))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("解放されたデート場所")
                    .font(.headline)
                ForEach(viewModel.availableLocations, id: \.id) { location in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(location.name)
                        Spacer()
                        Text("必要親密度: \(location.requiredIntimacy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var statisticsSection: some View {
        Section("統計情報") {
            HStack {
                Text("総メッセージ数")
                Spacer()
                Text("\(viewModel.getMessageCount())")
                    .fontWeight(.bold)
            }
            
            HStack {
                Text("あなたのメッセージ")
                Spacer()
                Text("\(viewModel.getUserMessageCount())")
                    .foregroundColor(.blue)
            }
            
            HStack {
                Text("\(viewModel.character.name)のメッセージ")
                Spacer()
                Text("\(viewModel.getAIMessageCount())")
                    .foregroundColor(.pink)
            }
            
            if let firstMessage = viewModel.messages.first {
                HStack {
                    Text("会話開始日")
                    Spacer()
                    Text(dateFormatter.string(from: firstMessage.timestamp))
                        .foregroundColor(.secondary)
                }
            }
            
            if let lastMessage = viewModel.messages.last {
                HStack {
                    Text("最後のメッセージ")
                    Spacer()
                    Text(relativeDateFormatter.localizedString(for: lastMessage.timestamp, relativeTo: Date()))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("会話継続日数")
                Spacer()
                Text("\(viewModel.getTotalConversationDays())日")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("1日平均メッセージ数")
                Spacer()
                Text(String(format: "%.1f", viewModel.getAverageMessagesPerDay()))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var dataManagementSection: some View {
        Section("データ管理") {
            Button(action: {
                isDataSyncing = true
                viewModel.updateCharacterSettings()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isDataSyncing = false
                }
            }) {
                HStack {
                    if isDataSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                    Text("データを同期")
                }
            }
            .foregroundColor(.blue)
            .disabled(isDataSyncing)
            
            Button("親密度をリセット") {
                showingResetIntimacyAlert = true
            }
            .foregroundColor(.orange)
            
            Button("キャラクター設定をリセット") {
                showingResetUserDefaultsAlert = true
            }
            .foregroundColor(.orange)
        }
    }
    
    private var dangerZoneSection: some View {
        Section("危険な操作") {
            if viewModel.isAnonymousUser {
                Button("ログアウト（ゲスト終了）") {
                    showingSignOutAlert = true
                }
                .foregroundColor(.orange)
            } else {
                Button("ログアウト") {
                    showingSignOutAlert = true
                }
                .foregroundColor(.orange)
            }
            
            Button("すべてのデータを削除") {
                showingDeleteAlert = true
            }
            .foregroundColor(.red)
        }
    }
    
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
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateTimeStyle = .named
        return formatter
    }
}

#Preview {
    SettingsView(viewModel: RomanceAppViewModel())
}
