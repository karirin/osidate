//
//  AdminChatAnalyticsView.swift
//  osidate
//
//  管理者向けチャット分析画面 - 全ユーザーのメッセージ監視（日別統計付き）
//

import SwiftUI
import Firebase
import FirebaseDatabase
import FirebaseAuth

struct AdminChatAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var allMessages: [AdminMessage] = []
    @State private var users: [AdminUser] = []
    @State private var characters: [AdminCharacter] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedUserFilter = ""
    @State private var selectedCharacterFilter = ""
    @State private var showingMessageDetail = false
    @State private var selectedMessage: AdminMessage?
    @State private var editingMessage: AdminMessage?
    @State private var editingText = ""
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var messageToDelete: AdminMessage?
    @State private var showingDailyStats = true // 日別統計の表示制御
    
    private let database = Database.database().reference()
    
    // 管理者権限チェック
    private let adminUserIds = [
        "vVceNdjseGTBMYP7rMV9NKZuBaz1",
        "ol3GjtaeiMhZwprk7E3zrFOh2VJ2",
        "8sW4V2Ej7ScAYKwINppoISjDKqX2"
    ]
    
    private var isCurrentUserAdmin: Bool {
        guard let userID = Auth.auth().currentUser?.uid else { return false }
        return adminUserIds.contains(userID)
    }
    
    // フィルタリングされたメッセージ
    private var filteredMessages: [AdminMessage] {
        var messages = allMessages
        
        // 検索フィルター
        if !searchText.isEmpty {
            messages = messages.filter { message in
                message.text.localizedCaseInsensitiveContains(searchText) ||
                message.userName.localizedCaseInsensitiveContains(searchText) ||
                message.characterName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // ユーザーフィルター
        if !selectedUserFilter.isEmpty {
            messages = messages.filter { $0.userId == selectedUserFilter }
        }
        
        // キャラクターフィルター
        if !selectedCharacterFilter.isEmpty {
            messages = messages.filter { $0.characterId == selectedCharacterFilter }
        }
        
        return messages.sorted { $0.timestamp > $1.timestamp }
    }
    
    // 日別統計データ
    private var dailyStats: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: now) ?? now
        
        var dailyCount: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 過去7日間の日付を初期化
        for i in 0...6 {
            if let date = calendar.date(byAdding: .day, value: -i, to: now) {
                let dateString = dateFormatter.string(from: date)
                dailyCount[dateString] = 0
            }
        }
        
        // メッセージ数をカウント
        for message in allMessages {
            if message.timestamp >= sevenDaysAgo {
                let dateString = dateFormatter.string(from: message.timestamp)
                dailyCount[dateString, default: 0] += 1
            }
        }
        
        // 結果を配列に変換してソート
        return dailyCount.compactMap { key, value in
            guard let date = dateFormatter.date(from: key) else { return nil }
            return (date: date, count: value)
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !isCurrentUserAdmin {
                    unauthorizedView
                } else if isLoading {
                    loadingView
                } else {
                    VStack(spacing: 0) {
                        // 統計サマリー
                        statisticsView
                        
                        // 日別統計（折りたたみ可能）
                        dailyStatsSection
                        
                        // フィルターセクション
                        filterSection
                        
                        // メッセージリスト
                        messagesList
                    }
                }
            }
            .navigationTitle("チャット分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                if isCurrentUserAdmin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: refreshData) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .onAppear {
            if isCurrentUserAdmin {
                loadAllData()
            }
        }
        .alert("メッセージを編集", isPresented: $showingEditAlert) {
            TextField("メッセージ", text: $editingText)
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                saveEditedMessage()
            }
        }
        .alert("メッセージを削除", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                deleteMessage()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("このメッセージを削除しますか？この操作は元に戻せません。")
        }
    }
    
    // MARK: - 未承認ユーザー画面
    private var unauthorizedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("アクセス権限がありません")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("この機能は管理者のみ利用できます")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - ローディング画面
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("データを読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 統計サマリー
    private var statisticsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatisticCard(
                    icon: "message",
                    title: "総メッセージ数",
                    value: allMessages.count,
                    gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

                StatisticCard(
                    icon: "person.3",
                    title: "アクティブユーザー",
                    value: users.count,
                    gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

                StatisticCard(
                    icon: "person.crop.circle",
                    title: "登録キャラクター",
                    value: characters.count,
                    gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }

            HStack(spacing: 20) {
                StatisticCard(
                    icon: "clock",
                    title: "今日のメッセージ",
                    value: todayMessageCount,
                    gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

                StatisticCard(
                    icon: "person.crop.circle.badge.plus",
                    title: "ユーザーメッセージ",
                    value: userMessageCount,
                    gradient: LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

                StatisticCard(
                    icon: "brain",
                    title: "AIメッセージ",
                    value: aiMessageCount,
                    gradient: LinearGradient(colors: [.mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    
    // MARK: - 日別統計セクション
    private var dailyStatsSection: some View {
        VStack(spacing: 0) {
            // ヘッダー
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingDailyStats.toggle()
                }
            }) {
                HStack {
                    Text("過去7日間の統計")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: showingDailyStats ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showingDailyStats ? 0 : 180))
                }
                .foregroundColor(.primary)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            
            if showingDailyStats {
                VStack(spacing: 16) {
                    // 日別チャート
                    dailyChart
                    
                    // 日別詳細リスト
                    dailyDetailList
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - 日別チャート
    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日別メッセージ数")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(dailyStats, id: \.date) { stat in
                    VStack(spacing: 4) {
                        // バー
                        RoundedRectangle(cornerRadius: 2)
                            .fill(stat.count > 0 ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 35, height: max(CGFloat(stat.count) * 2, 4))
                            .animation(.easeInOut(duration: 0.5), value: stat.count)
                        
                        // 日付ラベル
                        Text(formatChartDate(stat.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        // 数値ラベル
                        Text("\(stat.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(stat.count > 0 ? .blue : .secondary)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 日別詳細リスト
    private var dailyDetailList: some View {
        VStack(spacing: 8) {
            HStack {
                Text("詳細データ")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("合計: \(dailyStats.reduce(0) { $0 + $1.count })件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 6) {
                ForEach(dailyStats.reversed(), id: \.date) { stat in
                    HStack {
                        Text(formatDetailDate(stat.date))
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(stat.count)件")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(stat.count > 0 ? .blue : .secondary)
                        
                        // 視覚的インジケーター
                        RoundedRectangle(cornerRadius: 1)
                            .fill(stat.count > 0 ? Color.blue : Color.clear)
                            .frame(width: CGFloat(stat.count) * 2, height: 3)
                            .frame(minWidth: 0, maxWidth: 50, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(stat.count > 0 ? Color.blue.opacity(0.05) : Color.clear)
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - フィルターセクション
    private var filterSection: some View {
        VStack(spacing: 12) {
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("メッセージ、ユーザー、キャラクター名で検索", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("クリア") {
                        searchText = ""
                    }
                    .font(.caption)
                }
            }
            
            // フィルター選択
            HStack(spacing: 16) {
                Menu {
                    Button("すべてのユーザー") {
                        selectedUserFilter = ""
                    }
                    ForEach(users, id: \.id) { user in
                        Button(user.name) {
                            selectedUserFilter = user.id
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedUserFilter.isEmpty ? "全ユーザー" : (users.first { $0.id == selectedUserFilter }?.name ?? "不明"))
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                
                Menu {
                    Button("すべてのキャラクター") {
                        selectedCharacterFilter = ""
                    }
                    ForEach(characters, id: \.id) { character in
                        Button(character.name) {
                            selectedCharacterFilter = character.id
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCharacterFilter.isEmpty ? "全キャラクター" : (characters.first { $0.id == selectedCharacterFilter }?.name ?? "不明"))
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Text("\(filteredMessages.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - メッセージリスト
    private var messagesList: some View {
        List {
            ForEach(filteredMessages, id: \.id) { message in
                AdminMessageRow(
                    message: message,
                    onEdit: { message in
                        editingMessage = message
                        editingText = message.text
                        showingEditAlert = true
                    },
                    onDelete: { message in
                        messageToDelete = message
                        showingDeleteAlert = true
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - 計算プロパティ
    private var todayMessageCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return allMessages.filter { message in
            message.timestamp >= today && message.timestamp < tomorrow
        }.count
    }
    
    private var userMessageCount: Int {
        allMessages.filter { $0.isFromUser }.count
    }
    
    private var aiMessageCount: Int {
        allMessages.filter { !$0.isFromUser }.count
    }
    
    // MARK: - 日付フォーマット用メソッド
    private func formatChartDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今日"
        } else if calendar.isDateInYesterday(date) {
            return "昨日"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
    
    private func formatDetailDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "今日"
        } else if calendar.isDateInYesterday(date) {
            return "昨日"
        } else {
            formatter.dateFormat = "M月d日(E)"
            return formatter.string(from: date)
        }
    }
    
    // MARK: - データ読み込みメソッド（既存のものと同じ）
    private func loadAllData() {
        isLoading = true
        let group = DispatchGroup()
        
        // メッセージデータ読み込み
        group.enter()
        loadMessages {
            group.leave()
        }
        
        // ユーザーデータ読み込み
        group.enter()
        loadUsers {
            group.leave()
        }
        
        // キャラクターデータ読み込み
        group.enter()
        loadCharacters {
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func loadMessages(completion: @escaping () -> Void) {
        database.child("messages").observe(.value) { snapshot in
            var messages: [AdminMessage] = []
            
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let data = snap.value as? [String: Any],
                      let adminMessage = AdminMessage.fromFirebaseData(id: snap.key, data: data) else {
                    continue
                }
                messages.append(adminMessage)
            }
            
            DispatchQueue.main.async {
                self.allMessages = messages
                completion()
            }
        }
    }
    
    private func loadUsers(completion: @escaping () -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            var usersList: [AdminUser] = []
            
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let data = snap.value as? [String: Any] else {
                    continue
                }
                
                let user = AdminUser(
                    id: snap.key,
                    name: data["username"] as? String ?? "名前なし",
                    createdAt: Date(timeIntervalSince1970: data["createdAt"] as? TimeInterval ?? 0),
                    lastActiveAt: Date(timeIntervalSince1970: data["lastActiveAt"] as? TimeInterval ?? 0)
                )
                usersList.append(user)
            }
            
            DispatchQueue.main.async {
                self.users = usersList
                completion()
            }
        }
    }
    
    private func loadCharacters(completion: @escaping () -> Void) {
        database.child("characters").observeSingleEvent(of: .value) { snapshot in
            var charactersList: [AdminCharacter] = []
            
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let data = snap.value as? [String: Any] else {
                    continue
                }
                
                let character = AdminCharacter(
                    id: snap.key,
                    name: data["name"] as? String ?? "名前なし",
                    personality: data["personality"] as? String ?? "",
                    intimacyLevel: data["intimacyLevel"] as? Int ?? 0
                )
                charactersList.append(character)
            }
            
            DispatchQueue.main.async {
                self.characters = charactersList
                completion()
            }
        }
    }
    
    // MARK: - メッセージ編集・削除メソッド（既存のものと同じ）
    private func saveEditedMessage() {
        guard let message = editingMessage else { return }
        
        let updates = [
            "text": editingText,
            "editedAt": Date().timeIntervalSince1970,
            "editedBy": "admin"
        ] as [String : Any]
        
        database.child("messages").child(message.id).updateChildValues(updates) { error, _ in
            if let error = error {
                print("メッセージ編集エラー: \(error.localizedDescription)")
            } else {
                print("メッセージ編集完了")
            }
        }
        
        editingMessage = nil
        editingText = ""
    }
    
    private func deleteMessage() {
        guard let message = messageToDelete else { return }
        
        database.child("messages").child(message.id).removeValue { error, _ in
            if let error = error {
                print("メッセージ削除エラー: \(error.localizedDescription)")
            } else {
                print("メッセージ削除完了")
            }
        }
        
        messageToDelete = nil
    }
    
    private func refreshData() {
        loadAllData()
    }
}

// MARK: - StatisticCard コンポーネント（新規追加）
struct StatisticCard1: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - AdminMessage データモデル（既存のものと同じ）
struct AdminMessage: Identifiable {
    let id: String
    let text: String
    let isFromUser: Bool
    let timestamp: Date
    let userId: String
    let characterId: String
    let conversationId: String
    let intimacyGained: Int
    
    // ユーザー名とキャラクター名（表示用）
    var userName: String = "不明なユーザー"
    var characterName: String = "不明なキャラクター"
    
    static func fromFirebaseData(id: String, data: [String: Any]) -> AdminMessage? {
        guard let text = data["text"] as? String,
              let isFromUser = data["isFromUser"] as? Bool,
              let timestampDouble = data["timestamp"] as? TimeInterval else {
            return nil
        }
        
        return AdminMessage(
            id: id,
            text: text,
            isFromUser: isFromUser,
            timestamp: Date(timeIntervalSince1970: timestampDouble),
            userId: data["senderId"] as? String ?? "",
            characterId: data["receiverId"] as? String ?? "",
            conversationId: data["conversationId"] as? String ?? "",
            intimacyGained: data["intimacyGained"] as? Int ?? 0
        )
    }
}

// MARK: - AdminUser データモデル（既存のものと同じ）
struct AdminUser: Identifiable {
    let id: String
    let name: String
    let createdAt: Date
    let lastActiveAt: Date
}

// MARK: - AdminCharacter データモデル（既存のものと同じ）
struct AdminCharacter: Identifiable {
    let id: String
    let name: String
    let personality: String
    let intimacyLevel: Int
}

// MARK: - AdminMessageRow コンポーネント（既存のものと同じ）
struct AdminMessageRow: View {
    let message: AdminMessage
    let onEdit: (AdminMessage) -> Void
    let onDelete: (AdminMessage) -> Void
    
    @State private var showActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 送信者情報
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(message.isFromUser ? "👤 \(message.userName)" : "🤖 \(message.characterName)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(message.isFromUser ? .blue : .purple)
                        
                        Spacer()
                        
                        Text(formatTimestamp(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("会話: \(message.conversationId)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // アクションボタン
                Button(action: {
                    showActions.toggle()
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // メッセージ内容
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(message.isFromUser ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
                )
            
            // 親密度情報
            if message.intimacyGained > 0 {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.pink)
                    Text("親密度 +\(message.intimacyGained)")
                        .font(.caption2)
                        .foregroundColor(.pink)
                    Spacer()
                }
            }
            
            // アクションボタン
            if showActions {
                HStack(spacing: 16) {
                    Button("編集") {
                        onEdit(message)
                        showActions = false
                    }
                    .foregroundColor(.blue)
                    
                    Button("削除") {
                        onDelete(message)
                        showActions = false
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                }
                .font(.caption)
                .padding(.top, 4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: showActions)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    AdminChatAnalyticsView()
}
