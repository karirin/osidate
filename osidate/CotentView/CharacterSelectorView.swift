//
//  CharacterSelectorView.swift
//  osidate
//
//  Created by Apple on 2025/08/11.
//

import SwiftUI
import Foundation
import FirebaseDatabase
import FirebaseAuth

struct CharacterSelectorView: View {
    @ObservedObject var characterRegistry: CharacterRegistry
    @Binding var selectedCharacterId: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddCharacter = false
    @State private var showingDeleteConfirmation = false
    @State private var characterToDelete: Character?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if characterRegistry.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if characterRegistry.characters.isEmpty {
                    emptyStateView
                } else {
                    characterListView
                }
            }
            .navigationTitle("推しを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCharacter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCharacter) {
                AddCharacterView(characterRegistry: characterRegistry)
            }
            .alert("キャラクターを削除", isPresented: $showingDeleteConfirmation) {
                Button("削除", role: .destructive) {
                    if let character = characterToDelete {
                        characterRegistry.deleteCharacter(character)
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                if let character = characterToDelete {
                    Text("「\(character.name)」を削除しますか？この操作は取り消せません。")
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("推しがいません")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("右上の + ボタンから新しい推しを追加してください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("推しを追加") {
                showingAddCharacter = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var characterListView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 16), count: 2), spacing: 16) {
                ForEach(characterRegistry.characters) { character in
                    CharacterCardView(
                        character: character,
                        isSelected: character.id == selectedCharacterId,
                        onSelect: {
                            selectedCharacterId = character.id
                            characterRegistry.setActiveCharacter(character.id)
                            dismiss()
                        },
                        onDelete: {
                            characterToDelete = character
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(20)
        }
    }
}

struct CharacterCardView: View {
    let character: Character
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                // Character Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? .blue.opacity(0.2) : .gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    if let iconURL = character.iconURL,
                       let url = URL(string: iconURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                        } placeholder: {
                            Circle()
                                .fill(.gray.opacity(0.3))
                                .frame(width: 70, height: 70)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        }
                    } else {
                        Image(systemName: character.iconName)
                            .font(.system(size: 35))
                            .foregroundColor(isSelected ? .blue : .primary)
                    }
                    
                    if isSelected {
                        Circle()
                            .stroke(.blue, lineWidth: 3)
                            .frame(width: 80, height: 80)
                    }
                }
                
                // Character Info
                VStack(spacing: 4) {
                    Text(character.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Lv.\(character.intimacyLevel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(character.intimacyTitle)
                        .font(.caption2)
                        .foregroundColor(character.intimacyStage.color)
                        .lineLimit(1)
                }
                
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("選択中")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .overlay(
                // Delete button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                                .background(Circle().fill(.white))
                        }
                        .offset(x: 8, y: -8)
                    }
                    Spacer()
                }
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        // 🔧 修正: onLongPressGesture の正しい構文
        .onTapGesture {
            // タップ時のフィードバック
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            onSelect()
        }
    }
}

// MARK: - Add Character View
struct AddCharacterView: View {
    @ObservedObject var characterRegistry: CharacterRegistry
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var personality = ""
    @State private var speakingStyle = ""
    @State private var isCreating = false
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !personality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本情報") {
                    TextField("推しの名前", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("性格") {
                    TextEditor(text: $personality)
                        .frame(minHeight: 80)
                    
                    Text("例：優しくて思いやりがある、明るくて元気")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("話し方") {
                    TextEditor(text: $speakingStyle)
                        .frame(minHeight: 80)
                    
                    Text("例：丁寧で温かい、フレンドリーで親しみやすい")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("推しを作成") {
                        createCharacter()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid || isCreating)
                    .foregroundColor(isFormValid ? .white : .gray)
                    .padding()
                    .background(isFormValid ? .blue : .gray.opacity(0.3))
                    .cornerRadius(8)
                }
            }
            .navigationTitle("新しい推しを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .disabled(isCreating)
            .overlay(
                Group {
                    if isCreating {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("推しを作成中...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding(32)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                    }
                }
            )
        }
    }
    
    private func createCharacter() {
        isCreating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let newCharacter = characterRegistry.createNewCharacter(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                personality: personality.trimmingCharacters(in: .whitespacesAndNewlines),
                speakingStyle: speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            characterRegistry.setActiveCharacter(newCharacter.id)
            isCreating = false
            dismiss()
        }
    }
}
