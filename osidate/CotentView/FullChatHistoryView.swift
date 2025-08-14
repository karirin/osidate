//
//  FullChatHistoryView.swift
//  osidate
//
//  全メッセージ履歴を表示するビュー - アップデート版
//

import SwiftUI

struct FullChatHistoryView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var searchText = ""
    @State private var selectedDateFilter: DateFilter = .all
    @State private var showingSearchFilter = false
    @State private var isSearchFocused = false
    @State private var isSearchSectionVisible = true // 検索セクションの表示状態
    
    // Modern Design Constants
    private let primaryGradient = LinearGradient(
        colors: [Color(.systemBlue), Color(.systemIndigo)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    private let accentGradient = LinearGradient(
        colors: [Color(.systemPurple), Color(.systemPink)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
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
            GeometryReader { geometry in
                ZStack {
                    // Enhanced Background
                    backgroundView
                    
                    VStack(spacing: 0) {
                        // Enhanced Search and Filter Section (条件付きで表示)
                        if isSearchSectionVisible {
                            searchAndFilterSection
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Message List with improved animations
                        messageListView
                    }
                }
            }
            .navigationTitle("会話履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("閉じる")
                        }
                        .foregroundStyle(primaryGradient)
                        .font(.system(.body, design: .rounded, weight: .medium))
                    }
                }
                
                // 検索・フィルターセクションの表示/非表示切り替えボタン
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isSearchSectionVisible.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isSearchSectionVisible ? "slider.horizontal.3" : "magnifyingglass")
                                .font(.system(.body, weight: .medium))
                            
                            Text(isSearchSectionVisible ? "非表示" : "検索")
                                .font(.system(.body, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(primaryGradient)
                        .scaleEffect(isSearchSectionVisible ? 1.05 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchSectionVisible)
                }
            }
        }
        .sheet(isPresented: $showingSearchFilter) {
            SearchFilterView(selectedFilter: $selectedDateFilter)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Enhanced Background View
    private var backgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBlue).opacity(0.03),
                    Color(.systemPurple).opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Floating orbs for visual interest
            Circle()
                .fill(Color(.systemBlue).opacity(0.1))
                .frame(width: 200, height: 200)
                .offset(x: -100, y: -200)
                .blur(radius: 60)
            
            Circle()
                .fill(Color(.systemPurple).opacity(0.08))
                .frame(width: 150, height: 150)
                .offset(x: 100, y: 300)
                .blur(radius: 40)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Enhanced Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 20) {
            // Modern Search Bar
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(primaryGradient)
                    .font(.system(.title3, weight: .medium))
                    .scaleEffect(isSearchFocused ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isSearchFocused)
                
                TextField("メッセージを検索...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(.body, design: .rounded))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isSearchFocused = true
                        }
                    }
                    .onSubmit {
                        withAnimation(.spring(response: 0.3)) {
                            isSearchFocused = false
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Group {
                    if #available(iOS 17.0, *) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThickMaterial)
                            .stroke(primaryGradient, lineWidth: 2)
                    } else {
                        // iOS16では material を fill/stroke に直接使えない
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.clear)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
            .scaleEffect(isSearchFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearchFocused)
            .padding(.horizontal)
            
            // Enhanced Date Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        ModernFilterPill(
                            filter: filter,
                            isSelected: selectedDateFilter == filter,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedDateFilter = filter
                                }
                            }
                        )
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Enhanced Statistics with animations
            if !filteredMessages.isEmpty {
                HStack(spacing: 24) {
                    EnhancedStatisticItem(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "総メッセージ",
                        value: filteredMessages.count,
                        color: .blue,
                        gradient: primaryGradient
                    )
                    
                    EnhancedStatisticItem(
                        icon: "person.crop.circle.fill",
                        title: "あなた",
                        value: filteredMessages.filter { $0.isFromUser }.count,
                        color: .green,
                        gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    EnhancedStatisticItem(
                        icon: "heart.circle.fill",
                        title: "パートナー",
                        value: filteredMessages.filter { !$0.isFromUser }.count,
                        color: .pink,
                        gradient: accentGradient
                    )
                }
                .padding(.horizontal, 20)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 24)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
    }
    
    // MARK: - Enhanced Message List View
    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                if filteredMessages.isEmpty {
                    enhancedEmptyStateView
                        .transition(.scale.combined(with: .opacity))
                } else {
                    ForEach(groupedMessages, id: \.0) { dateString, messages in
                       
                        
                        VStack(spacing: 16) {
                            // Enhanced Date Header
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.circle.fill")
                                        .foregroundStyle(primaryGradient)
                                        .font(.title3)
                                    
                                    Text(dateString)
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                Text("\(messages.count)")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(primaryGradient)
                                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                    )
                            }
                            .padding(.horizontal, 20)
                            
                            // Enhanced Messages for this date
                            let sorted = messages.sorted { $0.timestamp < $1.timestamp }
                            ForEach(sorted, id: \.id) { message in
                                EnhancedHistoryMessageBubble(message: message)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: groupedMessages.map(\.0))
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Enhanced Empty State View
    private var enhancedEmptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(primaryGradient.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(primaryGradient)
            }
            
            VStack(spacing: 12) {
                Text("メッセージが見つかりません")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ? "フィルター条件を変更してみてください" : "「\(searchText)」に一致するメッセージはありません")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    searchText = ""
                    selectedDateFilter = .all
                }
            } label: {
                Text("フィルターをリセット")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(primaryGradient)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Enhanced Supporting Views

struct ModernFilterPill: View {
    let filter: DateFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                
                Text(filter.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ?
                          LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing) :
                          LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .overlay(
                        Capsule()
                            .stroke(.ultraThickMaterial, lineWidth: isSelected ? 0 : 1)
                    )
                    .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct EnhancedStatisticItem: View {
    let icon: String
    let title: String
    let value: Int
    let color: Color
    let gradient: LinearGradient
    
    @State private var animatedValue = 0
    
    var body: some View {
        VStack(spacing: 8) {
            HStack{
                ZStack {
                    Circle()
                        .fill(gradient.opacity(0.1))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(gradient)
                }
                
                Text("\(animatedValue)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
            }
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedValue = newValue
            }
        }
    }
}

struct EnhancedHistoryMessageBubble: View {
    let message: Message
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.isFromUser {
                Spacer(minLength: 60)
                userMessageView
            } else {
                aiMessageView
                Spacer(minLength: 60)
            }
        }
    }
    
    private var userMessageView: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(message.text)
                .font(.system(.body, design: .default))
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                if let location = message.dateLocation {
                    Label {
                        Text(location)
                            .font(.system(.caption2, design: .rounded))
                    } icon: {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                Text(timeString(from: message.timestamp))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
    }
    
    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.text)
                .font(.system(.body, design: .default))
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThickMaterial)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                Text(timeString(from: message.timestamp))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
                
                if let location = message.dateLocation {
                    Label {
                        Text(location)
                            .font(.system(.caption2, design: .rounded))
                    } icon: {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct SearchFilterView: View {
    @Binding var selectedFilter: DateFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.largeTitle)
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    
                    Text("期間を選択")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                }
                .padding(.top, 20)
                
                // Filter Options
                LazyVStack(spacing: 12) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        HStack(spacing: 16) {
                            Image(systemName: filter.icon)
                                .font(.title3)
                                .foregroundStyle(selectedFilter == filter ?
                                    LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 24)
                            
                            Text(filter.displayName)
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedFilter == filter {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .font(.title3)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedFilter = filter
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }
                        .scaleEffect(selectedFilter == filter ? 1.02 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedFilter)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Enhanced Supporting Types

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
    
    var icon: String {
        switch self {
        case .all: return "infinity.circle.fill"
        case .today: return "sun.max.fill"
        case .thisWeek: return "calendar.circle.fill"
        case .thisMonth: return "calendar.badge.clock"
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
