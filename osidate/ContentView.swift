//
//  ContentView.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RomanceAppViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // ヘッダー
                headerView
                
                // チャットエリア
                chatView
                
                // 入力エリア
                inputView
                
                // デート・設定ボタン
                bottomButtonsView
            }
            .background(
                Image(viewModel.character.backgroundName)
                    .resizable()
                    .ignoresSafeArea()
                    .opacity(0.3)
            )
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
            Image(systemName: viewModel.character.iconName)
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
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
    
    private var chatView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
    }
    
    @State private var messageText = ""
    
    private var inputView: some View {
        HStack {
            TextField("メッセージを入力...", text: $messageText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("送信") {
                if !messageText.isEmpty {
                    viewModel.sendMessage(messageText)
                    messageText = ""
                }
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
}

#Preview {
    ContentView()
}
