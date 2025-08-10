//
//  DateSelectorView.swift - 拡張された50箇所デート対応版
//  osidate
//
//  50箇所のデートスポット + 無限モード対応
//

import SwiftUI

struct DateSelectorView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedDateType: DateType? = nil
    @State private var showingDateDetail = false
    @State private var selectedLocation: DateLocation? = nil
    @State private var searchText = ""
    @State private var cardAppearOffset: CGFloat = 50
    @State private var cardAppearOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -100
    @State private var showingIntimacyFilter = false
    @State private var selectedIntimacyRange: IntimacyRange = .all
    
    // 🌟 親密度範囲フィルター
    enum IntimacyRange: String, CaseIterable {
        case all = "all"
        case low = "low"           // 0-300
        case medium = "medium"     // 301-1000
        case high = "high"         // 1001-3000
        case ultimate = "ultimate" // 3001+
        case infinite = "infinite" // 無限モード
        
        var displayName: String {
            switch self {
            case .all: return "すべて"
            case .low: return "初級 (0-300)"
            case .medium: return "中級 (301-1000)"
            case .high: return "上級 (1001-3000)"
            case .ultimate: return "究極 (3001+)"
            case .infinite: return "無限モード"
            }
        }
        
        var intimacyRange: ClosedRange<Int> {
            switch self {
            case .all: return 0...99999
            case .low: return 0...300
            case .medium: return 301...1000
            case .high: return 1001...3000
            case .ultimate: return 3001...99999
            case .infinite: return 5000...99999
            }
        }
    }
    
    // カラーテーマ
    private var primaryColor: Color {
        viewModel.character.intimacyStage.color
    }
    
    private var accentColor: Color {
        Color(.systemPurple)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemBackground) : Color(.systemGray6)
    }
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }
    
    // フィルタリングされたロケーション
    private var filteredLocations: [DateLocation] {
        var locations = viewModel.getAllAvailableLocations()
        
        // 親密度範囲フィルター
        if selectedIntimacyRange != .all {
            if selectedIntimacyRange == .infinite {
                locations = locations.filter { $0.type == .infinite }
            } else {
                let range = selectedIntimacyRange.intimacyRange
                locations = locations.filter { range.contains($0.requiredIntimacy) }
            }
        }
        
        // デートタイプフィルター
        if let selectedType = selectedDateType {
            locations = locations.filter { $0.type == selectedType }
        }
        
        // 検索フィルター
        if !searchText.isEmpty {
            locations = locations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.type.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 季節フィルター（現在利用可能なもののみ）
        locations = locations.filter { $0.isCurrentlyAvailable }
        
        return locations.sorted { $0.requiredIntimacy < $1.requiredIntimacy }
    }
    
    // 親密度レベル別のロケーション数
    private var locationCounts: [IntimacyRange: Int] {
        let allLocations = viewModel.getAllAvailableLocations()
        var counts: [IntimacyRange: Int] = [:]
        
        for range in IntimacyRange.allCases {
            if range == .infinite {
                counts[range] = viewModel.character.unlockedInfiniteMode ? 999 : 0
            } else if range == .all {
                counts[range] = allLocations.count
            } else {
                let rangeValues = range.intimacyRange
                counts[range] = allLocations.filter { rangeValues.contains($0.requiredIntimacy) }.count
            }
        }
        
        return counts
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [
                        backgroundColor,
                        primaryColor.opacity(0.05),
                        accentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 32) {
                        
                        // 検索バー
                        searchSection
                        
                        // 🌟 拡張された親密度ステータス
                        intimacyStatusSection
                        
                        // 🌟 親密度範囲フィルター
                        intimacyRangeFilterSection
                        
                        // デートタイプフィルター
                        dateTypeFilterSection
                        
                        // 現在の季節表示
                        currentSeasonSection
                        
                        // 🌟 無限モードセクション
                        if viewModel.character.unlockedInfiniteMode {
                            infiniteModeSection
                        }
                        
                        // デートロケーション一覧
                        dateLocationsSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("デートを選ぶ")
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
                        showingIntimacyFilter.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(primaryColor)
                    }
                }
            }
            .sheet(isPresented: $showingDateDetail) {
                if let location = selectedLocation {
                    DateDetailView(
                        viewModel: viewModel,
                        location: location,
                        onStartDate: { dateLocation in
                            viewModel.startDate(at: dateLocation)
                            dismiss()
                        }
                    )
                }
            }
            .sheet(isPresented: $showingIntimacyFilter) {
                IntimacyFilterView(
                    selectedRange: $selectedIntimacyRange,
                    locationCounts: locationCounts
                )
            }
            .onAppear {
                animateCardsAppearance()
            }
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("デートスポットを検索...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: cardAppearOffset)
    }
    
    // MARK: - 🌟 拡張された親密度ステータス
    private var intimacyStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("あなたの親密度ステータス")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: viewModel.character.intimacyStage.icon)
                    .font(.title3)
                    .foregroundColor(primaryColor)
            }
            
            VStack(spacing: 12) {
                // 進捗バー
                VStack(spacing: 8) {
                    HStack {
                        Text("現在のレベル")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if viewModel.character.intimacyToNextLevel > 0 {
                            Text("次のレベルまで: \(viewModel.character.intimacyToNextLevel)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("最高レベル達成！")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(primaryColor)
                        }
                    }
                    
                    ProgressView(value: viewModel.character.intimacyProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: primaryColor))
                        .frame(height: 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                // 統計情報
                HStack(spacing: 20) {
                    StatCard(
                        icon: "heart.fill",
                        title: "親密度",
                        value: "\(viewModel.character.intimacyLevel)",
                        color: primaryColor
                    )
                    
                    StatCard(
                        icon: "calendar.badge.clock",
                        title: "総デート回数",
                        value: "\(viewModel.character.totalDateCount)",
                        color: .orange
                    )
                    
                    StatCard(
                        icon: "sparkles",
                        title: "段階",
                        value: viewModel.character.intimacyTitle,
                        color: accentColor
                    )
                }
            }
        }
        .padding()
        .background(cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: cardAppearOffset)
    }
    
    // MARK: - 🌟 親密度範囲フィルター
    private var intimacyRangeFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("親密度レベル別")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if selectedIntimacyRange != .all {
                    Button("すべて表示") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedIntimacyRange = .all
                        }
                    }
                    .font(.caption)
                    .foregroundColor(primaryColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(IntimacyRange.allCases, id: \.self) { range in
                        if range != .infinite || viewModel.character.unlockedInfiniteMode {
                            intimacyRangeChip(range: range)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: cardAppearOffset)
    }
    
    private func intimacyRangeChip(range: IntimacyRange) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedIntimacyRange = selectedIntimacyRange == range ? .all : range
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(range.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if let count = locationCounts[range] {
                        Text("(\(count))")
                            .font(.caption2)
                    }
                }
                
                if range == .infinite && viewModel.character.unlockedInfiniteMode {
                    HStack(spacing: 2) {
                        Image(systemName: "infinity")
                            .font(.caption2)
                        Text("無限")
                            .font(.caption2)
                    }
                    .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selectedIntimacyRange == range
                ? primaryColor.opacity(0.2)
                : Color.gray.opacity(0.1)
            )
            .foregroundColor(
                selectedIntimacyRange == range
                ? primaryColor
                : .secondary
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedIntimacyRange == range
                        ? primaryColor.opacity(0.5)
                        : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .scaleEffect(selectedIntimacyRange == range ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIntimacyRange)
    }
    
    // MARK: - Date Type Filter Section (継続使用)
    private var dateTypeFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("カテゴリで絞り込み")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if selectedDateType != nil {
                    Button("すべて表示") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDateType = nil
                        }
                    }
                    .font(.caption)
                    .foregroundColor(primaryColor)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DateType.allCases, id: \.self) { type in
                        if type != .infinite || viewModel.character.unlockedInfiniteMode {
                            dateTypeChip(type: type)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: cardAppearOffset)
    }
    
    private func dateTypeChip(type: DateType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDateType = selectedDateType == type ? nil : type
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                selectedDateType == type
                ? type.color.opacity(0.2)
                : Color.gray.opacity(0.1)
            )
            .foregroundColor(
                selectedDateType == type
                ? type.color
                : .secondary
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        selectedDateType == type
                        ? type.color.opacity(0.5)
                        : Color.clear,
                        lineWidth: 1
                    )
            )
            .fixedSize(horizontal: true, vertical: false)
        }
        .scaleEffect(selectedDateType == type ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedDateType)
    }
    
    // MARK: - Current Season Section (継続使用)
    private var currentSeasonSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                    Text("現在の季節: \(DateLocation.currentSeason.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text("季節限定のデートも楽しめます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundColor(accentColor)
                .rotationEffect(.degrees(shimmerOffset / 10))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: shimmerOffset)
        }
        .padding()
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.6), value: cardAppearOffset)
    }
    
    // MARK: - 🌟 無限モードセクション
    private var infiniteModeSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "infinity.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("無限デートモード")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("想像を超えた無限のデートスポット")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.infiniteDateCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    
                    Text("回体験")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("無限の愛が生み出した奇跡のデートスポット。常に新しい体験があなたを待っています。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: Color.purple.opacity(0.2), radius: 12, x: 0, y: 6)
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.7), value: cardAppearOffset)
    }
    
    // MARK: - Date Locations Section
    private var dateLocationsSection: some View {
        LazyVGrid(
            columns: Array(repeating: .init(.flexible(), spacing: 16), count: 2),
            spacing: 16
        ) {
            ForEach(filteredLocations) { location in
                dateLocationCard(location: location)
            }
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: cardAppearOffset)
    }
    
    // MARK: - 🌟 拡張されたデートロケーションカード
    private func dateLocationCard(location: DateLocation) -> some View {
        Button(action: {
            selectedLocation = location
            showingDateDetail = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // 背景画像セクション
                ZStack {
                    if UIImage(named: location.backgroundImage) != nil {
                        Image(location.backgroundImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [
                                location.type.color.opacity(0.6),
                                location.type.color.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 120)
                    }
                    
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    
                    VStack {
                        HStack {
                            // カテゴリアイコンと親密度要求レベル
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: location.type.icon)
                                        .font(.caption2)
                                    Text(location.type.displayName)
                                        .font(.system(size: 9, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(location.type.color.opacity(0.8))
                                .cornerRadius(6)
                                
                                // 🌟 親密度表示
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 8))
                                    Text("\(location.requiredIntimacy)")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                            }
                            Spacer()
                            
                            // 🌟 親密度ボーナス表示
                            if location.intimacyBonus > 0 {
                                VStack(spacing: 2) {
                                    Text("+\(location.intimacyBonus)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.yellow)
                                    
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.yellow)
                                }
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(6)
                            }
                        }
                        Spacer()
                        
                        // デート名をオーバーレイ
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(location.name)
                                    .font(adaptiveFontSizeForLocationName(location.name))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                
                                // 🌟 特別デート表示
                                if location.isSpecial {
                                    HStack(spacing: 2) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 8))
                                        Text("特別")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(12)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 詳細情報セクション
                VStack(alignment: .leading, spacing: 6) {
                    Text(location.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(location.duration)分")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // 🌟 拡張された利用可能性表示
                        Group {
                            if location.requiredIntimacy <= viewModel.character.intimacyLevel {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                    Text("利用可能")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.green)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                    Text("要 \(location.requiredIntimacy)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(cardColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // 🌟 拡張された利用不可時のオーバーレイ
            .overlay(
                Group {
                    if location.requiredIntimacy > viewModel.character.intimacyLevel {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    VStack(spacing: 4) {
                                        Text("親密度 \(location.requiredIntimacy) 必要")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                        
                                        Text("あと \(location.requiredIntimacy - viewModel.character.intimacyLevel)")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            )
                    }
                }
            )
            
            // 🌟 無限モードデートの特別表示
            .overlay(
                Group {
                    if location.type == .infinite {
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "infinity")
                                        .font(.caption2)
                                    Text("∞")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            )
        }
        .disabled(location.requiredIntimacy > viewModel.character.intimacyLevel)
        .scaleEffect(location.requiredIntimacy > viewModel.character.intimacyLevel ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: location.requiredIntimacy > viewModel.character.intimacyLevel)
    }
    
    // MARK: - Helper Functions
    private func adaptiveFontSizeForLocationName(_ text: String) -> Font {
        let characterCount = text.count
        
        switch characterCount {
        case 0...4:
            return .subheadline
        case 5...6:
            return .caption
        case 7...8:
            return .caption2
        default:
            return .system(size: 10, weight: .bold)
        }
    }
    
    private func animateCardsAppearance() {
        cardAppearOffset = 50
        cardAppearOpacity = 0
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            cardAppearOffset = 0
            cardAppearOpacity = 1
        }
        
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            shimmerOffset = 100
        }
    }
}

// MARK: - 🌟 統計カードコンポーネント
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 🌟 親密度フィルタービュー
struct IntimacyFilterView: View {
    @Binding var selectedRange: DateSelectorView.IntimacyRange
    let locationCounts: [DateSelectorView.IntimacyRange: Int]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(DateSelectorView.IntimacyRange.allCases, id: \.self) { range in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(range.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if range != .all && range != .infinite {
                            Text("親密度 \(range.intimacyRange.lowerBound) - \(range.intimacyRange.upperBound)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if range == .infinite {
                            Text("無限モード専用デートスポット")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    }
                    
                    Spacer()
                    
                    if let count = locationCounts[range] {
                        Text("\(count)件")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    if selectedRange == range {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedRange = range
                    dismiss()
                }
            }
            .navigationTitle("親密度レベル別フィルター")
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

// MARK: - 🌟 DateDetailView も拡張対応（継続使用 + 親密度ボーナス表示）
struct DateDetailView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    let location: DateLocation
    let onStartDate: (DateLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showConfirmation = false
    
    private var primaryColor: Color {
        location.type.color
    }
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    headerImageSection
                    basicInfoSection
                    
                    // 🌟 親密度ボーナス情報
                    intimacyBonusSection
                    
                    detailInfoSection
                    specialEffectsSection
                    startButtonSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("戻る") {
                        dismiss()
                    }
                    .foregroundColor(primaryColor)
                }
            }
            .alert("デートを開始しますか？", isPresented: $showConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("開始") {
                    onStartDate(location)
                    dismiss()
                }
            } message: {
                Text("\(location.name)でのデートを開始します。\n約\(location.duration)分間の特別な時間をお楽しみください。\n\n親密度ボーナス: +\(location.intimacyBonus)")
            }
        }
    }
    
    // MARK: - Header Image Section (継続使用)
    private var headerImageSection: some View {
        ZStack {
            if UIImage(named: location.backgroundImage) != nil {
                Image(location.backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: [primaryColor.opacity(0.6), primaryColor.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 200)
            }
            
            VStack(spacing: 16) {
                Image(systemName: location.type.icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                
                Text(location.type.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: location.timeOfDay.icon)
                            .font(.caption)
                        Text(location.timeOfDay.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("\(location.duration)分")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                    
                    // 🌟 親密度ボーナス表示
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        Text("+\(location.intimacyBonus)")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: primaryColor.opacity(0.3), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - 🌟 親密度ボーナスセクション
    private var intimacyBonusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundColor(.pink)
                
                Text("親密度ボーナス")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("+\(location.intimacyBonus)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.pink)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("デート完了ボーナス")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("このデートを完了すると +\(location.intimacyBonus) の親密度ボーナスを獲得")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(.pink.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Text("+\(location.intimacyBonus)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                    }
                }
                
                if location.isSpecial {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.pink)
                        
                        Text("特別デート: 通常より高い親密度ボーナス")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.pink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.yellow.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Basic Info Section (継続使用)
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("デートについて")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(location.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("必要親密度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(location.requiredIntimacy <= viewModel.character.intimacyLevel ? .green : .red)
                        
                        Text("\(location.requiredIntimacy)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(location.requiredIntimacy <= viewModel.character.intimacyLevel ? .green : .red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("利用可能季節")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        ForEach(location.availableSeasons, id: \.self) { season in
                            Text(season.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(primaryColor.opacity(0.2))
                                .foregroundColor(primaryColor)
                                .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Detail Info Section (継続使用)
    private var detailInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("このデートの特徴")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                detailRow(icon: "bubble.left.and.bubble.right", title: "会話スタイル", description: "この場所に適した特別な会話を楽しめます")
                detailRow(icon: "photo", title: "背景変更", description: "デート中は専用の背景に変更されます")
                detailRow(icon: "sparkles", title: "特別演出", description: "場所に応じた特別な効果やイベントが発生します")
                detailRow(icon: "heart.text.square", title: "思い出作り", description: "デートの記録が残り、後で振り返ることができます")
            }
        }
        .padding()
        .background(cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func detailRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(primaryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Special Effects Section (継続使用)
    private var specialEffectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("特別演出")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if location.specialEffects.isEmpty {
                Text("このデートでは基本的な演出をお楽しみいただけます")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 8) {
                    ForEach(location.specialEffects, id: \.self) { effect in
                        Text(effectDisplayName(effect))
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(primaryColor.opacity(0.1))
                            .foregroundColor(primaryColor)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding()
        .background(cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Start Button Section (継続使用)
    private var startButtonSection: some View {
        VStack(spacing: 16) {
            if location.requiredIntimacy > viewModel.character.intimacyLevel {
                VStack(spacing: 8) {
                    Text("親密度が足りません")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text("このデートを楽しむには親密度\(location.requiredIntimacy)以上が必要です")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("現在の親密度: \(viewModel.character.intimacyLevel) (あと\(location.requiredIntimacy - viewModel.character.intimacyLevel))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            } else {
                Button(action: {
                    showConfirmation = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("デートを開始")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        // 🌟 親密度ボーナス表示
                        Text("(+\(location.intimacyBonus))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [primaryColor, primaryColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: primaryColor.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .scaleEffect(0.98)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showConfirmation)
            }
        }
    }
    
    private func effectDisplayName(_ effect: String) -> String {
        switch effect {
        case "sakura_petals": return "🌸 桜の花びら"
        case "romantic_atmosphere": return "💕 ロマンチック"
        case "sunset_glow": return "🌅 夕焼け"
        case "wave_sounds": return "🌊 波の音"
        case "falling_leaves": return "🍂 落ち葉"
        case "crisp_air": return "🍃 爽やかな風"
        case "snow_falling": return "❄️ 雪景色"
        case "warm_atmosphere": return "♨️ 温かい雰囲気"
        case "carnival_lights": return "🎡 カーニバル"
        case "excitement": return "🎉 興奮"
        case "blue_lighting": return "💙 幻想的な光"
        case "peaceful_atmosphere": return "😌 穏やかな雰囲気"
        case "coffee_aroma": return "☕️ コーヒーの香り"
        case "cozy_atmosphere": return "🏠 居心地の良さ"
        case "elegant_atmosphere": return "✨ 上品な雰囲気"
        case "romantic_lighting": return "🕯️ ロマンチックな照明"
        case "dim_lighting": return "💡 落ち着いた照明"
        case "intimate_atmosphere": return "💑 親密な雰囲気"
        case "cooking_sounds": return "🍳 料理音"
        case "delicious_aromas": return "🍽️ 美味しい香り"
        case "city_lights": return "🌃 夜景"
        case "shopping_excitement": return "🛍️ お買い物"
        case "discovery": return "🔍 新発見"
        case "infinite_magic": return "♾️ 無限の魔法"
        case "transcendent_love": return "✨ 超越的な愛"
        case "limitless_imagination": return "🌌 無限の想像力"
        default: return effect
        }
    }
}

#Preview {
    DateSelectorView(viewModel: RomanceAppViewModel())
}
