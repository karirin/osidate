//
//  FullChatHistoryView.swift
//  osidate
//
//  全メッセージ履歴を表示するビュー
//

import SwiftUI

struct FullChatHistoryView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var searchText = ""
    @State private var selectedDateFilter: DateFilter = .all
    @State private var showingSearchFilter = false
    
    // Design Constants
    private let primaryColor = Color(.systemBlue)
    private let accentColor = Color(.systemPurple)
    
    // フィルタリングされたメッセージ
    private var filteredMessages: [Message] {
        var messages = viewModel.messages
        
        // 検索フィルター
        if !searchText.isEmpty {
            messages = messages.filter { message in
                message.text.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 日付フィルター
        switch selectedDateFilter {
        case .today:
            messages = messages.filter { Calendar.current.isDateInToday($0.timestamp) }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            messages = messages.filter { $0.timestamp >= weekAgo }
        case .thisMonth:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            messages = messages.filter { $0.timestamp >= monthAgo }
        case .all:
            break
        }
        
        return messages
    }
    
    // 日付別にグループ化されたメッセージ
    private var groupedMessages: [(String, [Message])] {
        let grouped = Dictionary(grouping: filteredMessages) { message in
            DateFormatter.dayFormatter.string(from: message.timestamp)
        }
        
        return grouped.sorted { first, second in
            guard let firstDate = DateFormatter.dayFormatter.date(from: first.key),
                  let secondDate = DateFormatter.dayFormatter.date(from: second.key) else {
                return false
            }
            return firstDate > secondDate
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView
                
                VStack(spacing: 0) {
                    // Search and Filter Section
                    searchAndFilterSection
                    
                    // Message List
                    messageListView
                }
            }
            .navigationTitle("会話履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSearchFilter.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(primaryColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearchFilter) {
            SearchFilterView(selectedFilter: $selectedDateFilter)
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                primaryColor.opacity(0.05),
                accentColor.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("メッセージを検索...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // Date Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.displayName,
                            isSelected: selectedDateFilter == filter,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDateFilter = filter
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Statistics
            if !filteredMessages.isEmpty {
                HStack(spacing: 20) {
                    StatisticItem(
                        icon: "message.fill",
                        title: "総メッセージ",
                        value: "\(filteredMessages.count)"
                    )
                    
                    StatisticItem(
                        icon: "person.fill",
                        title: "あなた",
                        value: "\(filteredMessages.filter { $0.isFromUser }.count)"
                    )
                    
                    StatisticItem(
                        icon: "heart.fill",
                        title: "パートナー",
                        value: "\(filteredMessages.filter { !$0.isFromUser }.count)"
                    )
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Message List View
    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if filteredMessages.isEmpty {
                    emptyStateView
                } else {
                    ForEach(groupedMessages, id: \.0) { dateString, messages in
                        VStack(spacing: 16) {
                            // Date Header
                            HStack {
                                Text(dateString)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(messages.count)件")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 16)
                            
                            // Messages for this date
                            ForEach(messages.sorted { $0.timestamp < $1.timestamp }) { message in
                                HistoryMessageBubble(message: message)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("メッセージが見つかりません")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ? "フィルター条件を変更してみてください" : "検索条件を変更してみてください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue)
                )
        }
    }
}

struct StatisticItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HistoryMessageBubble: View {
    let message: Message
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
    }
    
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                if let location = message.dateLocation {
                    Label(location, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
    }
    
    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
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

struct SearchFilterView: View {
    @Binding var selectedFilter: DateFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(DateFilter.allCases, id: \.self) { filter in
                HStack {
                    Text(filter.displayName)
                        .font(.body)
                    
                    Spacer()
                    
                    if selectedFilter == filter {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedFilter = filter
                    dismiss()
                }
            }
            .navigationTitle("期間フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum DateFilter: CaseIterable {
    case all
    case today
    case thisWeek
    case thisMonth
    
    var displayName: String {
        switch self {
        case .all: return "すべて"
        case .today: return "今日"
        case .thisWeek: return "今週"
        case .thisMonth: return "今月"
        }
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

#Preview {
    FullChatHistoryView(viewModel: RomanceAppViewModel())
}
