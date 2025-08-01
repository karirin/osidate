//
//  TestView.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
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
                    TextField("性格", text: $viewModel.character.personality)
                    TextField("話し方", text: $viewModel.character.speakingStyle)
                }
                
                Section("記念日設定") {
                    DatePicker("誕生日", selection: Binding(
                        get: { viewModel.character.birthday ?? Date() },
                        set: { viewModel.character.birthday = $0 }
                    ), displayedComponents: [.date])
                    
                    DatePicker("記念日", selection: Binding(
                        get: { viewModel.character.anniversaryDate ?? Date() },
                        set: { viewModel.character.anniversaryDate = $0 }
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
