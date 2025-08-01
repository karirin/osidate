//
//  ContentView.swift
//  osidate
//
//  Updated with Firebase Auth integration
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @State private var showFloatingIcon = false
    @State private var pulseAnimation = false
    @State private var messageText = ""
    @State private var iconOffset: CGFloat = 0
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.isAuthenticated {
                MainAppView()
            } else {
                AuthenticationView()
            }
        }
        .sheet(isPresented: $viewModel.showingDateView) {
            DateView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
    
    // MARK: - Loading View
    private func LoadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("アプリを初期化中...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Authentication View
    private func AuthenticationView() -> some View {
        VStack(spacing: 30) {
            VStack(spacing: 10) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                
                Text("おかえりなさい")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("あなたの特別なパートナーが待っています")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 15) {
                Button(action: {
                    viewModel.signInAnonymously()
                }) {
                    HStack {
                        Image(systemName: "person.circle")
                        Text("ゲストとして始める")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isLoading)
                
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("認証中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            VStack(spacing: 8) {
                Text("ゲストアカウントについて")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("• データは自動的に保存されます\n• アプリを削除するとデータは失われます\n• 将来的にアカウント移行機能を提供予定")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.1), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Main App View
    private func MainAppView() -> some View {
        NavigationView {
            ZStack {
                // Background
                Image(viewModel.character.backgroundName)
                    .resizable()
                    .ignoresSafeArea()
                    .opacity(0.3)
                
                VStack {
                    // Header
                    headerView
                    
                    floatingIconView
                    ZStack {
                        // Chat Area
                        chatView
                    }
                    
                    // Input Area
                    inputView
                    
                    // Bottom Buttons
                    bottomButtonsView
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(viewModel.character.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack {
                    Text(viewModel.character.intimacyTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if viewModel.isAnonymousUser {
                        Image(systemName: "person.crop.circle.dashed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                ProgressView(value: Double(viewModel.character.intimacyLevel), total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 150)
            }
            
            Spacer()
            
            Button(action: { viewModel.showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.title2)
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
    }
    
    private var floatingIconView: some View {
        ZStack {
            // Floating Character Icon - カスタムアイコンに対応
            CharacterIconView(character: viewModel.character, size: 150)
                .padding(.top)
                .offset(y: iconOffset)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        iconOffset = -10
                    }
                }
                // アイコンURLの変更を強制的に監視
                .id("character_icon_\(viewModel.character.iconURL ?? "default")")
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleEnhanced(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _ in
                // Auto scroll to latest message
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                
                // Show floating icon for new AI messages
                if let lastMessage = viewModel.messages.last, !lastMessage.isFromUser {
                    triggerFloatingIcon()
                }
            }
        }
    }
    
    private var inputView: some View {
        HStack {
            TextField("メッセージを入力...", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(!viewModel.isAuthenticated)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.isEmpty || !viewModel.isAuthenticated ? .gray : .green)
            }
            .disabled(messageText.isEmpty || !viewModel.isAuthenticated)
        }
        .padding()
        .background(Color.white.opacity(0.9))
    }
    
    private var bottomButtonsView: some View {
        HStack {
            Button("デート") {
                viewModel.showingDateView = true
            }
            .padding()
            .background(viewModel.isAuthenticated ? Color.pink : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(!viewModel.isAuthenticated)
            
            Spacer()
        }
        .padding()
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        viewModel.sendMessage(messageText)
        messageText = ""
        
        // Trigger pulse animation
        triggerPulseAnimation()
    }
    
    private func triggerPulseAnimation() {
        pulseAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            pulseAnimation = false
        }
    }
    
    private func triggerFloatingIcon() {
        showFloatingIcon = true
        
        // Hide floating icon after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showFloatingIcon = false
            }
        }
    }
}

struct MessageBubbleEnhanced: View {
    let message: Message
    @State private var showAnimation = false
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                VStack(alignment: .trailing) {
                    Text(message.text)
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    
                    HStack {
                        Text(timeString(from: message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        // Read receipt (double check mark)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if let location = message.dateLocation {
                        Text("📍 \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading) {
                    Text(message.text)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(radius: 1)
                    
                    Text(timeString(from: message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if let location = message.dateLocation {
                        Text("📍 \(location)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
        }
        .scaleEffect(showAnimation ? 1.0 : 0.8)
        .opacity(showAnimation ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showAnimation = true
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView(viewModel: RomanceAppViewModel())
}
