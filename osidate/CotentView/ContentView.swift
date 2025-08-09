//
//  ContentView.swift - Modern UI Design (Keyboard Enhanced)
//  osidate
//
//  Enhanced with keyboard-aware scrolling like OshiAIChatView
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @State private var showFloatingIcon = false
    @State private var pulseAnimation = false
    @State private var messageText = ""
    @State private var iconOffset: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var backgroundBlur: CGFloat = 0
    @State private var headerOpacity: Double = 1.0
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    // Design Constants
    private let cardCornerRadius: CGFloat = 20
    private let primaryColor = Color(.systemBlue)
    private let accentColor = Color(.systemPurple)
    
    var body: some View {
        ZStack {
            Group {
                if viewModel.isLoading {
                    ModernLoadingView()
                } else if viewModel.isAuthenticated {
                    MainAppView()
                } else {
                    ModernAuthenticationView()
                }
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                if isInputFocused {
                    isInputFocused = false
                }
            }
        )
        .sheet(isPresented: $viewModel.showingBackgroundSelector) {
            BackgroundSelectorView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingDateSelector) {
            DateSelectorView(viewModel: viewModel)
        }
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = height
            }
        }
    }
    
    // MARK: - Modern Loading View
    private func ModernLoadingView() -> some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    primaryColor.opacity(0.1),
                    accentColor.opacity(0.1),
                    Color(.systemPink).opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .hueRotation(.degrees(backgroundBlur * 10))
            .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: backgroundBlur)
            
            VStack(spacing: 30) {
                // Custom loading animation
                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor, accentColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 20)
                            .scaleEffect(showFloatingIcon ? 1.2 : 0.8)
                            .opacity(showFloatingIcon ? 0.8 : 0.4)
                            .offset(x: CGFloat(index - 1) * 30)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: showFloatingIcon
                            )
                    }
                }
                .onAppear {
                    showFloatingIcon = true
                }
                
                VStack(spacing: 12) {
                    Text("アプリを初期化中...")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("あなたの特別な時間を準備しています")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    // MARK: - Modern Authentication View
    private func ModernAuthenticationView() -> some View {
        ZStack {
            // Dynamic background
            LinearGradient(
                colors: [
                    Color(.systemPink).opacity(0.15),
                    Color(.systemBlue).opacity(0.15),
                    Color(.systemPurple).opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 50) {
                    Spacer(minLength: 60)
                    
                    // Hero section
                    VStack(spacing: 25) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.pink.opacity(0.3), Color.blue.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                            
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 80, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.pink, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .onAppear {
                            pulseAnimation = true
                        }
                        
                        VStack(spacing: 12) {
                            Text("おかえりなさい")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, .secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("あなたの特別なパートナーが\n心を込めてお待ちしています")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }
                    
                    // Authentication button
                    VStack(spacing: 20) {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                viewModel.signInAnonymously()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                
                                Text("ゲストとして始める")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [primaryColor, primaryColor.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: primaryColor.opacity(0.3), radius: 12, x: 0, y: 8)
                            )
                        }
                        .disabled(viewModel.isLoading)
                        .scaleEffect(viewModel.isLoading ? 0.95 : 1.0)
                        .opacity(viewModel.isLoading ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
                        
                        if viewModel.isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(primaryColor)
                                
                                Text("認証中...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    // Information card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(accentColor)
                            
                            Text("ゲストアカウントについて")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(icon: "checkmark.circle.fill",
                                   text: "データは自動的に保存されます",
                                   color: .green)
                            InfoRow(icon: "exclamationmark.triangle.fill",
                                   text: "アプリを削除するとデータは失われます",
                                   color: .orange)
                            InfoRow(icon: "arrow.triangle.2.circlepath",
                                   text: "将来的にアカウント移行機能を提供予定",
                                   color: .blue)
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(cardCornerRadius)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Main App View
    private func MainAppView() -> some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Enhanced background with blur effect
                    backgroundView(geometry: geometry)
                        .blur(radius: backgroundBlur)
                    
                    VStack(spacing: 0) {
                        // Date status
                        if viewModel.currentDateSession != nil {
                            modernDateStatusView
                        }
                        
                        // Floating character icon
                        modernFloatingIconView
                        
                        // Enhanced chat area - キーボード対応版
                        modernChatView
                        
                        // Modern input area - キーボード対応版
                        modernInputView
                            .padding(.bottom, keyboardHeight > 0 ? 0 : 8)
                    }
                }
            }
            .clipped()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Enhanced Background View
    private func backgroundView(geometry: GeometryProxy) -> some View {
        Group {
            if let urlStr = viewModel.character.backgroundURL,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .edgesIgnoringSafeArea(.all)
                    default:
                        defaultBackgroundImage(geometry: geometry)
                    }
                }
            } else {
                defaultBackgroundImage(geometry: geometry)
            }
        }
        .ignoresSafeArea()
        .overlay(
            // Dynamic overlay for better readability
            LinearGradient(
                colors: [
                    Color.black.opacity(0.1),
                    Color.clear,
                    Color.black.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: 0.5), value: viewModel.character.backgroundName)
    }
    
    private func defaultBackgroundImage(geometry: GeometryProxy) -> some View {
        Image(viewModel.character.backgroundName)
            .resizable()
            .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - Modern Date Status View
    private var modernDateStatusView: some View {
        Group {
            if let session = viewModel.currentDateSession {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: session.location.type.icon)
                            .font(.title2)
                            .foregroundColor(session.location.type.color)
                            .frame(width: 40, height: 40)
                            .background(session.location.type.color.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(session.location.name)でデート中")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("開始: \(DateFormatter.localizedString(from: session.startTime, dateStyle: .none, timeStyle: .short))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("終了") {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                viewModel.endDate()
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.red, in: Capsule())
                        .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    // Date progress indicator
                    HStack(spacing: 16) {
                        Label("\(session.messagesExchanged)", systemImage: "message.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Time elapsed
                        Text(timeElapsedString(from: session.startTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cardCornerRadius))
                .padding(.horizontal, 16)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.currentDateSession != nil)
    }
    
    private func timeElapsedString(from startTime: Date) -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)時間\(remainingMinutes)分"
        } else {
            return "\(remainingMinutes)分"
        }
    }
    
    // MARK: - Modern Floating Icon with Message Animation
    @State private var showMessageBubble = false
    @State private var messageBubbleText = ""
    @State private var messageBubbleOffset: CGFloat = 0
    @State private var messageBubbleOpacity: Double = 0
    @State private var characterTalkingAnimation = false
    
    private var modernFloatingIconView: some View {
        ZStack {
            // Message bubble from character
            if showMessageBubble {
                VStack {
                    HStack {
                        Spacer()
                        
                        // Speech bubble
                        VStack(alignment: .leading, spacing: 8) {
                            Text(messageBubbleText)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: intimacyColor.opacity(0.3), radius: 12, x: 0, y: 6)
                                )
                                .overlay(
                                    // Speech bubble tail
                                    Path { path in
                                        path.move(to: CGPoint(x: 15, y: 40))
                                        path.addLine(to: CGPoint(x: 5, y: 50))
                                        path.addLine(to: CGPoint(x: 25, y: 45))
                                        path.closeSubpath()
                                    }
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: intimacyColor.opacity(0.2), radius: 4, x: 0, y: 2),
                                    alignment: .bottomLeading
                                )
                        }
                        .frame(maxWidth: 200, alignment: .leading)
                        .offset(x: -20, y: messageBubbleOffset)
                        .opacity(messageBubbleOpacity)
                        .scaleEffect(messageBubbleOpacity)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .frame(height: 180)
            }
            
            // Character icon with talking animation
            CharacterIconView(character: viewModel.character, size: 120)
                .scaleEffect(characterTalkingAnimation ? 1.05 : 1.0)
                .shadow(color: intimacyColor.opacity(showMessageBubble ? 0.6 : 0.4), radius: 20, x: 0, y: 10)
                .overlay(
                    // Speaking indicator (subtle rings)
                    Group {
                        if characterTalkingAnimation {
                            ForEach(0..<3) { index in
                                Circle()
                                    .stroke(intimacyColor.opacity(0.3), lineWidth: 2)
                                    .frame(width: 130 + CGFloat(index * 15), height: 130 + CGFloat(index * 15))
                                    .scaleEffect(characterTalkingAnimation ? 1.2 : 0.8)
                                    .opacity(characterTalkingAnimation ? 0 : 0.7)
                                    .animation(
                                        .easeOut(duration: 1.0)
                                            .delay(Double(index) * 0.2)
                                            .repeatForever(autoreverses: false),
                                        value: characterTalkingAnimation
                                    )
                            }
                        }
                    }
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: characterTalkingAnimation)
                .id(viewModel.character.iconURL ?? "default")
        }
        .padding(.vertical, 20)
        .offset(y: iconOffset)
        .onAppear {
            showFloatingIcon = true
        }
    }
    
    // Enhanced intimacy color
    private var intimacyColor: Color {
        switch viewModel.character.intimacyLevel {
        case 0...10: return .gray
        case 11...30: return .blue
        case 31...60: return .green
        case 61...80: return .orange
        case 81...100: return .pink
        default: return .red
        }
    }
    
    // MARK: - Modern Chat View (キーボード対応版)
    private var modernChatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ModernMessageBubble(message: message)
                            .id(message.id)
                            .padding(.horizontal, 16)
                    }
                    
                    // OshiAIChatViewと同じように最下部マーカーを追加
                    Color.clear
                        .frame(height: 1)
                        .id("bottomMarker")
                }
                .padding(.vertical, 16)
            }
            .background(.clear)
            // キーボード表示時のスクロール処理（OshiAIChatViewと同様）
            .onChange(of: keyboardHeight) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("bottomMarker", anchor: .bottom)
                    }
                }
            }
            // メッセージ追加時のスクロール処理
            .onChange(of: viewModel.messages.count) { _ in
                if !viewModel.messages.isEmpty {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("bottomMarker", anchor: .bottom)
                    }
                }
                
                if let lastMessage = viewModel.messages.last, !lastMessage.isFromUser {
                    triggerFloatingIcon()
                }
            }
        }
    }
    
    // MARK: - Modern Input View (キーボード対応版)
    private var modernInputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Input field with modern design
                HStack(spacing: 12) {
                    TextField("", text: $messageText, prompt: Text("メッセージを入力...").foregroundColor(.gray.opacity(0.6)))
                        .textFieldStyle(PlainTextFieldStyle())
                        .disabled(!viewModel.isAuthenticated)
                        .focused($isInputFocused)
                        .font(.body)
                        .foregroundColor(.primary)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    if messageText.count > 50 {
                        Text("\(messageText.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(messageText.count > 200 ? .red : .gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(messageText.count > 200 ? .red.opacity(0.1) : .gray.opacity(0.1))
                            )
                            .animation(.easeInOut(duration: 0.2), value: messageText.count)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.ultraThinMaterial)
                        .stroke(
                            isInputFocused ? primaryColor.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
                
                // Send button with enhanced design
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: messageText.isEmpty || !viewModel.isAuthenticated
                                        ? [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]
                                        : [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .shadow(
                                color: messageText.isEmpty ? Color.clear : .green.opacity(0.3),
                                radius: messageText.isEmpty ? 0 : 8,
                                x: 0,
                                y: messageText.isEmpty ? 0 : 4
                            )
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(pulseAnimation ? 5 : 0))
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    }
                }
                .disabled(messageText.isEmpty || !viewModel.isAuthenticated)
                .scaleEffect(messageText.isEmpty ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messageText.isEmpty)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pulseAnimation)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Helper Functions
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        // Show character listening animation
        showCharacterListening()
        
        if let message = viewModel.messages.last, viewModel.currentDateSession != nil {
            viewModel.updateDateSessionOnMessage(message)
        }
        
        viewModel.sendMessage(messageText)
        messageText = ""
        
        triggerPulseAnimation()
    }
    
    // MARK: - Character Listening Animation
    private func showCharacterListening() {
        // Subtle glow effect when user sends message
        withAnimation(.easeInOut(duration: 0.5)) {
            showFloatingIcon = true
        }
        
        // Small scale animation to show character is "receiving" the message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            characterTalkingAnimation = true
        }
        
        // Quick reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                characterTalkingAnimation = false
            }
        }
    }
    
    private func triggerPulseAnimation() {
        pulseAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pulseAnimation = false
        }
    }
    
    private func triggerFloatingIcon() {
        showFloatingIcon = true
        
        // Get the last AI message for the speech bubble
        if let lastMessage = viewModel.messages.last, !lastMessage.isFromUser {
            showCharacterSpeaking(with: lastMessage.text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showFloatingIcon = false
            }
        }
    }
    
    // MARK: - Character Speaking Animation
    private func showCharacterSpeaking(with text: String) {
        // Set the message text (truncate if too long)
        let displayText = text.count > 50 ? String(text.prefix(47)) + "..." : text
        messageBubbleText = displayText
        
        // Start talking animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            characterTalkingAnimation = true
        }
        
        // Show message bubble with entrance animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            showMessageBubble = true
            messageBubbleOffset = -10
            messageBubbleOpacity = 1.0
        }
        
        // Add floating animation to the bubble
        withAnimation(.easeInOut(duration: 2.0).delay(0.5)) {
            messageBubbleOffset = -20
        }
        
        // Hide message bubble after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                messageBubbleOpacity = 0
                messageBubbleOffset = -30
            }
            
            // Reset after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showMessageBubble = false
                messageBubbleOffset = 0
            }
        }
        
        // Stop talking animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                characterTalkingAnimation = false
            }
        }
    }
}

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

// MARK: - Modern Button Component
private struct ModernButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .scaleEffect(0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: color)
    }
}

// MARK: - Modern Message Bubble
struct ModernMessageBubble: View {
    let message: Message
    @State private var showAnimation = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer()
                userMessageView
            } else {
                aiMessageView
                Spacer()
            }
        }
        .scaleEffect(showAnimation ? 1.0 : 0.8)
        .opacity(showAnimation ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showAnimation = true
            }
        }
    }
    
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                if let location = message.dateLocation {
                    Label(location, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
    }
    
    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let location = message.dateLocation {
                    Label(location, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Row Component for Authentication View
struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

#Preview {
    ContentView(viewModel: RomanceAppViewModel())
}
