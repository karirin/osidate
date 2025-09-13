//
//  DateSelectorView.swift - ボタン式検索・フィルター対応版
//  osidate
//
//  検索とフィルターをボタンクリックで表示
//

import SwiftUI
import FirebaseAuth

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
    @State private var showUnlockedOnly = false
    
    // 🌟 新しい状態変数（表示制御用）
    @State private var showingSearchBar = false
    @State private var showingFilters = false
    @State private var showingUnlockFilter = false
    @State private var showingIntimacyRangeFilter = false
    @State private var showingDateTypeFilter = false
    
    // 🔧 修正: Sheet表示の問題を解決するための状態管理
    @State private var isSheetReady = false
    @State private var pendingLocation: DateLocation? = nil
    
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
    
    // 🌟 すべてのデートスポット取得（無限モード含む）
    private var allDateLocations: [DateLocation] {
        var locations = DateLocation.availableDateLocations
        
        return locations
    }
    
    // 🌟 フィルタリングされたロケーション（全スポット対応）
    private var filteredLocations: [DateLocation] {
        var locations = allDateLocations
        
        // 🌟 解放済みフィルター
        if showUnlockedOnly {
            locations = locations.filter { $0.requiredIntimacy <= viewModel.character.intimacyLevel }
        }
        
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
    
    // 🌟 親密度レベル別のロケーション数（全スポット対応）
    private var locationCounts: [IntimacyRange: Int] {
        let allLocations = allDateLocations
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
    
    // 🌟 利用可能・ロック済みの統計
    private var availabilityStats: (available: Int, locked: Int) {
        let available = allDateLocations.filter { $0.requiredIntimacy <= viewModel.character.intimacyLevel }.count
        let locked = allDateLocations.filter { $0.requiredIntimacy > viewModel.character.intimacyLevel }.count
        return (available: available, locked: locked)
    }
    
    // 🌟 アクティブなフィルター数を計算
    private var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if showUnlockedOnly { count += 1 }
        if selectedIntimacyRange != .all { count += 1 }
        if selectedDateType != nil { count += 1 }
        return count
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
                    if viewModel.shouldShowBannerAds {
                        BannerAdView()
                            .frame(height: 60)
                    }
                    LazyVStack(spacing: 20) {
                        intimacyStatusSection
                        
                        // 🌟 新しい検索・フィルターボタンセクション
                        searchAndFilterButtonsSection
                        
                        // 🌟 検索バー（条件付き表示）
                        if showingSearchBar {
                            searchSection
                        }
                        
                        // 🌟 フィルターセクション（条件付き表示）
                        if showingFilters {
                            filterSectionsContainer
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
            .sheet(item: $selectedLocation) { location in
                DateDetailViewWrapper(
                    viewModel: viewModel,
                    location: location,
                    onStartDate: { dateLocation in
                        handleDateStart(dateLocation)
                    }
                )
            }
            .sheet(isPresented: $showingIntimacyFilter) {
                IntimacyFilterView(
                    selectedRange: $selectedIntimacyRange,
                    locationCounts: locationCounts
                )
            }
            .onAppear {
                print("🔧 DateSelectorView.onAppear - 初期化開始")
                animateCardsAppearance()
                
                // シートの準備完了フラグを設定
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSheetReady = true
                    
                    // 待機中のロケーションがある場合は表示
                    if let pending = pendingLocation {
                        selectedLocation = pending
                        pendingLocation = nil
                        showingDateDetail = true
                    }
                }
            }
            .onDisappear {
                print("🔧 DateSelectorView.onDisappear")
                isSheetReady = false
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func dateLocationCardWithAdInfo(location: DateLocation) -> some View {
        Button(action: {
            handleLocationCardTap(location)
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
                                
                                // 親密度表示
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 8))
                                    Text("\(location.requiredIntimacy)")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    location.requiredIntimacy <= viewModel.character.intimacyLevel
                                    ? Color.green.opacity(0.8)
                                    : Color.red.opacity(0.8)
                                )
                                .cornerRadius(4)
                            }
                            Spacer()
                            
                            // 🌟 広告必須マークと親密度ボーナス表示
                            VStack(spacing: 4) {
                                // 広告必須マーク
                                if viewModel.isAdRequiredForDate(at: location) &&
                                    location.requiredIntimacy <= viewModel.character.intimacyLevel {
                                    HStack(spacing: 2) {
                                        Image(systemName: "tv.fill")
                                            .font(.system(size: 8))
                                        Text("広告")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(4)
                                }
                                
                                // 🔧 修正：親密度ボーナス表示（広告ボーナス除外）
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
                                
                                // ロック状態表示
                                if location.requiredIntimacy > viewModel.character.intimacyLevel {
                                    HStack(spacing: 2) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 8))
                                        Text("ロック中")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                                } else if location.isSpecial {
                                    HStack(spacing: 2) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 8))
                                        Text("特別")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundColor(.yellow)
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
                        
                        // 🌟 広告必須表示
                        if viewModel.isAdRequiredForDate(at: location) &&
                            location.requiredIntimacy <= viewModel.character.intimacyLevel {
                            HStack(spacing: 4) {
                                Image(systemName: "tv")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        // 利用可能性表示
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
            
            // ロック状態のオーバーレイ（既存コード）
            .overlay(
                Group {
                    if location.requiredIntimacy > viewModel.character.intimacyLevel {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2)
                                    
                                    VStack(spacing: 6) {
                                        Text("親密度 \(location.requiredIntimacy) 必要")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .shadow(color: .black.opacity(0.7), radius: 1)
                                        
                                        Text("あと \(location.requiredIntimacy - viewModel.character.intimacyLevel)")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.red.opacity(0.7))
                                            .cornerRadius(8)
                                    }
                                    
                                    Text("💕 もっと会話して親密度を上げよう")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.6))
                                        .cornerRadius(6)
                                }
                            )
                            .animation(.easeInOut(duration: 0.3), value: location.requiredIntimacy > viewModel.character.intimacyLevel)
                    }
                }
            )
        }
        .scaleEffect(location.requiredIntimacy > viewModel.character.intimacyLevel ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: location.requiredIntimacy > viewModel.character.intimacyLevel)
    }

    
    private func handleDateStart(_ dateLocation: DateLocation) {
        print("🔧 DateSelectorView: 広告必須デート開始処理")
        
        // 親密度チェック
        guard dateLocation.requiredIntimacy <= viewModel.character.intimacyLevel else {
            print("❌ 親密度不足のため詳細画面のみ表示")
            selectedLocation = nil
            return
        }
        
        // 🌟 広告必須チェック
        if viewModel.isAdRequiredForDate(at: dateLocation) {
            print("📺 広告視聴が必要なデート - ViewModelで処理")
            
            // 詳細画面を閉じる
            selectedLocation = nil
            
            // ViewModelの広告必須デート開始メソッドを使用
            viewModel.startDateWithAdReward(at: dateLocation) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ 広告視聴完了 - デート開始成功")
                        dismiss()
                    } else {
                        print("❌ 広告視聴失敗またはキャンセル")
                        // エラーメッセージはViewModelで処理済み
                    }
                }
            }
        } else {
            // 広告不要な場合（通常は使用されない）
            print("ℹ️ 広告不要デート - 直接開始")
            viewModel.startDate(at: dateLocation)
            selectedLocation = nil
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
    
    // 🔧 修正: デートロケーションカードのタップ処理を改善
    private func handleLocationCardTap(_ location: DateLocation) {
        print("🔧 DateSelectorView: ロケーションカードタップ - \(location.name)")
        
        if isSheetReady {
            selectedLocation = location
            print("🔧 Sheet即座表示")
        } else {
            // まだ準備ができていない場合は待機
            pendingLocation = location
            print("🔧 Sheet準備待ち - \(location.name)を待機リストに追加")
        }
    }
    
    private var intimacyStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
//                if let urlString = viewModel.character.iconURL,
//                   let url = URL(string: urlString),
//                   !urlString.isEmpty {
//
//                    AsyncImage(url: url) { phase in
//                        switch phase {
//                        case .success(let image):
//                            image
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(width: 30, height: 30)
//                                .clipShape(Circle())
//                        case .failure(_):
//                            defaultIcon   // 読み込み失敗時
//
//                        case .empty:
//                            Circle()      // 読み込み中
//                                .fill(Color.gray.opacity(0.3))
//                                .frame(width: 30, height: 30)
//                                .overlay(ProgressView().scaleEffect(0.8))
//
//                        @unknown default:
//                            defaultIcon
//                        }
//                    }
//                    .id(urlString)
//
//                } else {
//                    defaultIcon           // iconURL が無いとき
//                }
                CharacterIconView(character: viewModel.character, size: 30, enableFloating: false)
                Text("関係性: \(viewModel.character.intimacyTitle)")
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
                        Text("現在の親密度: \(viewModel.character.intimacyLevel)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if viewModel.character.intimacyToNextLevel > 0 {
                            Text("次の関係性まで: \(viewModel.character.intimacyToNextLevel)")
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
    
    private var defaultIcon: some View {
        Circle()
            .fill(Color.brown)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: viewModel.character.iconName)
                    .font(.system(size: 30 * 0.4))
                    .foregroundColor(.white)
            )
    }
    
    private func dateLocationCard(location: DateLocation) -> some View {
        Button(action: {
            handleLocationCardTap(location)
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
                                
                                // 親密度表示
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 8))
                                    Text("\(location.requiredIntimacy)")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    location.requiredIntimacy <= viewModel.character.intimacyLevel
                                    ? Color.green.opacity(0.8)
                                    : Color.red.opacity(0.8)
                                )
                                .cornerRadius(4)
                            }
                            Spacer()
                            
                            // 🌟 サブスク対応のステータス表示
                            VStack(spacing: 4) {
                                // 🔧 修正：プレミアム会員は広告マークを表示しない
                                if !viewModel.isPremiumUser &&
                                   viewModel.isAdRequiredForDate(at: location) &&
                                   location.requiredIntimacy <= viewModel.character.intimacyLevel {
                                    HStack(spacing: 2) {
                                        Image(systemName: "tv.fill")
                                            .font(.system(size: 8))
                                        Text("広告")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(4)
                                } else if viewModel.isPremiumUser &&
                                         location.requiredIntimacy <= viewModel.character.intimacyLevel {
                                    // プレミアム会員表示
                                    HStack(spacing: 2) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 8))
                                        Text("Premium")
                                            .font(.system(size: 7, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        LinearGradient(
                                            colors: [.yellow.opacity(0.8), .purple.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(4)
                                }
                                
                                // 親密度ボーナス表示
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
                                
                                // ロック状態表示
                                if location.requiredIntimacy > viewModel.character.intimacyLevel {
                                    HStack(spacing: 2) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 8))
                                        Text("ロック中")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                                } else if location.isSpecial {
                                    HStack(spacing: 2) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 8))
                                        Text("特別")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundColor(.yellow)
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
                        
                        // 🌟 サブスク対応の広告表示
                        if !viewModel.isPremiumUser &&
                           viewModel.isAdRequiredForDate(at: location) &&
                           location.requiredIntimacy <= viewModel.character.intimacyLevel {
                            HStack(spacing: 4) {
                                Image(systemName: "tv")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                        } else if viewModel.isPremiumUser {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                Text("広告なし")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.purple)
                        }
                        
                        Spacer()
                        
                        // 利用可能性表示
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
            
            // ロック状態のオーバーレイ（既存コードと同じ）
            .overlay(
                Group {
                    if location.requiredIntimacy > viewModel.character.intimacyLevel {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "lock.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2)
                                    
                                    VStack(spacing: 6) {
                                        Text("親密度 \(location.requiredIntimacy) 必要")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .shadow(color: .black.opacity(0.7), radius: 1)
                                        
                                        Text("あと \(location.requiredIntimacy - viewModel.character.intimacyLevel)")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.red.opacity(0.7))
                                            .cornerRadius(8)
                                    }
                                    
                                    Text("💕 もっと会話して親密度を上げよう")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.6))
                                        .cornerRadius(6)
                                }
                            )
                            .animation(.easeInOut(duration: 0.3), value: location.requiredIntimacy > viewModel.character.intimacyLevel)
                    }
                }
            )
        }
        .scaleEffect(location.requiredIntimacy > viewModel.character.intimacyLevel ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: location.requiredIntimacy > viewModel.character.intimacyLevel)
    }
    
    // MARK: - 🌟 新しい検索・フィルターボタンセクション
    private var searchAndFilterButtonsSection: some View {
        VStack(spacing: 16) {
            // メインボタン行
            HStack(spacing: 12) {
                // 検索ボタン
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingSearchBar.toggle()
                        if showingSearchBar {
                            showingFilters = false
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                        Text("検索")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        // 検索中インジケーター
                        if !searchText.isEmpty {
                            Text("•")
                                .foregroundColor(.green)
                        }
                    }
                    .foregroundColor(showingSearchBar ? .white : primaryColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        showingSearchBar
                        ? primaryColor
                        : primaryColor.opacity(0.1)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // フィルターボタン
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingFilters.toggle()
                        if showingFilters {
                            showingSearchBar = false
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .medium))
                        Text("フィルター")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        // アクティブフィルター数
                        if activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(.red)
                                .clipShape(Circle())
                        }
                    }
                    .foregroundColor(showingFilters ? .white : accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        showingFilters
                        ? accentColor
                        : accentColor.opacity(0.1)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            
            // アクティブフィルターの表示
            if activeFilterCount > 0 {
                activeFiltersDisplay
            }
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: cardAppearOffset)
    }
    
    // MARK: - アクティブフィルター表示
    private var activeFiltersDisplay: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !searchText.isEmpty {
                    ActiveFilterChip(
                        icon: "magnifyingglass",
                        text: "「\(searchText)」",
                        color: primaryColor
                    ) {
                        searchText = ""
                    }
                }
                
                if showUnlockedOnly {
                    ActiveFilterChip(
                        icon: "checkmark.circle",
                        text: "解放済みのみ",
                        color: .green
                    ) {
                        showUnlockedOnly = false
                    }
                }
                
                if selectedIntimacyRange != .all {
                    ActiveFilterChip(
                        icon: "heart.fill",
                        text: selectedIntimacyRange.displayName,
                        color: .pink
                    ) {
                        selectedIntimacyRange = .all
                    }
                }
                
                if let selectedType = selectedDateType {
                    ActiveFilterChip(
                        icon: selectedType.icon,
                        text: selectedType.displayName,
                        color: selectedType.color
                    ) {
                        selectedDateType = nil
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - フィルターセクションコンテナ
    private var filterSectionsContainer: some View {
        VStack(spacing: 20) {
            // 解放済みフィルター
            unlockFilterSection
            
            // 親密度範囲フィルター
            intimacyRangeFilterSection
            
            // デートタイプフィルター
            dateTypeFilterSection
        }
        .padding()
        .background(cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Search Section (既存)
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("デートスポットを検索...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    showingSearchBar = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - 🌟 解放済みフィルター（レイアウト調整）
    private var unlockFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("表示設定")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showUnlockedOnly = false
                    }
                }) {
                    FilterChip(
                        icon: "eye",
                        text: "すべて表示",
                        isSelected: !showUnlockedOnly,
                        color: primaryColor
                    )
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showUnlockedOnly = true
                    }
                }) {
                    FilterChip(
                        icon: "checkmark.circle",
                        text: "解放済みのみ",
                        isSelected: showUnlockedOnly,
                        color: .green
                    )
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - 親密度範囲フィルター（レイアウト調整）
    private var intimacyRangeFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("親密度レベル")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IntimacyRange.allCases, id: \.self) { range in
                        if range != .infinite || viewModel.character.unlockedInfiniteMode {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedIntimacyRange = selectedIntimacyRange == range ? .all : range
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(range.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    if let count = locationCounts[range] {
                                        Text("(\(count))")
                                            .font(.caption2)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedIntimacyRange == range
                                    ? .pink.opacity(0.2)
                                    : Color.gray.opacity(0.1)
                                )
                                .foregroundColor(
                                    selectedIntimacyRange == range
                                    ? .pink
                                    : .secondary
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Date Type Filter Section (レイアウト調整)
    private var dateTypeFilterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カテゴリ")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateType.allCases, id: \.self) { type in
                        if type != .infinite || viewModel.character.unlockedInfiniteMode {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDateType = selectedDateType == type ? nil : type
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.caption)
                                    Text(type.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 12)
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
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func clearAllFilters() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            searchText = ""
            showUnlockedOnly = false
            selectedIntimacyRange = .all
            selectedDateType = nil
            showingSearchBar = false
            showingFilters = false
        }
    }
    
    // 残りのセクション（無限モード、デートロケーション等）は元のコードと同じ
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

// 統計バッジコンポーネント
struct StatBadge: View {
    let icon: String
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// アクティブフィルターチップコンポーネント
struct ActiveFilterChip: View {
    let icon: String
    let text: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// フィルターチップコンポーネント
struct FilterChip: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(isSelected ? color : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected
            ? color.opacity(0.2)
            : Color.gray.opacity(0.1)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected
                    ? color.opacity(0.5)
                    : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// 🌟 元のコンポーネントも含める（DateDetailView, UnlockMotivationView, StatCard, IntimacyFilterView）
// 元のコードのこれらのコンポーネントはそのまま保持

struct DateDetailView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    let location: DateLocation
    let onStartDate: (DateLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // 🌟 広告関連の状態
    @State private var showAdRequiredConfirmation = false
    @State private var isWatchingAd = false
    @State private var showAdFailedAlert = false
    @State private var showAdNotAvailableAlert = false
    
    private var primaryColor: Color {
        location.type.color
    }
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }
    
    private var isUnlocked: Bool {
        location.requiredIntimacy <= viewModel.character.intimacyLevel
    }
    
    private var intimacyDeficit: Int {
        max(0, location.requiredIntimacy - viewModel.character.intimacyLevel)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    headerImageSection
                    
                    // ロック状態の場合は特別なセクションを表示
                    if !isUnlocked {
                        lockStatusSection
                    }
                    
                    basicInfoSection
                    intimacyBonusSection
                    detailInfoSection
                    specialEffectsSection
                    
                    // 🔧 削除：広告必須の説明セクションを削除
                    // if isUnlocked {
                    //     adRequirementSection
                    // }
                    
                    // ボタンセクション
                    if isUnlocked {
                        startButtonSection
                    } else {
                        unlockMotivationSection
                    }
                    
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
            // 🌟 広告視聴確認ダイアログ
            .alert("デート開始には広告の視聴が必要です", isPresented: $showAdRequiredConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("広告を見る") {
                    // アラートを閉じ切るまで少し待ってから表示
                    showAdRequiredConfirmation = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        watchAdAndStartDate()
                    }
                }
            } message: {
                Text("\(location.name)でのデートを開始するには、短い広告をご視聴ください。\n\n広告視聴後、素敵なデートが始まります！✨")
            }
            // 🌟 広告視聴失敗アラート
            .alert("広告の視聴に失敗しました", isPresented: $showAdFailedAlert) {
                Button("OK", role: .cancel) { }
                Button("再試行") {
                    watchAdAndStartDate()
                }
            } message: {
                Text("申し訳ございません。広告の読み込みに問題が発生しました。\n\nネットワーク接続を確認して、もう一度お試しください。")
            }
            // 🌟 広告利用不可アラート
            .alert("広告が利用できません", isPresented: $showAdNotAvailableAlert) {
                Button("OK", role: .cancel) { }
                Button("再読み込み") {
                    // 広告を再読み込み
                    viewModel.adMobManager.loadRewardedAd()
                }
            } message: {
                Text("現在広告が利用できません。\n\nしばらく時間をおいてから再度お試しください。")
            }
        }
    }
    
    // MARK: - 🔧 修正されたスタートボタンセクション（親密度ボーナス表示を削除）
    private var startButtonSection: some View {
        VStack(spacing: 16) {
            // 🌟 メインのデート開始ボタン（広告視聴必須）
            Button(action: {
                if let userID = Auth.auth().currentUser?.uid,
                   ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"].contains(userID) {
                    viewModel.startDate(at: location)
                } else {
                    showAdRequiredConfirmation = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "tv.fill")
                        .font(.system(size: 18, weight: .medium))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("広告を見てデート開始")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        // 🔧 削除：広告視聴による親密度ボーナス表示を削除
                        Text("親密度 +\(location.intimacyBonus) 獲得")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
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
            .disabled(isWatchingAd)
            .opacity(isWatchingAd ? 0.6 : 1.0)
            
            // 🌟 広告視聴中の表示
            if isWatchingAd {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(primaryColor)
                    
                    Text("広告を準備中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // 🔧 修正：補足説明から親密度ボーナスの言及を削除
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("広告は通常15-30秒程度です")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("デート完了で親密度ボーナス獲得！")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    

    private func watchAdAndStartDate() {
        print("🎬 広告視聴開始処理")
        
        // 広告が利用可能かチェック
        guard viewModel.adMobManager.canShowAd else {
            print("❌ 広告が利用できません")
            // 広告を再読み込み
            viewModel.adMobManager.loadRewardedAd()
            showAdNotAvailableAlert = true
            return
        }
        
        isWatchingAd = true
        
        // 🌟 修正：ViewModelのstartDateWithAdRewardメソッドを使用
        let dismissAction = dismiss
        viewModel.startDateWithAdReward(at: location) { success in
            DispatchQueue.main.async {
                isWatchingAd = false

                if success {
                    print("✅ 広告視聴完了 - デート開始成功")
                    // 詳細画面を閉じる
                    dismissAction()
                } else {
                    print("❌ 広告視聴失敗")
                    showAdFailedAlert = true
                }
            }
        }
    }
    
    // MARK: - 🌟 広告視聴成功後のデート開始処理
    private func startDateAfterAdSuccess() {
        print("🎉 広告視聴成功 - デート開始処理")
        
        // 🌟 修正：ViewModelのstartDateメソッドを直接呼び出し
        viewModel.startDate(at: location)
        
        // 詳細画面を閉じる
        dismiss()
    }
    
    // MARK: - 既存のビューコンポーネント（変更なし）
    
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
                    
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        // 🔧 削除：広告ボーナス込みの表示を元の表示に戻す
                        Text("+\(location.intimacyBonus)")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
                }
            }.opacity(isUnlocked ? 1 : 0.8)
            
            if !isUnlocked {
                Rectangle()
                    .fill(.black.opacity(0.4))
                    .frame(height: 200)
                
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white)
                    
                    Text("ロック中")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: primaryColor.opacity(0.3), radius: 15, x: 0, y: 8)
    }
    
    // ロック状態セクション、基本情報セクションなど、既存のコンポーネントは同じ
    private var lockStatusSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.red.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 8) {
                    Text("このデートスポットはロック中です")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("親密度 \(location.requiredIntimacy) に達すると解放されます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("現在の進捗")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(viewModel.character.intimacyLevel) / \(location.requiredIntimacy)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(primaryColor)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor, primaryColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * min(1.0, Double(viewModel.character.intimacyLevel) / Double(location.requiredIntimacy)),
                                height: 8
                            )
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("あと \(intimacyDeficit) で解放")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(Double(viewModel.character.intimacyLevel) / Double(location.requiredIntimacy) * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(.red.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.red.opacity(0.2), lineWidth: 1)
        )
    }
    
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
                            .foregroundColor(isUnlocked ? .green : .red)
                        
                        Text("\(location.requiredIntimacy)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(isUnlocked ? .green : .red)
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
    
    // 🔧 修正：親密度ボーナスセクション（広告ボーナスの説明を削除）
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
                
                // 🔧 削除：広告ボーナス込みの表示を元に戻す
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
                        
                        Text("デートの完了で +\(location.intimacyBonus) の親密度ボーナス")
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
                
                // 🔧 削除：広告ボーナスの説明セクションを削除
                // if isUnlocked {
                //     HStack(spacing: 12) {
                //         VStack(alignment: .leading, spacing: 4) {
                //             Text("広告視聴ボーナス")
                //                 .font(.subheadline)
                //                 .fontWeight(.semibold)
                //                 .foregroundColor(.primary)
                //
                //             Text("広告視聴への感謝として +1 の追加ボーナス")
                //                 .font(.caption)
                //                 .foregroundColor(.secondary)
                //         }
                //
                //         Spacer()
                //
                //         ZStack {
                //             Circle()
                //                 .fill(.blue.opacity(0.2))
                //                 .frame(width: 40, height: 40)
                //
                //             Text("+1")
                //                 .font(.caption)
                //                 .fontWeight(.bold)
                //                 .foregroundColor(.blue)
                //         }
                //     }
                // }
                
                if location.isSpecial {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text("特別デート: 通常より高い親密度ボーナス")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.yellow)
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
                
                if !isUnlocked {
                    detailRow(icon: "lock.fill", title: "解放後の特典", description: "親密度が\(location.requiredIntimacy)に達すると、この特別な体験を楽しむことができます")
                }
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
    
    private var specialEffectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("特別演出")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if location.specialEffects.isEmpty {
                Text(isUnlocked
                     ? "このデートでは基本的な演出をお楽しみいただけます"
                     : "解放後、基本的な演出をお楽しみいただけます"
                )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 8) {
                    ForEach(location.specialEffects, id: \.self) { effect in
                        Text(effectDisplayName(effect))
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(primaryColor.opacity(isUnlocked ? 0.1 : 0.05))
                            .foregroundColor(primaryColor.opacity(isUnlocked ? 1.0 : 0.6))
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
    
    private var unlockMotivationSection: some View {
        VStack(spacing: 16) {
            Text("解放条件を満たしていません")
                .font(.headline)
                .foregroundColor(.secondary)
            
//            Button("詳細を見る") {
//                showUnlockMotivation = true
//            }
//            .foregroundColor(primaryColor)
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
        // 他のエフェクトも同様に追加
        default: return effect
        }
    }
}

// MARK: - 🌟 情報行コンポーネント
struct InfoRowView: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
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
}

struct UnlockMotivationView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    let targetLocation: DateLocation
    let currentIntimacy: Int
    let requiredIntimacy: Int
    @Environment(\.dismiss) private var dismiss
    
    private var intimacyDeficit: Int {
        requiredIntimacy - currentIntimacy
    }
    
    private var estimatedDaysToUnlock: Int {
        let avgDailyGain = max(1, viewModel.getAverageMessagesPerDay() * 2) // メッセージ1つあたり平均2の親密度と仮定
        return max(1, Int(ceil(Double(intimacyDeficit) / avgDailyGain)))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // ターゲット情報
                    VStack(spacing: 16) {
                        Image(systemName: targetLocation.type.icon)
                            .font(.system(size: 48))
                            .foregroundColor(targetLocation.type.color)
                        
                        Text(targetLocation.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("解放まであと \(intimacyDeficit) の親密度が必要です")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // 進捗表示
                    VStack(spacing: 12) {
                        ProgressView(value: Double(currentIntimacy), total: Double(requiredIntimacy))
                            .progressViewStyle(LinearProgressViewStyle(tint: targetLocation.type.color))
                            .frame(height: 8)
                        
                        HStack {
                            Text("現在: \(currentIntimacy)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("目標: \(requiredIntimacy)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    
                    // 解放方法
                    VStack(alignment: .leading, spacing: 16) {
                        Text("親密度を上げる方法")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 12) {
                            motivationRow(icon: "message.fill", title: "日常会話", points: "1-3", description: "毎日の何気ない会話で親密度アップ")
                            motivationRow(icon: "heart.fill", title: "デート", points: "5-20", description: "デートを完了すると大幅に親密度アップ")
                            motivationRow(icon: "text.bubble.fill", title: "長いメッセージ", points: "2-5", description: "感情を込めた長いメッセージで親密度ボーナス")
                            motivationRow(icon: "calendar.circle.fill", title: "継続利用", points: "1-2", description: "毎日アプリを使うことで親密度が自然に上昇")
                        }
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .cornerRadius(16)
                    
                    // 予想期間
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.green)
                            Text("解放予想期間")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("現在のペースなら約 \(estimatedDaysToUnlock) 日で解放できそうです！")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("💡 毎日会話することで、より早く解放できます")
                            .font(.caption)
                            .foregroundColor(.green)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 閉じるボタン
                    Button("頑張って親密度を上げよう！") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(targetLocation.type.color)
                    .cornerRadius(16)
                }
                .padding(20)
            }
            .navigationTitle("解放への道のり")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func motivationRow(icon: String, title: String, points: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("+\(points)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

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

struct DateDetailViewWrapper: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    let location: DateLocation
    let onStartDate: (DateLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isViewReady = false
    
    var body: some View {
        Group {
            if isViewReady {
                // 🌟 広告必須対応のDateDetailViewを使用
                DateDetailView(
                    viewModel: viewModel,
                    location: location,
                    onStartDate: { location in
                        // 🌟 広告必須デート開始処理を統合
                        handleAdRequiredDateStart(location)
                    }
                )
            } else {
                // 読み込み中の表示
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("準備中...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            print("🔧 DateDetailViewWrapper.onAppear")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isViewReady = true
                }
            }
        }
        .onDisappear {
            print("🔧 DateDetailViewWrapper.onDisappear")
            isViewReady = false
        }
    }
    
    // MARK: - 🌟 広告必須デート開始の統合処理
    private func handleAdRequiredDateStart(_ location: DateLocation) {
        print("🎬 DateDetailViewWrapper: 広告必須デート開始統合処理")
        
        // 親密度チェック
        guard location.requiredIntimacy <= viewModel.character.intimacyLevel else {
            print("❌ 親密度不足 - 詳細画面を閉じる")
            dismiss()
            return
        }
        
        // 🌟 ViewModelの広告必須デート開始メソッドを使用
        viewModel.startDateWithAdReward(at: location) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ 広告視聴＆デート開始成功")
                    // 成功時は onStartDate を呼び出さず、ViewModelで完結
                    dismiss()
                } else {
                    print("❌ 広告視聴失敗 - 詳細画面は開いたまま")
                    // 失敗時は詳細画面を開いたままにして、ユーザーが再試行できるようにする
                }
            }
        }
    }
}

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

#Preview {
//    DateSelectorView(viewModel: RomanceAppViewModel())
    TopView()
}
