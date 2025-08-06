//
//  ContentView.swift - 背景画像修正版
//  osidate
//
//  Fixed background image layout issues
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @State private var showFloatingIcon = false
    @State private var pulseAnimation = false
    @State private var messageText = ""
    @State private var iconOffset: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack{
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.isAuthenticated {
                    MainAppView()
                } else {
                    AuthenticationView()
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
            GeometryReader { geometry in
                ZStack {
                    // 修正された背景画像
                    backgroundView(geometry: geometry)
                    
                    VStack(spacing: 0) {
                        // Header
                        headerView
                        
                        // デート状況表示（デート中の場合）
                        if viewModel.currentDateSession != nil {
                            dateStatusView
                        }
                        
                        // Floating Icon
                        floatingIconView
                        
                        // Chat Area
                        chatView
                        
                        // Input Area
                        inputView
                        
                        // Bottom Buttons（デート中でない場合のみ表示）
                        if viewModel.currentDateSession == nil {
                            bottomButtonsView
                        }
                    }
                }
            }
            .clipped() // 画面外への表示を防ぐ
        }
        .navigationViewStyle(StackNavigationViewStyle()) // iPadでの表示問題を防ぐ
    }
    
    // MARK: - Fixed Background View
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
//                            .aspectRatio(contentMode: .fill)
//                            .frame(
//                                width: geometry.size.width,
//                                height: geometry.size.height
//                            )
//                            .clipped() // 画面外への表示を防ぐ
                    default:
                        defaultBackgroundImage(geometry: geometry)
                    }
                }
            } else {
                defaultBackgroundImage(geometry: geometry)
            }
        }
        .ignoresSafeArea()
        .opacity(0.8)
        .animation(.easeInOut(duration: 0.5), value: viewModel.character.backgroundName)
    }
    
    // デフォルト背景画像
    private func defaultBackgroundImage(geometry: GeometryProxy) -> some View {
        Image(viewModel.character.backgroundName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .clipped() // 画面外への表示を防ぐ
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.character.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Text(viewModel.character.intimacyTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if viewModel.isAnonymousUser {
                        Image(systemName: "person.crop.circle.dashed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // プログレスバー
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("親密度")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.character.intimacyLevel)/100")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 150, height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(intimacyColor)
                            .frame(width: 150 * CGFloat(viewModel.character.intimacyLevel) / 100, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.character.intimacyLevel)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { viewModel.showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Button(action: { viewModel.showingBackgroundSelector = true }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // 親密度の色を決定するプロパティ
    private var intimacyColor: Color {
        switch viewModel.character.intimacyLevel {
        case 0...10: return .gray
        case 11...30: return .blue
        case 31...60: return .green
        case 61...100: return .pink
        default: return .red
        }
    }
    
    // MARK: - Date Status View
    private var dateStatusView: some View {
        Group {
            if let session = viewModel.currentDateSession {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: session.location.type.icon)
                            .foregroundColor(session.location.type.color)
                        
                        Text("\(session.location.name)でデート中")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button("終了") {
                            viewModel.endDate()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    HStack {
                        Text("開始時刻: \(DateFormatter.localizedString(from: session.startTime, dateStyle: .none, timeStyle: .short))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("メッセージ: \(session.messagesExchanged)回")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentDateSession != nil)
    }
    
    private var floatingIconView: some View {
        CharacterIconView(character: viewModel.character, size: 120) // サイズを少し小さくして画面におさまりやすく
            .id(viewModel.character.iconURL ?? "default")
            .padding(.vertical, 10)
            .offset(y: iconOffset)
    }
    
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleEnhanced(message: message)
                            .id(message.id)
                            .padding(.horizontal) // メッセージに適切なパディングを追加
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                
                if let lastMessage = viewModel.messages.last, !lastMessage.isFromUser {
                    triggerFloatingIcon()
                }
            }
        }
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
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
                            .foregroundColor(messageText.count > 200 ? .red : .gray)
                            .animation(.easeInOut(duration: 0.2), value: messageText.count)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(isInputFocused ? Color.gray.opacity(0.5) : Color.clear, lineWidth: 1)
                                .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                        )
                )
                
                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                messageText.isEmpty || !viewModel.isAuthenticated
                                ? Color.gray.opacity(0.3)
                                : Color.green
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(pulseAnimation ? 5 : 0))
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pulseAnimation)
                    }
                }
                .disabled(messageText.isEmpty || !viewModel.isAuthenticated)
                .scaleEffect(messageText.isEmpty ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: messageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    private var bottomButtonsView: some View {
        HStack(spacing: 16) {
            Button("デート") {
                viewModel.showingDateSelector = true
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.pink, Color.pink.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .disabled(!viewModel.isAuthenticated)
            .opacity(viewModel.isAuthenticated ? 1.0 : 0.6)
            .shadow(color: Color.pink.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        // デートセッションがある場合、メッセージカウントを更新
        if let message = viewModel.messages.last, viewModel.currentDateSession != nil {
            viewModel.updateDateSessionOnMessage(message)
        }
        
        viewModel.sendMessage(messageText)
        messageText = ""
        
        triggerPulseAnimation()
    }
    
    private func triggerPulseAnimation() {
        pulseAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pulseAnimation = false
        }
    }
    
    private func triggerFloatingIcon() {
        showFloatingIcon = true
        
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
                        // デート場所の表示
                        if let location = message.dateLocation {
                            Text("📍 \(location)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(timeString(from: message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing) // 最大幅を制限
            } else {
                VStack(alignment: .leading) {
                    Text(message.text)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        .shadow(radius: 1)
                    
                    HStack {
                        Text(timeString(from: message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        if let location = message.dateLocation {
                            Text("📍 \(location)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading) // 最大幅を制限
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
