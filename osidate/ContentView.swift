//
//  ContentView.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @State private var showFloatingIcon = false
    @State private var pulseAnimation = false
    @State private var messageText = ""
    @State private var iconOffset: CGFloat = 0
    
    var body: some View {
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
        .sheet(isPresented: $viewModel.showingDateView) {
            DateView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(viewModel.character.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(viewModel.character.intimacyTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
            // Pulse rings for character icon
            if pulseAnimation {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.red.opacity(0.6), lineWidth: 2)
                        .scaleEffect(pulseAnimation ? 2.0 + Double(index) * 0.5 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .delay(Double(index) * 0.2)
                                .repeatCount(3, autoreverses: false),
                            value: pulseAnimation
                        )
                }
            }
            // Floating Character Icon
            Circle()
                .fill(Color.brown)
                .frame(width: 150, height: 150)
                .overlay(
                    Text("アイコン")
                        .font(.caption)
                        .foregroundColor(.white)
                )
                .padding(.top)
                .offset(y: iconOffset)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        iconOffset = -10
                    }
                }
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
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.isEmpty ? .gray : .green)
            }
            .disabled(messageText.isEmpty)
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
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Spacer()
            
            Text("親密度: \(viewModel.character.intimacyLevel)")
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(10)
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
