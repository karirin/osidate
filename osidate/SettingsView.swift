//
//  SettingsView.swift
//  osidate
//
//  Updated for Firebase integration
//

import SwiftUI
import Foundation

// MARK: - 設定ビュー
struct SettingsView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("キャラクター設定") {
                    TextField("名前", text: $viewModel.character.name)
                        .onChange(of: viewModel.character.name) { _ in
                            viewModel.updateCharacterSettings()
                        }
                    
                    TextField("性格", text: $viewModel.character.personality)
                        .onChange(of: viewModel.character.personality) { _ in
                            viewModel.updateCharacterSettings()
                        }
                    
                    TextField("話し方", text: $viewModel.character.speakingStyle)
                        .onChange(of: viewModel.character.speakingStyle) { _ in
                            viewModel.updateCharacterSettings()
                        }
                }
                
                Section("記念日設定") {
                    DatePicker("誕生日", selection: Binding(
                        get: { viewModel.character.birthday ?? Date() },
                        set: { newValue in
                            viewModel.character.birthday = newValue
                            viewModel.updateCharacterSettings()
                        }
                    ), displayedComponents: [.date])
                    
                    DatePicker("記念日", selection: Binding(
                        get: { viewModel.character.anniversaryDate ?? Date() },
                        set: { newValue in
                            viewModel.character.anniversaryDate = newValue
                            viewModel.updateCharacterSettings()
                        }
                    ), displayedComponents: [.date])
                }
                
                Section("親密度") {
                    HStack {
                        Text("現在の親密度")
                        Spacer()
                        Text("\(viewModel.character.intimacyLevel)")
                    }
                    
                    Text("レベル: \(viewModel.character.intimacyTitle)")
                        .foregroundColor(.secondary)
                }
                
                Section("データ管理") {
                    Button("データを同期") {
                        // 手動同期機能（必要に応じて）
                        viewModel.updateCharacterSettings()
                    }
                    .foregroundColor(.blue)
                }
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
        }
    }
}

#Preview {
    SettingsView(viewModel: RomanceAppViewModel())
}
