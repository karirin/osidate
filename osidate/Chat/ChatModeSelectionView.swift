//
//  ChatModeSelectionView.swift
//  osidate
//
//  Created by Apple on 2025/08/12.
//  Updated with modern UI/UX design
//

import SwiftUI

struct ChatModeSelectionView: View {
    @Binding var selectedMode: ChatDisplayMode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation States
    @State private var headerAppeared = false
    @State private var cardsAppeared = false
    @State private var backgroundAnimation = false
    
    // Design Constants
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F093FB"), Color(hex: "F5576C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Animated Background
                animatedBackground
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        // Header Section
                        headerSection
                            .opacity(headerAppeared ? 1 : 0)
                            .offset(y: headerAppeared ? 0 : 30)
                        
                        // Mode Cards
                        VStack(spacing: 20) {
                            ForEach(Array(ChatDisplayMode.allCases.enumerated()), id: \.element) { index, mode in
                                ModernChatModeCard(
                                    mode: mode,
                                    isSelected: selectedMode == mode,
                                    primaryGradient: primaryGradient,
                                    onSelect: {
                                        selectMode(mode)
                                    }
                                )
                                .opacity(cardsAppeared ? 1 : 0)
                                .offset(y: cardsAppeared ? 0 : 50)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.15 + 0.3),
                                    value: cardsAppeared
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Hint Text
                        hintSection
                            .opacity(cardsAppeared ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.6), value: cardsAppeared)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        hapticFeedback(.light)
                        dismiss()
                    } label: {
                        Text("完了")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(primaryGradient)
                    }
                }
            }
            .onAppear {
                startAnimations()
            }
        }
    }
    
    // MARK: - Animated Background
    private var animatedBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "0D0D0D"), Color(hex: "1A1A2E"), Color(hex: "16213E")]
                    : [Color(hex: "F8F9FA"), Color(hex: "E9ECEF"), Color(hex: "DEE2E6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Floating orbs
            Circle()
                .fill(Color(hex: "667EEA").opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(
                    x: backgroundAnimation ? 50 : -50,
                    y: backgroundAnimation ? -100 : -150
                )
            
            Circle()
                .fill(Color(hex: "F093FB").opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(
                    x: backgroundAnimation ? -80 : 80,
                    y: backgroundAnimation ? 200 : 250
                )
            
            Circle()
                .fill(Color(hex: "764BA2").opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(
                    x: backgroundAnimation ? 100 : 50,
                    y: backgroundAnimation ? 100 : 50
                )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: backgroundAnimation)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Icon with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(primaryGradient)
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                    .opacity(0.5)
                
                // Icon container
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .stroke(primaryGradient, lineWidth: 2)
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(primaryGradient)
                }
            }
            
            VStack(spacing: 12) {
                Text("表示形式を選択")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("お好みのチャットスタイルで\nキャラクターとの会話をお楽しみください")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Hint Section
    private var hintSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text("設定はいつでも変更できます")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Actions
    private func selectMode(_ mode: ChatDisplayMode) {
        hapticFeedback(.medium)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            selectedMode = mode
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    private func startAnimations() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            headerAppeared = true
        }
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
            cardsAppeared = true
        }
        
        backgroundAnimation = true
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Modern Chat Mode Card
struct ModernChatModeCard: View {
    let mode: ChatDisplayMode
    let isSelected: Bool
    let primaryGradient: LinearGradient
    let onSelect: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? primaryGradient : LinearGradient(colors: [Color.gray.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: mode.icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode.displayName)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isSelected {
                        Circle()
                            .fill(primaryGradient)
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardBackground)
                    .shadow(
                        color: isSelected
                            ? Color(hex: "667EEA").opacity(0.3)
                            : Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                        radius: isSelected ? 20 : 12,
                        x: 0,
                        y: isSelected ? 10 : 6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isSelected ? primaryGradient : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
            )
            .scaleEffect(isPressed ? 0.97 : (isSelected ? 1.02 : 1.0))
        }
        .buttonStyle(PlainButtonStyle())
        .pressEvents(onPress: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
        }, onRelease: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = false
            }
        })
    }
}

// MARK: - ChatDisplayMode Extension
extension ChatDisplayMode {
    var description: String {
        switch self {
        case .traditional:
            return "LINEのように横並びでメッセージが表示される形式"
        case .floating:
            return "キャラクターの周りに吹き出しが表示される形式"
        }
    }
}

// MARK: - Press Events Modifier
struct PressActions: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressActions(onPress: onPress, onRelease: onRelease))
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ChatModeSelectionView(selectedMode: .constant(.traditional))
}
