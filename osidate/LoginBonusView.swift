//
//  LoginBonusView.swift
//  osidate
//
//  受け取り済みボーナス表示対応版
//

import SwiftUI

struct LoginBonusView: View {
    @ObservedObject var loginBonusManager: LoginBonusManager
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var animationOffset: CGFloat = -200
    @State private var animationOpacity: Double = 0
    @State private var celebrationAnimation = false
    @State private var showingConfetti = false
    
    private var isSmallScreen: Bool { UIScreen.main.bounds.height <= 667 }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6)
    }
    
    // 🌟 表示するボーナス（受け取り済みまたは利用可能）
    private var displayBonus: LoginBonus? {
        if let availableBonus = loginBonusManager.availableBonus {
            return availableBonus
        } else if let lastBonus = loginBonusManager.loginHistory.first {
            return lastBonus
        }
        return nil
    }
    
    // 🌟 既に受け取り済みかどうか
    private var isAlreadyClaimed: Bool {
        return loginBonusManager.availableBonus == nil
    }
    
    var body: some View {
        ZStack {
            // 背景
            backgroundView
            
            // メインコンテンツ
            if let bonus = displayBonus {
                bonusContentView(bonus: bonus)
            } else {
                noBonusView
            }
            
            // 紙吹雪エフェクト
            if showingConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startBonusAnimation()
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            // グラデーション背景
            LinearGradient(
                colors: [
                    backgroundColor,
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.1),
                    Color.pink.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // アニメーション背景
            ForEach(0..<20) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: CGFloat.random(in: 20...50))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .scaleEffect(celebrationAnimation ? 1.2 : 0.8)
                    .opacity(celebrationAnimation ? 0.7 : 0.3)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2)),
                        value: celebrationAnimation
                    )
            }
        }
    }
    
    // MARK: - Bonus Content View
    private func bonusContentView(bonus: LoginBonus) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // メインボーナスカード
            mainBonusCard(bonus: bonus)
                .offset(y: animationOffset)
                .opacity(animationOpacity)
            
            Spacer()
            
            // ボタンエリア
            buttonArea(bonus: bonus)
                .offset(y: animationOffset * 0.5)
                .opacity(animationOpacity)
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Main Bonus Card
    private func mainBonusCard(bonus: LoginBonus) -> some View {
        VStack(spacing: 32) {
            // ヘッダー
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [bonus.bonusType.color.opacity(0.3), bonus.bonusType.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isSmallScreen ? 60 : 120, height: isSmallScreen ? 60 : 120)
                        .scaleEffect(celebrationAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: celebrationAnimation)
                    
                    Image(systemName: bonus.bonusType.icon)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(bonus.bonusType.color)
                        .scaleEffect(celebrationAnimation ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: celebrationAnimation)
                }
                
                VStack(spacing: 8) {
                    // 🌟 受け取り済みかどうかでタイトルを変更
                    Text(isAlreadyClaimed ? "ログインボーナス受け取り済み" : "ログインボーナス")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text("\(bonus.day)日目")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(bonus.bonusType.color)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(bonus.bonusType.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(bonus.bonusType.color)
                    }
                }
            }
            
            // ボーナス詳細
            VStack(spacing: 20) {
                // 親密度ボーナス
                VStack(spacing: 12) {
                    Text("親密度ボーナス")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.title)
                            .foregroundColor(.pink)
                        
                        Text("+\(bonus.intimacyBonus)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(bonus.bonusType.color)
                    }
                    .scaleEffect(celebrationAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: celebrationAnimation)
                }
                
                // メッセージ
                Text(bonus.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .lineSpacing(4)
                
                // 🌟 受け取り済みの場合は受け取り時刻を表示
                if isAlreadyClaimed {
                    Text("受け取り日時: \(DateFormatter.loginBonusFormatter.string(from: bonus.receivedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            // 連続ログイン情報
            loginStreakInfo
        }
        .padding(isSmallScreen ? 10 : 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: bonus.bonusType.color.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [bonus.bonusType.color.opacity(0.5), bonus.bonusType.color.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
    
    // MARK: - Login Streak Info
    private var loginStreakInfo: some View {
        VStack(spacing: 12) {
            Text("ログイン状況")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 24) {
                InfoBadge(
                    icon: "flame.fill",
                    title: "連続ログイン",
                    value: "\(loginBonusManager.currentStreak)日",
                    color: .orange
                )
                
                InfoBadge(
                    icon: "calendar.badge.plus",
                    title: "累計ログイン",
                    value: "\(loginBonusManager.totalLoginDays)日",
                    color: .green
                )
                
                InfoBadge(
                    icon: "heart.circle.fill",
                    title: "獲得親密度",
                    value: "+\(loginBonusManager.getTotalIntimacyFromBonuses())",
                    color: .pink
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Button Area
    private func buttonArea(bonus: LoginBonus) -> some View {
        VStack(spacing: 16) {
            if isAlreadyClaimed {
                // 受け取り済みの場合は閉じるボタンのみ
                Button("閉じる") {
                    dismiss()
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(bonus.bonusType.color)
                .cornerRadius(16)
                .shadow(color: bonus.bonusType.color.opacity(0.4), radius: 12, x: 0, y: 6)
            } else {
                // 未受け取りの場合は受け取りボタン
                Button(action: {
                    claimBonus(bonus)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gift.fill")
                            .font(.title2)
                        
                        Text("ボーナスを受け取る")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical,isSmallScreen ? 12 : 18)
                    .background(
                        LinearGradient(
                            colors: [bonus.bonusType.color, bonus.bonusType.color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: bonus.bonusType.color.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .scaleEffect(celebrationAnimation ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: celebrationAnimation)
                
                Button("後で受け取る") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - No Bonus View
    private var noBonusView: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.green)
            
            VStack(spacing: 16) {
                Text("本日のボーナス受取済み")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("明日もログインして\n新しいボーナスを受け取りましょう！")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button("閉じる") {
                dismiss()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .cornerRadius(16)
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    
    private func startBonusAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
            animationOffset = 0
            animationOpacity = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            celebrationAnimation = true
            showingConfetti = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showingConfetti = false
        }
    }
    
    private func claimBonus(_ bonus: LoginBonus) {
        // ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // ボーナス受取処理
        loginBonusManager.claimBonus { intimacyBonus, reason in
            viewModel.increaseIntimacy(by: intimacyBonus, reason: reason)
        }
        
        // 画面を閉じる
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct InfoBadge: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let loginBonusFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// MARK: - 既存のConfettiView等はそのまま保持
struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<50) { index in
                ConfettiPiece(
                    color: [Color.red, Color.blue, Color.green, Color.yellow, Color.purple, Color.pink].randomElement() ?? Color.blue,
                    delay: Double.random(in: 0...2)
                )
                .opacity(animate ? 1 : 0)
                .animation(.easeOut(duration: 3).delay(Double.random(in: 0...2)), value: animate)
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let delay: Double
    
    @State private var location = CGPoint(
        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
        y: -50
    )
    @State private var rotation: Double = 0
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 10, height: 10)
            .rotationEffect(.degrees(rotation))
            .position(location)
            .onAppear {
                withAnimation(.easeOut(duration: 3).delay(delay)) {
                    location.y = UIScreen.main.bounds.height + 50
                }
                
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false).delay(delay)) {
                    rotation = 360
                }
            }
    }
}

struct LoginBonusView_Previews: PreviewProvider {
    static var previews: some View {
        let mockBonus = LoginBonus(
            day: 3,
            intimacyBonus: 150,
            bonusType: .special, // ← enumに合わせて適宜変更
            description: "特別なログインボーナス！"
        )
        
        let mockManager = LoginBonusManager()
        mockManager.availableBonus = mockBonus
        mockManager.currentStreak = 5
        mockManager.totalLoginDays = 12
        mockManager.loginHistory = [mockBonus]
        
        let mockViewModel = RomanceAppViewModel()
        
        return LoginBonusView(
            loginBonusManager: mockManager,
            viewModel: mockViewModel
        )
    }
}
