//
//  ChatModeSelectionView.swift
//  osidate
//
//  Created by Apple on 2025/08/12.
//

import SwiftUI

struct ChatModeSelectionView: View {
    @Binding var selectedMode: ChatDisplayMode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.blue)
                    
                    Text("チャット表示形式を選択")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("お好みの表示形式でキャラクターとの会話をお楽しみください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    ForEach(ChatDisplayMode.allCases, id: \.self) { mode in
                        ChatModeCard(
                            mode: mode,
                            isSelected: selectedMode == mode,
                            onSelect: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedMode = mode
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    dismiss()
                                }
                            }
                        )
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("表示形式")
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

struct ChatModeCard: View {
    let mode: ChatDisplayMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .blue.opacity(0.2) : .gray.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: mode.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .blue : .gray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(mode == .traditional ? "横並びでメッセージが表示される従来の形式" : "中央のキャラクターアイコンから吹き出しが表示される形式")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(isSelected ? Color.blue.opacity(0.05) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
            )
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
