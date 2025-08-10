//
//  ContentView.swift - 拡張親密度システム対応版
//  osidate
//
//  50箇所のデートスポットと無限モード対応
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
    @State private var showingFullChatHistory = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    // Design Constants
    private let cardCornerRadius: CGFloat = 20
    private let primaryColor = Color(.systemBlue)
    private let accentColor = Color(.systemPurple)
    
    // MARK: - Recent Messages Computed Property
    private var recentMessages: [Message] {
        Array(viewModel.messages.suffix(5))
    }
    
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
        .sheet(isPresented: $showingFullChatHistory) {
            FullChatHistoryView(viewModel: viewModel)
        }
        // 🌟 親密度レベルアップ通知
        .sheet(isPresented: $viewModel.showingIntimacyLevelUp) {
            IntimacyLevelUpView(
                newStage: viewModel.newIntimacyStage ?? .bestFriend,
                currentLevel: viewModel.character.intimacyLevel
            )
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
                    backgroundView(geometry: geometry)
                        .blur(radius: backgroundBlur)
                    
                    VStack(spacing: 0) {
                        // Date status
                        if viewModel.currentDateSession != nil {
                            modernDateStatusView
                                .padding(.top)
                        }
                        
                        // Floating character icon
                        modernFloatingIconView
                        
                        // Enhanced chat area
                        modernChatView
                        
                        // Modern input area
                        modernInputView
                            .padding(.bottom, keyboardHeight > 0 ? 0 : 8)
                    }
                }
            }
            .clipped()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - 🌟 拡張された親密度ステータス表示
    private var modernIntimacyStatusView: some View {
        HStack(spacing: 16) {
            // 親密度レベルアイコン
            ZStack {
                Circle()
                    .fill(viewModel.character.intimacyStage.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: viewModel.character.intimacyStage.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(viewModel.character.intimacyStage.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(viewModel.character.intimacyLevel)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.character.intimacyStage.color)
                    
                    Text(viewModel.character.intimacyTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // プログレスバー
                HStack(spacing: 8) {
                    ProgressView(value: viewModel.character.intimacyProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: viewModel.character.intimacyStage.color))
                        .frame(height: 4)
                    
                    if viewModel.character.intimacyToNextLevel > 0 {
                        Text("+\(viewModel.character.intimacyToNextLevel)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("MAX")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.character.intimacyStage.color)
                    }
                }
            }
            
            Spacer()
            
            // 無限モードインジケーター
            if viewModel.character.unlockedInfiniteMode {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "infinity")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            
            // デート回数
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(viewModel.character.totalDateCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("回デート")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
                                .font(adaptiveFontSizeForDateStatus("\(session.location.name)でデート中"))
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            HStack {
                                Text("開始: \(DateFormatter.localizedString(from: session.startTime, dateStyle: .none, timeStyle: .short))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Text("経過時間: \(timeElapsedString(from: session.startTime))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
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
    
    private func adaptiveFontSizeForDateStatus(_ text: String) -> Font {
        let characterCount = text.count
        
        switch characterCount {
        case 0...8:
            return .headline
        case 9...12:
            return .subheadline
        case 13...16:
            return .body
        default:
            return .callout
        }
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
            CharacterIconView(character: viewModel.character, size: 120)
                .scaleEffect(characterTalkingAnimation ? 1.05 : 1.0)
                .shadow(color: intimacyColor.opacity(showMessageBubble ? 0.6 : 0.4), radius: 20, x: 0, y: 10)
                .overlay(
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
        return viewModel.character.intimacyStage.color
    }
    
    // MARK: - Modern Chat View
    private var modernChatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.messages.count > 5 {
                        VStack(spacing: 12) {
                            Text("\(viewModel.messages.count - 5)件の過去のメッセージがあります")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                showingFullChatHistory = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption)
                                    Text("過去のメッセージを表示")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(primaryColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    
                    ForEach(recentMessages) { message in
                        ModernMessageBubble(message: message)
                            .id(message.id)
                            .padding(.horizontal, 16)
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id("bottomMarker")
                }
                .padding(.vertical, 16)
            }
            .background(.clear)
            .onChange(of: keyboardHeight) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("bottomMarker", anchor: .bottom)
                    }
                }
            }
            .onChange(of: recentMessages.count) { _ in
                if !recentMessages.isEmpty {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo("bottomMarker", anchor: .bottom)
                    }
                }
                
                if let lastMessage = recentMessages.last, !lastMessage.isFromUser {
                    triggerFloatingIcon()
                }
            }
        }
    }
    
    // MARK: - Modern Input View
    private var modernInputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
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
        
        showCharacterListening()
        
        if let message = viewModel.messages.last, viewModel.currentDateSession != nil {
            viewModel.updateDateSessionOnMessage(message)
        }
        
        viewModel.sendMessage(messageText)
        messageText = ""
        
        triggerPulseAnimation()
    }
    
    private func showCharacterListening() {
        withAnimation(.easeInOut(duration: 0.5)) {
            showFloatingIcon = true
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            characterTalkingAnimation = true
        }
        
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
        
        if let lastMessage = recentMessages.last, !lastMessage.isFromUser {
            showCharacterSpeaking(with: lastMessage.text)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showFloatingIcon = false
            }
        }
    }
    
    private func showCharacterSpeaking(with text: String) {
        let displayText = text.count > 50 ? String(text.prefix(47)) + "..." : text
        messageBubbleText = displayText
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            characterTalkingAnimation = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            showMessageBubble = true
            messageBubbleOffset = -10
            messageBubbleOpacity = 1.0
        }
        
        withAnimation(.easeInOut(duration: 2.0).delay(0.5)) {
            messageBubbleOffset = -20
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                messageBubbleOpacity = 0
                messageBubbleOffset = -30
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showMessageBubble = false
                messageBubbleOffset = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                characterTalkingAnimation = false
            }
        }
    }
}

// MARK: - 🌟 親密度レベルアップ通知ビュー
struct IntimacyLevelUpView: View {
    let newStage: IntimacyStage
    let currentLevel: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var celebrationAnimation = false
    @State private var textScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                colors: [
                    newStage.color.opacity(0.3),
                    newStage.color.opacity(0.1),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // レベルアップアイコン
                ZStack {
                    Circle()
                        .fill(newStage.color.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(celebrationAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: celebrationAnimation)
                    
                    Image(systemName: newStage.icon)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(newStage.color)
                        .scaleEffect(celebrationAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: celebrationAnimation)
                }
                
                // レベルアップテキスト
                VStack(spacing: 16) {
                    Text("レベルアップ！")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(newStage.color)
                        .scaleEffect(textScale)
                        .opacity(textOpacity)
                    
                    VStack(spacing: 8) {
                        Text("親密度 \(currentLevel)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(newStage.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(newStage.color)
                    }
                    .scaleEffect(textScale)
                    .opacity(textOpacity)
                }
                
                Spacer()
                
                // 閉じるボタン
                Button("続ける") {
                    dismiss()
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(newStage.color)
                .cornerRadius(16)
                .padding(.horizontal, 40)
                .scaleEffect(textScale)
                .opacity(textOpacity)
            }
            .padding(20)
        }
        .onAppear {
            celebrationAnimation = true
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                textScale = 1.0
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Extensions (継続使用)
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

struct ModernButton: View {
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

// MARK: - 🌟 拡張されたメッセージバブル（親密度表示付き）
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
