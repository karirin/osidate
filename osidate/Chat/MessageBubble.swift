//
//  MessageBubble.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//  Updated with modern UI/UX design
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme
    
    // Design Constants
    private var userBubbleGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var aiBubbleBackground: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: "2C2C2E"))
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 50)
                userMessageBubble
            } else {
                aiMessageBubble
                Spacer(minLength: 50)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : (message.isFromUser ? 30 : -30))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
    }
    
    // MARK: - User Message Bubble
    private var userMessageBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Message content
            Text(message.text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    MessageBubbleShape(isFromUser: true)
                        .fill(userBubbleGradient)
                        .shadow(
                            color: Color(hex: "667EEA").opacity(0.35),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                )
            
            // Metadata
            HStack(spacing: 10) {
                if let location = message.dateLocation {
                    locationBadge(location)
                }
                
                timestampText(message.timestamp)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
    }
    
    // MARK: - AI Message Bubble
    private var aiMessageBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message content
            Text(message.text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    MessageBubbleShape(isFromUser: false)
                        .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                )
            
            // Metadata
            HStack(spacing: 10) {
                timestampText(message.timestamp)
                
                if let location = message.dateLocation {
                    locationBadge(location)
                }
                
                // Intimacy gained badge
                if message.intimacyGained > 0 {
                    intimacyBadge(message.intimacyGained)
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
    }
    
    // MARK: - Supporting Views
    private func locationBadge(_ location: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.system(size: 9))
            Text(location)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "F2F2F7"))
        )
    }
    
    private func timestampText(_ date: Date) -> some View {
        Text(timeString(from: date))
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
    }
    
    private func intimacyBadge(_ value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9))
            Text("+\(value)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(Color(hex: "F093FB"))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(hex: "F093FB").opacity(0.15))
        )
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Custom Message Bubble Shape
struct MessageBubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 24
        let tailSize: CGFloat = 6
        
        var path = Path()
        
        if isFromUser {
            // User message: tail on bottom-right
            path.addRoundedRect(
                in: CGRect(x: 0, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
                style: .continuous
            )
            
            // Tail
            path.move(to: CGPoint(x: rect.width - tailSize - 10, y: rect.height - 8))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: rect.height),
                control: CGPoint(x: rect.width - tailSize, y: rect.height)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.width - tailSize - 2, y: rect.height - 2),
                control: CGPoint(x: rect.width - tailSize - 4, y: rect.height - 1)
            )
        } else {
            // AI message: tail on bottom-left
            path.addRoundedRect(
                in: CGRect(x: tailSize, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
                style: .continuous
            )
            
            // Tail
            path.move(to: CGPoint(x: tailSize + 10, y: rect.height - 8))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.height),
                control: CGPoint(x: tailSize, y: rect.height)
            )
            path.addQuadCurve(
                to: CGPoint(x: tailSize + 2, y: rect.height - 2),
                control: CGPoint(x: tailSize + 4, y: rect.height - 1)
            )
        }
        
        return path
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        MessageBubble(message: Message(
            id: UUID(),
            text: "こんにちは！今日はどんな一日だった？",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: "カフェ",
            intimacyGained: 5
        ))
        
        MessageBubble(message: Message(
            id: UUID(),
            text: "とても良い一日だったよ！君と話せて嬉しい",
            isFromUser: true,
            timestamp: Date(),
            dateLocation: nil,
            intimacyGained: 0
        ))
    }
    .padding()
    .background(Color(hex: "F8F9FA"))
}
