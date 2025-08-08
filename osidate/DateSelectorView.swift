//
//  DateSelectorView.swift
//  osidate
//
//  Created by Apple on 2025/08/05.
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
    
    // カラーテーマ
    private var primaryColor: Color {
        Color(.systemPink)
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
        let availableLocations = DateLocation.availableLocations(for: viewModel.character.intimacyLevel)
        let seasonalLocations = availableLocations.filter { $0.isCurrentlyAvailable }
        
        var filtered = seasonalLocations
        
        if let selectedType = selectedDateType {
            filtered = filtered.filter { $0.type == selectedType }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
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
                        // ヘッダーセクション
                        headerSection
                        
                        // 検索バー
                        searchSection
                        
                        // デートタイプフィルター
                        dateTypeFilterSection
                        
                        // 現在の季節表示
                        currentSeasonSection
                        
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
            .onAppear {
                animateCardsAppearance()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(primaryColor)
                
                Text("特別な時間を選ぼう")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 8) {
                Text("親密度レベル: \(viewModel.character.intimacyLevel) (\(viewModel.character.intimacyTitle))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(primaryColor)
                
                Text("選択できるデートスポット: \(filteredLocations.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: cardAppearOffset)
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
    
    // MARK: - Date Type Filter Section
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
                        dateTypeChip(type: type)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .offset(y: cardAppearOffset)
        .opacity(cardAppearOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: cardAppearOffset)
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
        }
        .scaleEffect(selectedDateType == type ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedDateType)
    }
    
    // MARK: - Current Season Section
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
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4), value: cardAppearOffset)
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
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.5), value: cardAppearOffset)
    }
    
    private func dateLocationCard(location: DateLocation) -> some View {
        Button(action: {
            selectedLocation = location
            showingDateDetail = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // 背景画像
                ZStack {
                    Rectangle()
                        .fill(location.type.color.opacity(0.3))
                        .frame(height: 120)
                    
                    // プレースホルダー画像（実際のアプリでは背景画像を使用）
                    VStack {
                        Image(systemName: location.type.icon)
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(location.type.color)
                        
                        Text(location.type.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(location.type.color)
                    }
                    
                    // 時間帯アイコン
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: location.timeOfDay.icon)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // 詳細情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(location.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(location.duration)分")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                            Text("\(location.requiredIntimacy)+")
                                .font(.caption2)
                        }
                        .foregroundColor(location.requiredIntimacy <= viewModel.character.intimacyLevel ? .green : .red)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding()
            .background(cardColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .disabled(location.requiredIntimacy > viewModel.character.intimacyLevel)
        .opacity(location.requiredIntimacy > viewModel.character.intimacyLevel ? 0.6 : 1.0)
        .scaleEffect(location.requiredIntimacy > viewModel.character.intimacyLevel ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: location.requiredIntimacy > viewModel.character.intimacyLevel)
    }
    
    // MARK: - Animation Functions
    private func animateCardsAppearance() {
        // 初期状態設定
        cardAppearOffset = 50
        cardAppearOpacity = 0
        
        // アニメーション開始
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
            cardAppearOffset = 0
            cardAppearOpacity = 1
        }
        
        // シマーアニメーション開始
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            shimmerOffset = 100
        }
    }
}

// MARK: - Date Detail View
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
                    // ヘッダー画像
                    headerImageSection
                    
                    // 基本情報
                    basicInfoSection
                    
                    // 詳細情報
                    detailInfoSection
                    
                    // 特別効果
                    specialEffectsSection
                    
                    // 開始ボタン
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
                Text("\(location.name)でのデートを開始します。\n約\(location.duration)分間の特別な時間をお楽しみください。")
            }
        }
    }
    
    private var headerImageSection: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [primaryColor.opacity(0.6), primaryColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            
            VStack(spacing: 16) {
                Image(systemName: location.type.icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.white)
                
                Text(location.type.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: location.timeOfDay.icon)
                            .font(.caption)
                        Text(location.timeOfDay.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("\(location.duration)分")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .shadow(color: primaryColor.opacity(0.3), radius: 15, x: 0, y: 8)
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
                    
                    Text("現在の親密度: \(viewModel.character.intimacyLevel)")
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
        default: return effect
        }
    }
}

#Preview {
    DateSelectorView(viewModel: RomanceAppViewModel())
}
