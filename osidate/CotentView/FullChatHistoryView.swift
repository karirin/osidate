//
//  FullChatHistoryView.swift
//  osidate
//
//  全メッセージ履歴を表示するビュー - モダンUI/UXアップデート版
//

import SwiftUI

struct FullChatHistoryView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // State
    @State private var searchText = ""
    @State private var selectedDateFilter: DateFilter = .all
    @State private var showingSearchFilter = false
    @State private var isSearchFocused = false
    @State private var isSearchSectionVisible = true
    @State private var headerAppeared = false
    @State private var contentAppeared = false

    // Design Constants
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F093FB"), Color(hex: "F5576C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Filtered Messages
    private var filteredMessages: [Message] {
        var messages = viewModel.messages

        if !searchText.isEmpty {
            messages = messages.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }

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

    // MARK: - Grouping (Dateキーでグループ化して型推論負荷を軽減)
    private struct DayGroup: Identifiable {
        let day: Date
        let messages: [Message]
        var id: Date { day }
        var title: String { DateFormatter.dayFormatter.string(from: day) }
    }

    private var groupedDays: [DayGroup] {
        let grouped = Dictionary(grouping: filteredMessages) { message in
            Calendar.current.startOfDay(for: message.timestamp)
        }

        return grouped
            .map { DayGroup(day: $0.key, messages: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView

                VStack(spacing: 0) {
                    // Search & Filter Section
                    if isSearchSectionVisible {
                        searchAndFilterSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    // Message List
                    messageListView
                }
            }
            .navigationTitle("会話履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                navToolbar
            }
            .onAppear {
                viewModel.loadMoreMessages()
                startAnimations()
            }
        }
        .sheet(isPresented: $showingSearchFilter) {
            ModernSearchFilterSheet(selectedFilter: $selectedDateFilter)
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Toolbar (分離してビルダーの型推論負荷を軽減)
    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                hapticFeedback(.light)
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                    Text("閉じる")
                        .font(.system(.body, design: .rounded, weight: .medium))
                }
                .foregroundStyle(primaryGradient)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                hapticFeedback(.light)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isSearchSectionVisible.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSearchSectionVisible
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "magnifyingglass.circle.fill")
                        .font(.title3)
                    Text(isSearchSectionVisible ? "非表示" : "検索")
                        .font(.system(.body, design: .rounded, weight: .medium))
                }
                .foregroundStyle(primaryGradient)
            }
        }
    }

    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            // Base
            (colorScheme == .dark ? Color(hex: "0D0D0D") : Color(hex: "F8F9FA"))
                .ignoresSafeArea()

            // Gradient orbs
            Circle()
                .fill(Color(hex: "667EEA").opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color(hex: "F093FB").opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 100, y: 300)
        }
    }

    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 20) {
            // Search Bar
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(primaryGradient)
                    .scaleEffect(isSearchFocused ? 1.15 : 1.0)
                    .animation(.spring(response: 0.3), value: isSearchFocused)

                TextField("メッセージを検索...", text: $searchText)
                    .font(.system(.body, design: .rounded))
                    .textFieldStyle(PlainTextFieldStyle())
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
                        hapticFeedback(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                        radius: isSearchFocused ? 16 : 10,
                        x: 0,
                        y: isSearchFocused ? 8 : 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSearchFocused ? primaryGradient : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSearchFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearchFocused)
            .padding(.horizontal, 20)

            // Date Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        ModernFilterPill(
                            filter: filter,
                            isSelected: selectedDateFilter == filter,
                            primaryGradient: primaryGradient
                        ) {
                            hapticFeedback(.light)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedDateFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }

            // Statistics
            if !filteredMessages.isEmpty {
                statisticsView
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Statistics View
    private var statisticsView: some View {
        HStack(spacing: 0) {
            StatisticCard(
                icon: "bubble.left.and.bubble.right.fill",
                title: "総数",
                value: filteredMessages.count,
                gradient: primaryGradient
            )

            Divider()
                .frame(height: 40)
                .padding(.horizontal, 8)

            StatisticCard(
                icon: "person.fill",
                title: "あなた",
                value: filteredMessages.filter { $0.isFromUser }.count,
                gradient: LinearGradient(
                    colors: [Color(hex: "11998E"), Color(hex: "38EF7D")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Divider()
                .frame(height: 40)
                .padding(.horizontal, 8)

            StatisticCard(
                icon: "heart.fill",
                title: "パートナー",
                value: filteredMessages.filter { !$0.isFromUser }.count,
                gradient: accentGradient
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Message List View
    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 28) {
                if filteredMessages.isEmpty {
                    emptyStateView
                        .transition(.scale.combined(with: .opacity))
                } else {
                    ForEach(Array(groupedDays.enumerated()), id: \.element.id) { index, group in
                        VStack(spacing: 16) {
                            // Date Header
                            dateHeaderView(dateString: group.title, messageCount: group.messages.count)

                            // Messages
                            ForEach(group.messages.sorted { $0.timestamp < $1.timestamp }) { message in
                                HistoryMessageBubble(message: message)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 30)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                                .delay(Double(index) * 0.05),
                            value: contentAppeared
                        )
                    }
                }
            }
            .padding(.vertical, 24)
        }
    }

    // MARK: - Date Header View
    private func dateHeaderView(dateString: String, messageCount: Int) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.circle.fill")
                    .font(.title3)
                    .foregroundStyle(primaryGradient)

                Text(dateString)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }

            Spacer()

            Text("\(messageCount)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(primaryGradient)
                        .shadow(color: Color(hex: "667EEA").opacity(0.3), radius: 6, x: 0, y: 3)
                )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(primaryGradient.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(primaryGradient)
            }

            VStack(spacing: 14) {
                Text("メッセージが見つかりません")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)

                Text(searchText.isEmpty
                     ? "フィルター条件を変更してみてください"
                     : "「\(searchText)」に一致するメッセージはありません")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                hapticFeedback(.light)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    searchText = ""
                    selectedDateFilter = .all
                }
            } label: {
                Text("フィルターをリセット")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(primaryGradient)
                            .shadow(color: Color(hex: "667EEA").opacity(0.35), radius: 12, x: 0, y: 6)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Actions
    private func startAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            headerAppeared = true
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            contentAppeared = true
        }
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Statistic Card
struct StatisticCard: View {
    let icon: String
    let title: String
    let value: Int
    let gradient: LinearGradient

    @State private var animatedValue = 0

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(gradient)

                Text("\(animatedValue)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
            }

            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3)) {
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

// MARK: - Modern Filter Pill
struct ModernFilterPill: View {
    let filter: DateFilter
    let isSelected: Bool
    let primaryGradient: LinearGradient
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(filter.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected
                          ? AnyShapeStyle(primaryGradient)
                          : AnyShapeStyle(colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white))
                    .shadow(
                        color: isSelected
                            ? Color(hex: "667EEA").opacity(0.35)
                            : Color.black.opacity(colorScheme == .dark ? 0.2 : 0.06),
                        radius: isSelected ? 10 : 6,
                        x: 0,
                        y: isSelected ? 5 : 3
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - History Message Bubble
struct HistoryMessageBubble: View {
    let message: Message

    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme

    private var userGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isFromUser {
                Spacer(minLength: 60)
                userBubble
            } else {
                aiBubble
                Spacer(minLength: 60)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : (message.isFromUser ? 20 : -20))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(message.text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(userGradient)
                        .shadow(color: Color(hex: "667EEA").opacity(0.3), radius: 10, x: 0, y: 5)
                )

            HStack(spacing: 8) {
                if let location = message.dateLocation {
                    locationLabel(location)
                }
                timeLabel(message.timestamp)
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
    }

    private var aiBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white)
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                            radius: 10,
                            x: 0,
                            y: 5
                        )
                )

            HStack(spacing: 8) {
                timeLabel(message.timestamp)

                if let location = message.dateLocation {
                    locationLabel(location)
                }

                if message.intimacyGained > 0 {
                    intimacyLabel(message.intimacyGained)
                }
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
    }

    private func locationLabel(_ location: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.system(size: 9))
            Text(location)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundColor(.secondary)
    }

    private func timeLabel(_ date: Date) -> some View {
        Text(timeString(from: date))
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
    }

    private func intimacyLabel(_ value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9))
            Text("+\(value)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(Color(hex: "F093FB"))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(hex: "F093FB").opacity(0.12))
        )
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Modern Search Filter Sheet
struct ModernSearchFilterSheet: View {
    @Binding var selectedFilter: DateFilter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 28) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(primaryGradient.opacity(0.15))
                        .frame(width: 70, height: 70)

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(primaryGradient)
                }

                Text("期間を選択")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.top, 24)

            // Filter Options
            VStack(spacing: 12) {
                ForEach(DateFilter.allCases, id: \.self) { filter in
                    FilterOptionRow(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        primaryGradient: primaryGradient
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            dismiss()
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
    }
}

// MARK: - Filter Option Row
struct FilterOptionRow: View {
    let filter: DateFilter
    let isSelected: Bool
    let primaryGradient: LinearGradient
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    
    private var iconStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(primaryGradient) : AnyShapeStyle(Color.secondary)
    }

    private var rowFill: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(colorScheme == .dark ? Color(hex: "2C2C2E") : Color(hex: "F0F4FF"))
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }

    private var rowStroke: AnyShapeStyle {
        isSelected ? AnyShapeStyle(primaryGradient.opacity(0.3)) : AnyShapeStyle(Color.clear)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: filter.icon)
                    .font(.title3)
                    .foregroundStyle(iconStyle)
                    .frame(width: 28)

                Text(filter.displayName)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(primaryGradient)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(rowFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(rowStroke, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - DateFilter Enum
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
