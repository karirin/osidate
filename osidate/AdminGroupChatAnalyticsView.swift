//
//  AdminGroupChatAnalyticsView.swift
//  osidate
//
//  管理者向けグループチャット分析画面
//

import SwiftUI
import Firebase
import FirebaseDatabase
import FirebaseAuth

struct AdminGroupChatAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupChats: [AdminGroupChat] = []
    @State private var selectedGroup: AdminGroupChat?
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingGroupDetail = false
    @State private var showingDeleteAlert = false
    @State private var groupToDelete: AdminGroupChat?
    
    private let database = Database.database().reference()
    
    // 管理者権限チェック
    private let adminUserIds = [
        "vVceNdjseGTBMYP7rMV9NKZuBaz1",
        ""
    ]
    
    private var isCurrentUserAdmin: Bool {
        guard let userID = Auth.auth().currentUser?.uid else { return false }
        return adminUserIds.contains(userID)
    }
    
    // フィルタリングされたグループ
    private var filteredGroups: [AdminGroupChat] {
        if searchText.isEmpty {
            return groupChats.sorted { $0.lastMessageTime > $1.lastMessageTime }
        } else {
            return groupChats.filter { group in
                group.name.localizedCaseInsensitiveContains(searchText) ||
                group.memberNames.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.lastMessageTime > $1.lastMessageTime }
        }
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
                        groupStatisticsView
                        
                        // 検索バー
                        searchSection
                        
                        // グループリスト
                        groupsList
                    }
                }
            }
            .navigationTitle("グループチャット監視")
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
                loadGroupChats()
            }
        }
        .sheet(isPresented: $showingGroupDetail) {
            if let group = selectedGroup {
                AdminGroupChatDetailView(group: group)
            }
        }
        .alert("グループチャットを削除", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                deleteGroupChat()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("このグループチャットとすべてのメッセージを削除しますか？この操作は元に戻せません。")
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
            
            Text("グループデータを読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - グループ統計
    private var groupStatisticsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatisticCard(
                    title: "総グループ数",
                    value: "\(groupChats.count)",
                    icon: "person.3.sequence.fill",
                    color: .blue
                )
                
                StatisticCard(
                    title: "アクティブグループ",
                    value: "\(activeGroupsCount)",
                    icon: "message.fill",
                    color: .green
                )
                
                StatisticCard(
                    title: "総メンバー数",
                    value: "\(totalMembersCount)",
                    icon: "person.2.fill",
                    color: .purple
                )
            }
            
            HStack(spacing: 20) {
                StatisticCard(
                    title: "今日のメッセージ",
                    value: "\(todayMessagesCount)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                StatisticCard(
                    title: "平均メンバー数",
                    value: String(format: "%.1f", averageMembersPerGroup),
                    icon: "chart.bar.fill",
                    color: .red
                )
                
                StatisticCard(
                    title: "非アクティブ",
                    value: "\(inactiveGroupsCount)",
                    icon: "pause.fill",
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - 検索セクション
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("グループ名やメンバー名で検索", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("クリア") {
                    searchText = ""
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - グループリスト
    private var groupsList: some View {
        List {
            ForEach(filteredGroups, id: \.id) { group in
                AdminGroupChatRow(
                    group: group,
                    onTap: {
                        selectedGroup = group
                        showingGroupDetail = true
                    },
                    onDelete: {
                        groupToDelete = group
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
    private var activeGroupsCount: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return groupChats.filter { $0.lastMessageTime >= oneWeekAgo }.count
    }
    
    private var inactiveGroupsCount: Int {
        groupChats.count - activeGroupsCount
    }
    
    private var totalMembersCount: Int {
        groupChats.reduce(0) { $0 + $1.memberCount }
    }
    
    private var averageMembersPerGroup: Double {
        guard !groupChats.isEmpty else { return 0 }
        return Double(totalMembersCount) / Double(groupChats.count)
    }
    
    private var todayMessagesCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return groupChats.reduce(0) { total, group in
            return total + group.messages.filter { $0.timestamp >= today }.count
        }
    }
    
    // MARK: - データ読み込みメソッド
    private func loadGroupChats() {
        isLoading = true
        
        database.child("groupChats").observe(.value) { snapshot in
            var groups: [AdminGroupChat] = []
            let dispatchGroup = DispatchGroup()
            
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let data = snap.value as? [String: Any] else {
                    continue
                }
                
                dispatchGroup.enter()
                
                let groupId = snap.key
                let groupName = data["name"] as? String ?? "名前なし"
                let createdAt = Date(timeIntervalSince1970: data["createdAt"] as? TimeInterval ?? 0)
                let memberIds = data["members"] as? [String] ?? []
                
                // グループのメッセージを読み込み
                self.loadGroupMessages(groupId: groupId) { messages in
                    // メンバー名を取得
                    self.loadMemberNames(memberIds: memberIds) { memberNames in
                        let group = AdminGroupChat(
                            id: groupId,
                            name: groupName,
                            memberIds: memberIds,
                            memberNames: memberNames,
                            memberCount: memberIds.count,
                            messages: messages,
                            createdAt: createdAt,
                            lastMessageTime: messages.last?.timestamp ?? createdAt
                        )
                        groups.append(group)
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.groupChats = groups
                self.isLoading = false
            }
        }
    }
    
    private func loadGroupMessages(groupId: String, completion: @escaping ([AdminGroupMessage]) -> Void) {
        database.child("groupMessages").child(groupId).observeSingleEvent(of: .value) { snapshot in
            var messages: [AdminGroupMessage] = []
            
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let data = snap.value as? [String: Any],
                      let messageId = snap.key as String?,
                      let text = data["text"] as? String,
                      let senderId = data["senderId"] as? String,
                      let timestamp = data["timestamp"] as? TimeInterval else {
                    continue
                }
                
                let message = AdminGroupMessage(
                    id: messageId,
                    text: text,
                    senderId: senderId,
                    senderName: data["senderName"] as? String ?? "不明",
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    groupId: groupId
                )
                messages.append(message)
            }
            
            messages.sort { $0.timestamp < $1.timestamp }
            completion(messages)
        }
    }
    
    private func loadMemberNames(memberIds: [String], completion: @escaping ([String]) -> Void) {
        var memberNames: [String] = []
        let dispatchGroup = DispatchGroup()
        
        for memberId in memberIds {
            dispatchGroup.enter()
            
            // ユーザー名を取得
            database.child("users").child(memberId).child("username").observeSingleEvent(of: .value) { snapshot in
                let name = snapshot.value as? String ?? "不明なユーザー"
                memberNames.append(name)
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(memberNames)
        }
    }
    
    private func deleteGroupChat() {
        guard let group = groupToDelete else { return }
        
        // グループチャットデータを削除
        database.child("groupChats").child(group.id).removeValue()
        
        // グループメッセージを削除
        database.child("groupMessages").child(group.id).removeValue()
        
        groupToDelete = nil
    }
    
    private func refreshData() {
        loadGroupChats()
    }
}

// MARK: - AdminGroupChat データモデル
struct AdminGroupChat: Identifiable {
    let id: String
    let name: String
    let memberIds: [String]
    let memberNames: [String]
    let memberCount: Int
    let messages: [AdminGroupMessage]
    let createdAt: Date
    let lastMessageTime: Date
}

// MARK: - AdminGroupMessage データモデル
struct AdminGroupMessage: Identifiable {
    let id: String
    let text: String
    let senderId: String
    let senderName: String
    let timestamp: Date
    let groupId: String
}

// MARK: - AdminGroupChatRow コンポーネント
struct AdminGroupChatRow: View {
    let group: AdminGroupChat
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // グループ情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(formatDate(group.lastMessageTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(group.memberCount)名のメンバー")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("メンバー: \(group.memberNames.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // アクションボタン
                Button(action: {
                    showActions.toggle()
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // 最新メッセージ
            if let lastMessage = group.messages.last {
                HStack {
                    Text("\(lastMessage.senderName):")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text(lastMessage.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
            
            // 統計情報
            HStack(spacing: 16) {
                Label("\(group.messages.count)", systemImage: "message")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Label("作成: \(formatDate(group.createdAt))", systemImage: "calendar")
                    .font(.caption2)
                    .foregroundColor(.green)
                
                Spacer()
                
                if isActiveGroup(group) {
                    Text("アクティブ")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
            
            // アクションボタン
            if showActions {
                HStack(spacing: 16) {
                    Button("詳細表示") {
                        onTap()
                        showActions = false
                    }
                    .foregroundColor(.blue)
                    
                    Button("削除") {
                        onDelete()
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            if !showActions {
                onTap()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showActions)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨日"
        } else {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
    
    private func isActiveGroup(_ group: AdminGroupChat) -> Bool {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return group.lastMessageTime >= oneWeekAgo
    }
}

// MARK: - AdminGroupChatDetailView
struct AdminGroupChatDetailView: View {
    let group: AdminGroupChat
    @Environment(\.dismiss) private var dismiss
    @State private var editingMessage: AdminGroupMessage?
    @State private var editingText = ""
    @State private var showingEditAlert = false
    @State private var showingDeleteAlert = false
    @State private var messageToDelete: AdminGroupMessage?
    
    private let database = Database.database().reference()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // グループ情報ヘッダー
                groupInfoHeader
                
                Divider()
                
                // メッセージリスト
                messagesList
            }
            .navigationTitle("グループ詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
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
            Text("このメッセージを削除しますか？")
        }
    }
    
    private var groupInfoHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(group.memberCount)名のメンバー • \(group.messages.count)件のメッセージ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // メンバーリスト
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(zip(group.memberIds, group.memberNames)), id: \.0) { memberId, memberName in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(memberName.prefix(1)).uppercased())
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                )
                            
                            Text(memberName)
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    private var messagesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(group.messages, id: \.id) { message in
                    AdminGroupMessageRow(
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
                }
            }
            .padding()
        }
    }
    
    private func saveEditedMessage() {
        guard let message = editingMessage else { return }
        
        let updates = [
            "text": editingText,
            "editedAt": Date().timeIntervalSince1970,
            "editedBy": "admin"
        ] as [String : Any]
        
        database.child("groupMessages").child(message.groupId).child(message.id).updateChildValues(updates)
        
        editingMessage = nil
        editingText = ""
    }
    
    private func deleteMessage() {
        guard let message = messageToDelete else { return }
        
        database.child("groupMessages").child(message.groupId).child(message.id).removeValue()
        
        messageToDelete = nil
    }
}

// MARK: - AdminGroupMessageRow コンポーネント
struct AdminGroupMessageRow: View {
    let message: AdminGroupMessage
    let onEdit: (AdminGroupMessage) -> Void
    let onDelete: (AdminGroupMessage) -> Void
    
    @State private var showActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 送信者情報
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(String(message.senderName.prefix(1)).uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        )
                    
                    Text(message.senderName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        showActions.toggle()
                    }) {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // メッセージ内容
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.2), value: showActions)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    AdminGroupChatAnalyticsView()
}
