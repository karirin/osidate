//
//  FloatingChatView.swift
//  osidate
//
//  Created by Apple on 2025/08/12.
//

import SwiftUI

struct SpeechBubbleView: View {
    let message: Message
    let isTyping: Bool
    let primaryColor: Color
    
    @State private var textOpacity: Double = 0
    @State private var bubbleScale: CGFloat = 0.8
    
    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // メッセージ内容（キャラクターからのメッセージのみなので左寄せ）
                    Text(isTyping ? "入力中..." : message.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemGray5), Color(.systemGray6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(20)
                        )
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                        .opacity(textOpacity)
                        .scaleEffect(bubbleScale)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                textOpacity = 1.0
                bubbleScale = 1.0
            }
        }
        .onChange(of: isTyping) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                textOpacity = isTyping ? 0.7 : 1.0
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 吹き出し形状
struct SpeechBubbleShape: Shape {
    enum Direction {
        case left, right
    }
    
    let direction: Direction
    
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let cornerRadius: CGFloat = 20
        let tailSize: CGFloat = 12
        
        var path = Path()
        
        if direction == .left {
            // 左向き（受信メッセージ）の吹き出し
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addQuadCurve(to: CGPoint(x: width, y: cornerRadius), control: CGPoint(x: width, y: 0))
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius - tailSize))
            path.addQuadCurve(to: CGPoint(x: width - cornerRadius, y: height - tailSize), control: CGPoint(x: width, y: height - tailSize))
            path.addLine(to: CGPoint(x: cornerRadius + tailSize, y: height - tailSize))
            
            // 左下の尻尾
            path.addLine(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: cornerRadius, y: height - tailSize))
            
            path.addQuadCurve(to: CGPoint(x: 0, y: height - tailSize - cornerRadius), control: CGPoint(x: 0, y: height - tailSize))
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), control: CGPoint(x: 0, y: 0))
        } else {
            // 右向き（送信メッセージ）の吹き出し
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addQuadCurve(to: CGPoint(x: width, y: cornerRadius), control: CGPoint(x: width, y: 0))
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius - tailSize))
            path.addQuadCurve(to: CGPoint(x: width - cornerRadius, y: height - tailSize), control: CGPoint(x: width, y: height - tailSize))
            
            // 右下の尻尾
            path.addLine(to: CGPoint(x: width, y: height))
            path.addLine(to: CGPoint(x: width - cornerRadius - tailSize, y: height - tailSize))
            
            path.addLine(to: CGPoint(x: cornerRadius, y: height - tailSize))
            path.addQuadCurve(to: CGPoint(x: 0, y: height - tailSize - cornerRadius), control: CGPoint(x: 0, y: height - tailSize))
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), control: CGPoint(x: 0, y: 0))
        }
        
        return path
    }
}

// MARK: - チャット表示モード切り替え用の列挙型
enum ChatDisplayMode: String, CaseIterable {
    case traditional = "traditional"
    case floating = "floating"
    
    var displayName: String {
        switch self {
        case .traditional: return "LINE形式"
        case .floating: return "吹き出し形式"
        }
    }
    
    var icon: String {
        switch self {
        case .traditional: return "message.fill"
        case .floating: return "bubble.left.and.bubble.right.fill"
        }
    }
}

// MARK: - ContentViewでの統合用拡張
extension ContentView {
    // チャット表示モードの切り替えボタンを追加する場合
    private var chatModeToggleButton: some View {
        Button(action: {
            // ChatDisplayModeの状態管理を追加する必要があります
        }) {
            Image(systemName: "arrow.2.squarepath")
                .font(.title3)
//                .foregroundColor(primaryColor)
        }
    }
}
