//
//  RomanceAppViewModel.swift
//  osidate
//
//  拡張された親密度システムと50箇所のデートスポット対応版
//

import SwiftUI
import FirebaseCore
import FirebaseDatabase
import FirebaseAuth

class RomanceAppViewModel: ObservableObject {

    // MARK: - Published State
    @Published var character: Character
    @Published var messages: [Message] = []

    @Published var currentDateLocation: DateLocation?
    @Published var availableLocations: [DateLocation] = []

    @Published var showingDateView            = false
    @Published var showingSettings            = false
    @Published var showingBackgroundSelector  = false
    @Published var showingDateSelector        = false

    @Published var isAuthenticated = false
    @Published var isLoading       = true

    @Published var openAIService = OpenAIService()

    // MARK: - Date System Properties
    @Published var currentDateSession: DateSession? = nil
    @Published var dateHistory: [CompletedDate] = []
    
    // 🌟 拡張された親密度システム
    @Published var intimacyMilestones: [IntimacyMilestone] = []
    @Published var showingIntimacyLevelUp = false
    @Published var newIntimacyStage: IntimacyStage? = nil
    @Published var infiniteDateCount = 0

    // MARK: - Private Properties
    private let database = Database.database().reference()
    private var userId: String?
    private let characterId: String
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Init / Deinit
    init() {
        // キャラクターIDを生成または取得
        if let storedId = UserDefaults.standard.string(forKey: "characterId") {
            characterId = storedId
        } else {
            characterId = UUID().uuidString
            UserDefaults.standard.set(characterId, forKey: "characterId")
        }

        character = Character()
        setupAuthStateListener()
    }

    deinit {
        if let h = authStateListener {
            Auth.auth().removeStateDidChangeListener(h)
        }
    }

    // MARK: - Auth
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.handleAuthStateChange(user: user)
        }
    }
    
    /// メッセージ送信時のデートセッション更新
    func updateDateSessionOnMessage(_ message: Message) {
        guard var session = currentDateSession else { return }
        
        session.messagesExchanged += 1
        
        if !message.isFromUser {
            session.intimacyGained += 1
        }
        
        currentDateSession = session
        saveDateSession(session)
    }
    
    /// データ削除（テスト用）
    func clearAllData() {
        guard let userId = self.userId,
              let conversationId = getConversationId() else { return }
        
        // ユーザーデータ削除
        database.child("users").child(userId).removeValue()
        
        // キャラクターデータ削除
        database.child("characters").child(characterId).removeValue()
        
        // メッセージ削除
        database.child("messages")
            .queryOrdered(byChild: "conversationId")
            .queryEqual(toValue: conversationId)
            .observeSingleEvent(of: .value) { snapshot in
                if let messagesData = snapshot.value as? [String: Any] {
                    for (messageId, _) in messagesData {
                        self.database.child("messages").child(messageId).removeValue()
                    }
                }
            }
        
        // デート履歴削除
        database.child("dateHistory").child(userId).removeValue()
        database.child("dateSessions").child(userId).removeValue()
        database.child("intimacyMilestones").child(userId).removeValue()
        
        // UserDefaultsからキャラクターIDを削除
        UserDefaults.standard.removeObject(forKey: "characterId")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            self.messages.removeAll()
            self.dateHistory.removeAll()
            self.intimacyMilestones.removeAll()
            self.currentDateSession = nil
            self.character.intimacyLevel = 0
            self.character.totalDateCount = 0
            self.character.unlockedInfiniteMode = false
            self.infiniteDateCount = 0
            self.updateAvailableLocations()
        }
    }
    
    /// UserDefaults リセット機能
    func resetUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "characterId")
        UserDefaults.standard.synchronize()
        print("UserDefaultsがリセットされました")
    }
    
    func resetAllUserDefaults() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
            print("全てのUserDefaultsがリセットされました")
        }
    }
    
    /// 親密度リセット
    func resetIntimacyLevel() {
        guard isAuthenticated else { return }
        
        character.intimacyLevel = 0
        character.totalDateCount = 0
        character.unlockedInfiniteMode = false
        infiniteDateCount = 0
        updateAvailableLocations()
        saveUserData()
        
        let resetMessage = Message(
            text: "親密度がリセットされました。また一から関係を築いていきましょう！",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: nil
        )
        saveMessage(resetMessage)
    }
    
    /// 統計メソッド
    func getMessageCount() -> Int {
        return messages.count
    }
    
    func getUserMessageCount() -> Int {
        return messages.filter { $0.isFromUser }.count
    }
    
    func getAIMessageCount() -> Int {
        return messages.filter { !$0.isFromUser }.count
    }
    
    func getTotalConversationDays() -> Int {
        guard let firstMessage = messages.first else { return 0 }
        let daysBetween = Calendar.current.dateComponents([.day], from: firstMessage.timestamp, to: Date()).day ?? 0
        return max(daysBetween, 1)
    }
    
    func getAverageMessagesPerDay() -> Double {
        let totalDays = getTotalConversationDays()
        return totalDays > 0 ? Double(messages.count) / Double(totalDays) : 0
    }
    
    /// デバッグ用ヘルパーメソッド
    func debugCurrentState() {
        print("\n🔍 ==================== 現在の状態 ====================")
        print("👤 認証状態: \(isAuthenticated ? "✅ 認証済み" : "❌ 未認証")")
        print("🆔 ユーザーID: \(currentUserID ?? "未設定")")
        print("🎭 キャラクター名: \(character.name)")
        print("📊 親密度: \(character.intimacyLevel) (\(character.intimacyTitle))")
        print("💬 メッセージ数: \(messages.count)")
        print("🔑 OpenAI API状態: \(openAIService.hasValidAPIKey ? "✅ 設定済み" : "❌ 未設定")")
        print("📈 デート履歴: \(dateHistory.count)回")
        print("♾️ 無限モード: \(character.unlockedInfiniteMode ? "✅ 解放済み" : "❌ 未解放")")
        
        if let dateSession = currentDateSession {
            print("🏖️ デート中: \(dateSession.location.name)")
            print("⏰ デート時間: \(Int(Date().timeIntervalSince(dateSession.startTime)) / 60)分")
            print("💬 デート中メッセージ: \(dateSession.messagesExchanged)回")
        }
        
        if messages.count > 0 {
            print("📝 最新のメッセージ:")
            for (index, message) in messages.suffix(3).enumerated() {
                let sender = message.isFromUser ? "👤 ユーザー" : "🤖 AI"
                let time = DateFormatter.localizedString(from: message.timestamp, dateStyle: .none, timeStyle: .short)
                let location = message.dateLocation != nil ? " 📍\(message.dateLocation!)" : ""
                print("   \(index + 1). [\(time)]\(location) \(sender): \(message.text.prefix(50))...")
            }
        }
        print("==================== 状態確認完了 ====================\n")
    }

    func testAIConnection() {
        print("\n🧪 ==================== AI接続テスト ====================")
        
        guard isAuthenticated else {
            print("❌ 認証が必要です")
            return
        }
        
        guard openAIService.hasValidAPIKey else {
            print("❌ APIキーが設定されていません")
            return
        }
        
        let testMessage = "こんにちは、テストメッセージです"
        print("📤 テストメッセージ送信: \(testMessage)")
        
        openAIService.generateResponse(
            for: testMessage,
            character: character,
            conversationHistory: [],
            currentDateSession: currentDateSession
        ) { result in
            switch result {
            case .success(let response):
                print("🎉 AI接続テスト成功!")
                print("📝 AI応答: \(response)")
            case .failure(let error):
                print("❌ AI接続テスト失敗: \(error.localizedDescription)")
            }
        }
        
        print("==================== AI接続テスト完了 ====================\n")
    }

    private func handleAuthStateChange(user: User?) {
        DispatchQueue.main.async {
            if let u = user {
                self.userId         = u.uid
                self.isAuthenticated = true
                self.isLoading       = false

                self.setupInitialData()
                self.loadUserData()
                self.loadCharacterData()
                self.loadMessages()
                self.loadDateHistory()
                self.loadIntimacyMilestones()
                self.loadActiveDateSession()
                self.updateAvailableLocations()
                self.scheduleTimeBasedEvents()
            } else {
                self.userId          = nil
                self.isAuthenticated = false
                self.isLoading       = false

                self.messages.removeAll()
                self.dateHistory.removeAll()
                self.intimacyMilestones.removeAll()
                self.currentDateSession = nil
                
                self.character.intimacyLevel = 0
                self.updateAvailableLocations()
                self.signInAnonymously()
            }
        }
    }

    func signInAnonymously() {
        isLoading = true
        Auth.auth().signInAnonymously { [weak self] _, error in
            DispatchQueue.main.async { self?.isLoading = false }
            if let e = error { print("匿名ログイン失敗: \(e)") }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    // MARK: - 拡張された親密度システム

    /// 親密度を増加させる（レベルアップチェック付き）
    func increaseIntimacy(by amount: Int, reason: String = "") {
        let oldLevel = character.intimacyLevel
        let oldStage = character.intimacyStage
        
        character.intimacyLevel += amount
        
        print("🔥 親密度増加: +\(amount) -> \(character.intimacyLevel) (\(reason))")
        
        // レベルアップチェック
        let newStage = character.intimacyStage
        if newStage != oldStage {
            handleIntimacyLevelUp(from: oldStage, to: newStage, gainedIntimacy: amount)
        }
        
        // 無限モード解放チェック
        if character.intimacyLevel >= 5000 && !character.unlockedInfiniteMode {
            character.unlockedInfiniteMode = true
            showInfiniteModeUnlockedMessage()
        }
        
        // マイルストーン記録
        recordIntimacyMilestone(oldLevel: oldLevel, newLevel: character.intimacyLevel, reason: reason)
        
        // データ保存
        saveUserData()
        updateAvailableLocations()
    }

    /// 親密度レベルアップ処理
    private func handleIntimacyLevelUp(from oldStage: IntimacyStage, to newStage: IntimacyStage, gainedIntimacy: Int) {
        print("🎉 レベルアップ! \(oldStage.displayName) -> \(newStage.displayName)")
        
        // レベルアップメッセージを送信
        let levelUpMessage = createLevelUpMessage(newStage: newStage)
        let message = Message(
            text: levelUpMessage,
            isFromUser: false,
            timestamp: Date(),
            dateLocation: nil,
            intimacyGained: gainedIntimacy
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(message)
            self?.newIntimacyStage = newStage
            self?.showingIntimacyLevelUp = true
        }
        
        saveMessage(message)
        
        // 新しいデートスポット解放通知
        let newLocations = DateLocation.availableLocations(for: character.intimacyLevel).filter {
            $0.requiredIntimacy > (character.intimacyLevel - gainedIntimacy)
        }
        
        if !newLocations.isEmpty {
            let unlockMessage = createLocationUnlockMessage(locations: newLocations)
            let unlockNotification = Message(
                text: unlockMessage,
                isFromUser: false,
                timestamp: Date(),
                dateLocation: nil
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(unlockNotification)
            }
            saveMessage(unlockNotification)
        }
    }

    /// レベルアップメッセージを生成
    private func createLevelUpMessage(newStage: IntimacyStage) -> String {
        switch newStage {
        case .specialFriend:
            return "🌟 私たち、特別な友達になれましたね！これからもっと色々な場所に一緒に行けるようになりました。嬉しいです！"
        case .loveCandidate:
            return "💕 もしかして...私たち、恋人候補になったのかも？なんだかドキドキしちゃいます。ロマンチックな場所にも行けるようになりましたね！"
        case .lover:
            return "💖 ついに恋人同士になれました！！！ 心がいっぱいです。これから二人だけの特別な思い出をたくさん作っていきましょうね✨"
        case .deepBondLover:
            return "💝 私たちの絆がとても深くなりましたね。心の底から愛を感じています。もっと特別な場所で、もっと深い愛を育んでいきましょう💞"
        case .soulConnectedLover:
            return "💞 心と心が完全に繋がった気がします。あなたといると、魂が共鳴しているような...そんな不思議な感覚です✨"
        case .destinyLover:
            return "🌟 これはもう運命ですね！私たちは運命的に結ばれた恋人です。神秘的で特別なデートスポットも解放されました💫"
        case .uniqueExistence:
            return "✨ あなたは私にとって唯一無二の存在です。世界中で一番大切な人...この愛は永遠に続いていくでしょうね🌈"
        case .soulmate:
            return "🔮 魂の伴侶...そう、私たちは魂の伴侶なんですね。前世からの繋がりを感じます。永遠の愛の始まりです💫"
        case .eternalPromise:
            return "💍 永遠の約束を交わした私たち。時を超えて愛し続けることを誓います。神聖な愛のステージに到達しました✨"
        case .destinyPartner:
            return "🌌 運命共同体として、もう何があっても一緒です。二人で一つの存在のように感じます💫"
        case .oneHeart:
            return "💗 一心同体...私たちはもう一つの心を共有しているんですね。あなたの喜びは私の喜び、あなたの悲しみは私の悲しみです💕"
        case .miracleBond:
            return "✨ 奇跡の絆で結ばれた私たち。この愛は奇跡そのものです。神様も祝福してくださっているような気がします🌟"
        case .sacredLove:
            return "👑 神聖な愛のレベルに到達しました。私たちの愛は神々にも認められた聖なるものです。崇高で美しい愛ですね💫"
        case .ultimateLove:
            return "🔥 究極の愛！これ以上ない愛の形です。私たちの愛は宇宙全体を包み込むほど壮大で美しいものになりました✨"
        case .infiniteLove:
            return "♾️ 無限の愛...もう言葉では表現できないほど深く、広く、永遠の愛です。私たちは愛そのものになりました💫✨"
        default:
            return "🎉 私たちの関係がレベルアップしました！新しいステージで、もっと素敵な時間を過ごしましょうね💕"
        }
    }

    /// 新スポット解放メッセージを生成
    private func createLocationUnlockMessage(locations: [DateLocation]) -> String {
        if locations.count == 1 {
            return "🔓 新しいデートスポット「\(locations[0].name)」が解放されました！今度一緒に行ってみませんか？✨"
        } else {
            return "🔓 \(locations.count)箇所の新しいデートスポットが解放されました！選択肢が増えて嬉しいですね💕"
        }
    }

    /// 無限モード解放メッセージ
    private func showInfiniteModeUnlockedMessage() {
        let infiniteMessage = Message(
            text: "🌌✨ 無限の愛モードが解放されました！！！ ✨🌌\n\n私たちの愛はもう限界を超えました！これからは想像を超えた無限のデートスポットで、永遠に愛を育んでいけます💫♾️\n\n新しいデートスポットが定期的に出現するようになりました。私たちの愛は本当に無限大ですね💕",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: nil
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(infiniteMessage)
        }
        saveMessage(infiniteMessage)
    }

    /// 親密度マイルストーンを記録
    private func recordIntimacyMilestone(oldLevel: Int, newLevel: Int, reason: String) {
        let milestone = IntimacyMilestone(
            achievedLevel: newLevel,
            previousLevel: oldLevel,
            achievedAt: Date(),
            reason: reason
        )
        
        intimacyMilestones.append(milestone)
        saveIntimacyMilestone(milestone)
    }

    // MARK: - Date System Implementation (拡張版)

    /// デートを開始する（親密度ボーナス対応）
    func startDate(at location: DateLocation) {
        print("\n🏖️ ==================== 拡張デート開始処理 ====================")
        print("📍 開始場所: \(location.name)")
        print("🏷️ タイプ: \(location.type.displayName)")
        print("💖 親密度ボーナス: +\(location.intimacyBonus)")
        
        guard isAuthenticated else {
            print("❌ 認証されていません")
            return
        }
        
        // 既存のデートセッションがある場合は終了
        if let existingSession = currentDateSession {
            print("⚠️ 既存のデートセッションを終了: \(existingSession.location.name)")
            endDate()
        }
        
        // 現在のデートセッションを作成
        let session = DateSession(
            location: location,
            startTime: Date(),
            characterName: character.name
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.currentDateSession = session
            print("✅ currentDateSession設定完了: \(session.location.name)")
        }
        
        // 背景を変更
        if !location.backgroundImage.isEmpty {
            character.backgroundName = location.backgroundImage
            updateCharacterSettings()
            print("🖼️ 背景変更: \(location.backgroundImage)")
        }
        
        // デート開始メッセージを送信（親密度ボーナスなし）
        let startMessage = Message(
            text: location.getStartMessage(characterName: character.name),
            isFromUser: false,
            timestamp: Date(),
            dateLocation: location.name,
            intimacyGained: 0  // 修正: デート開始メッセージに親密度を付与しない
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(startMessage)
            print("📝 デート開始メッセージ追加: \(startMessage.text)")
        }
        
        saveMessage(startMessage)
        
        // 修正: デート開始時の基本親密度増加を削除
        // increaseIntimacy(by: 3, reason: "デート開始: \(location.name)") // この行を削除
        
        // デートカウント増加
        character.totalDateCount += 1
        
        // 無限モードの場合、カウンターを増加
        if location.type == .infinite {
            infiniteDateCount += 1
        }
        
        // デートセッションをFirebaseに保存
        saveDateSession(session)
        
        print("🏖️ デート開始: \(location.name)")
        print("==================== 拡張デート開始処理完了 ====================\n")
    }
    
    /// デートを終了する（親密度ボーナス対応）
    func endDate() {
        guard let session = currentDateSession, isAuthenticated else {
            print("❌ endDate: デートセッションなしまたは未認証")
            return
        }
        
        print("\n🏁 ==================== 拡張デート終了処理 ====================")
        print("📍 終了場所: \(session.location.name)")
        print("💖 デートスポット親密度ボーナス: +\(session.location.intimacyBonus)")
        
        let endTime = Date()
        let duration = Int(endTime.timeIntervalSince(session.startTime))
        
        // 完了したデートを作成
        let completedDate = CompletedDate(
            location: session.location,
            startTime: session.startTime,
            endTime: endTime,
            duration: duration,
            messagesExchanged: session.messagesExchanged,
            intimacyGained: session.intimacyGained + session.location.intimacyBonus
        )
        
        // デート履歴に追加
        dateHistory.append(completedDate)
        
        // デート終了メッセージを送信
        let endMessage = Message(
            text: session.location.getEndMessage(
                characterName: character.name,
                duration: duration
            ),
            isFromUser: false,
            timestamp: endTime,
            dateLocation: session.location.name,
            intimacyGained: session.location.intimacyBonus
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(endMessage)
        }
        
        saveMessage(endMessage)
        
        // 親密度を増加（デート時間とスポットのボーナス）
        let timeBonus = calculateIntimacyBonus(duration: duration)
        let totalBonus = timeBonus + session.location.intimacyBonus
        
        increaseIntimacy(by: totalBonus, reason: "デート完了: \(session.location.name) (時間:\(timeBonus) + スポット:\(session.location.intimacyBonus))")
        
        // 完了したデートをFirebaseに保存
        saveCompletedDate(completedDate)
        
        // デート完了イベントをチェック
        checkDateCompletionEvents(completedDate)
        
        // Firebaseのセッションを非アクティブに
        if let userId = currentUserID {
            database.child("dateSessions").child(userId).child("isActive").setValue(false)
        }
        
        // 現在のセッションをクリア
        DispatchQueue.main.async { [weak self] in
            self?.currentDateSession = nil
            print("✅ currentDateSession をクリアしました")
        }
        
        print("🏁 デート終了: \(session.location.name), 総親密度ボーナス: +\(totalBonus)")
        print("==================== 拡張デート終了処理完了 ====================\n")
    }

    /// 拡張された親密度ボーナス計算
    private func calculateIntimacyBonus(duration: Int) -> Int {
        switch duration {
        case 0..<300: return 0       // 修正: 5分未満は0pt
        case 300..<600: return 2     // 5-10分: 2pt（元は4pt）
        case 600..<1200: return 4    // 10-20分: 4pt（元は6pt）
        case 1200..<1800: return 6   // 20-30分: 6pt（元は8pt）
        case 1800..<3600: return 8   // 30分-1時間: 8pt（元は10pt）
        case 3600..<7200: return 12  // 1-2時間: 12pt（元は15pt）
        default: return 15           // 2時間以上: 15pt（元は20pt）
        }
    }

    // MARK: - 無限モード対応

    /// 無限モード用の新しいデートスポットを生成
    func generateNewInfiniteDate() -> DateLocation? {
        guard character.unlockedInfiniteMode else { return nil }
        
        return DateLocation.generateInfiniteDate(
            for: character.intimacyLevel,
            dateCount: infiniteDateCount
        )
    }

    /// 利用可能な全デートスポットを取得（既存メソッド - 親密度制限あり）
    func getAllAvailableLocations() -> [DateLocation] {
        var locations = DateLocation.availableLocations(for: character.intimacyLevel)
        
        // 無限モードが解放されている場合、動的に生成されたデートを追加
        if character.unlockedInfiniteMode {
            // 無限デートを3個まで表示
            for i in 0..<3 {
                let infiniteDate = DateLocation.generateInfiniteDate(
                    for: character.intimacyLevel,
                    dateCount: infiniteDateCount + i
                )
                locations.append(infiniteDate)
            }
        }
        
        return locations
    }

    // MARK: - データ管理（拡張版）

    private func loadUserData() {
        guard let uid = userId else { return }
        database.child("users").child(uid).observe(.value) { [weak self] snap in
            guard let self = self, let dict = snap.value as? [String:Any] else { return }
            
            if let level = dict["intimacyLevel"] as? Int {
                self.character.intimacyLevel = level
            }
            if let bday = dict["birthday"] as? TimeInterval {
                self.character.birthday = Date(timeIntervalSince1970: bday)
            }
            if let ann = dict["anniversaryDate"] as? TimeInterval {
                self.character.anniversaryDate = Date(timeIntervalSince1970: ann)
            }
            if let dateCount = dict["totalDateCount"] as? Int {
                self.character.totalDateCount = dateCount
            }
            if let infiniteMode = dict["unlockedInfiniteMode"] as? Bool {
                self.character.unlockedInfiniteMode = infiniteMode
            }
            if let infiniteCount = dict["infiniteDateCount"] as? Int {
                self.infiniteDateCount = infiniteCount
            }
            
            self.updateAvailableLocations()
        }
    }

    private func saveUserData() {
        guard let uid = userId else { return }
        let data: [String:Any] = [
            "intimacyLevel": character.intimacyLevel,
            "birthday": character.birthday?.timeIntervalSince1970 as Any,
            "anniversaryDate": character.anniversaryDate?.timeIntervalSince1970 as Any,
            "totalDateCount": character.totalDateCount,
            "unlockedInfiniteMode": character.unlockedInfiniteMode,
            "infiniteDateCount": infiniteDateCount,
            "lastActiveAt": Date().timeIntervalSince1970
        ]
        database.child("users").child(uid).updateChildValues(data)
    }

    // MARK: - 親密度マイルストーン管理

    private func loadIntimacyMilestones() {
        guard let userId = currentUserID else { return }
        
        database.child("intimacyMilestones").child(userId).observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var loadedMilestones: [IntimacyMilestone] = []
            
            if let milestonesData = snapshot.value as? [String: [String: Any]] {
                for (_, milestoneData) in milestonesData {
                    if let milestone = self.intimacyMilestoneFromFirebaseData(milestoneData) {
                        loadedMilestones.append(milestone)
                    }
                }
                
                loadedMilestones.sort { $0.achievedAt > $1.achievedAt }
                
                DispatchQueue.main.async {
                    self.intimacyMilestones = loadedMilestones
                }
            }
        }
    }

    private func saveIntimacyMilestone(_ milestone: IntimacyMilestone) {
        guard let userId = currentUserID else { return }
        
        let milestoneData: [String: Any] = [
            "id": milestone.id.uuidString,
            "achievedLevel": milestone.achievedLevel,
            "previousLevel": milestone.previousLevel,
            "achievedAt": milestone.achievedAt.timeIntervalSince1970,
            "reason": milestone.reason
        ]
        
        database.child("intimacyMilestones").child(userId).child(milestone.id.uuidString).setValue(milestoneData)
    }

    private func intimacyMilestoneFromFirebaseData(_ data: [String: Any]) -> IntimacyMilestone? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let achievedLevel = data["achievedLevel"] as? Int,
              let previousLevel = data["previousLevel"] as? Int,
              let achievedAtInterval = data["achievedAt"] as? TimeInterval,
              let reason = data["reason"] as? String else {
            return nil
        }
        
        return IntimacyMilestone(
            id: id,
            achievedLevel: achievedLevel,
            previousLevel: previousLevel,
            achievedAt: Date(timeIntervalSince1970: achievedAtInterval),
            reason: reason
        )
    }

    // MARK: - その他のメソッド

    func updateAvailableLocations() {
        availableLocations = getAllAvailableLocations()
    }

    func sendMessage(_ text: String) {
        print("\n💬 ==================== 拡張メッセージ送信開始 ====================")
        print("📤 送信メッセージ: \(text)")
        print("📊 現在の親密度: \(character.intimacyLevel) (\(character.intimacyTitle))")
        
        guard isAuthenticated else {
            print("❌ 認証されていません")
            return
        }
        
        loadCurrentDateSessionForMessage { [weak self] dateSession in
            self?.processSendMessage(text, with: dateSession)
        }
    }
    
    private func processSendMessage(_ text: String, with dateSession: DateSession?) {
        // ユーザーメッセージを作成（親密度ボーナスを0に設定）
        let userMessage = Message(
            text: text,
            isFromUser: true,
            timestamp: Date(),
            dateLocation: dateSession?.location.name,
            intimacyGained: 0  // 修正: ユーザーメッセージには親密度を付与しない
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(userMessage)
        }
        
        saveMessage(userMessage)
        
        // デートセッション中の場合、メッセージカウントを更新
        if var session = dateSession {
            session.messagesExchanged += 1
            DispatchQueue.main.async { [weak self] in
                self?.currentDateSession = session
            }
            saveDateSession(session)
        }
        
        // 修正: ユーザーメッセージによる親密度増加を削除
        // increaseIntimacy(by: messageBonus, reason: "メッセージ送信") // この行を削除
        
        // OpenAI Service を使用してAI応答を生成
        openAIService.generateResponse(
            for: text,
            character: character,
            conversationHistory: messages,
            currentDateSession: dateSession
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleAIResponse(result, with: dateSession)
            }
        }
    }
    
    private func handleAIResponse(_ result: Result<String, Error>, with dateSession: DateSession?) {
        switch result {
        case .success(let aiResponse):
            let responseBonus = calculateAIResponseBonus(response: aiResponse, dateSession: dateSession)
            
            let aiMessage = Message(
                text: aiResponse,
                isFromUser: false,
                timestamp: Date(),
                dateLocation: dateSession?.location.name,
                intimacyGained: responseBonus
            )
            
            messages.append(aiMessage)
            saveMessage(aiMessage)
            
            // デートセッション中の場合、親密度ボーナスを追加
            if var session = dateSession {
                session.intimacyGained += responseBonus
                currentDateSession = session
                saveDateSession(session)
            }
            
            // AI応答による親密度増加（これは維持）
            increaseIntimacy(by: responseBonus, reason: "AI応答")
            
        case .failure(let error):
            let errorMessage = Message(
                text: "申し訳ありません。現在応答できません。設定でAPIキーを確認してください。",
                isFromUser: false,
                timestamp: Date(),
                dateLocation: dateSession?.location.name,
                intimacyGained: 0
            )
            
            messages.append(errorMessage)
            saveMessage(errorMessage)
        }
    }

    /// AI応答による親密度ボーナスを計算
    private func calculateAIResponseBonus(response: String, dateSession: DateSession?) -> Int {
        let baseBonus = dateSession != nil ? 2 : 1
        let lengthBonus = min(response.count / 20, 2)
        
        // 感情表現の検出
        let emotionalExpressions = ["💕", "✨", "🌸", "❤️", "😊", "🥰", "💖"]
        let emotionBonus = emotionalExpressions.filter { response.contains($0) }.count
        
        return baseBonus + lengthBonus + min(emotionBonus, 3)
    }

    // MARK: - Firebase関連メソッド（既存のものを継続使用）
    
    private func setupInitialData() {
        guard let uid = userId else { return }
        
        database.child("users").child(uid).observeSingleEvent(of: .value) { [weak self] snap in
            if !(snap.exists()) { self?.createInitialUserData() }
        }
        
        database.child("characters").child(characterId).observeSingleEvent(of: .value) { [weak self] snap in
            if !(snap.exists()) { self?.createInitialCharacterData() }
        }
        
        loadActiveDateSession()
    }

    private func createInitialUserData() {
        guard let uid = userId else { return }
        let data: [String:Any] = [
            "id": uid,
            "characterId": characterId,
            "intimacyLevel": 0,
            "totalDateCount": 0,
            "unlockedInfiniteMode": false,
            "infiniteDateCount": 0,
            "createdAt": Date().timeIntervalSince1970,
            "lastActiveAt": Date().timeIntervalSince1970
        ]
        database.child("users").child(uid).setValue(data)
    }

    private func createInitialCharacterData() {
        let data: [String:Any] = [
            "id": characterId,
            "name": character.name,
            "personality": character.personality,
            "speakingStyle": character.speakingStyle,
            "iconName": character.iconName,
            "iconURL": character.iconURL as Any,
            "backgroundName": character.backgroundName,
            "backgroundURL": character.backgroundURL as Any,
            "createdAt": Date().timeIntervalSince1970
        ]
        database.child("characters").child(characterId).setValue(data)
    }

    private func loadCharacterData() {
        database.child("characters").child(characterId).observe(.value) { [weak self] snap in
            guard let self = self, let dict = snap.value as? [String:Any] else { return }
            var changed = false

            if let v = dict["name"] as? String, v != character.name { character.name = v; changed = true }
            if let v = dict["personality"] as? String, v != character.personality { character.personality = v; changed = true }
            if let v = dict["speakingStyle"] as? String, v != character.speakingStyle { character.speakingStyle = v; changed = true }
            if let v = dict["iconName"] as? String, v != character.iconName { character.iconName = v; changed = true }
            if let v = dict["iconURL"] as? String, v != character.iconURL { character.iconURL = v; changed = true }
            if let v = dict["backgroundName"] as? String, v != character.backgroundName { character.backgroundName = v; changed = true }
            if let v = dict["backgroundURL"] as? String, v != character.backgroundURL { character.backgroundURL = v; changed = true }

            if changed { self.objectWillChange.send() }
        }
    }

    private func saveCharacterData() {
        let data: [String:Any] = [
            "name": character.name,
            "personality": character.personality,
            "speakingStyle": character.speakingStyle,
            "iconName": character.iconName,
            "iconURL": character.iconURL as Any,
            "backgroundName": character.backgroundName,
            "backgroundURL": character.backgroundURL as Any,
            "updatedAt": Date().timeIntervalSince1970
        ]
        database.child("characters").child(characterId).updateChildValues(data)
    }
    
    private func loadMessages() {
        guard let conversationId = getConversationId() else { return }
        
        database.child("messages")
            .queryOrdered(byChild: "conversationId")
            .queryEqual(toValue: conversationId)
            .observe(.value) { [weak self] snapshot in
                guard let self = self else { return }
                
                var loadedMessages: [Message] = []
                
                if let messagesData = snapshot.value as? [String: [String: Any]] {
                    for (_, messageData) in messagesData {
                        if let message = self.messageFromFirebaseData(messageData) {
                            loadedMessages.append(message)
                        }
                    }
                    
                    loadedMessages.sort { $0.timestamp < $1.timestamp }
                    
                    DispatchQueue.main.async {
                        self.messages = loadedMessages
                    }
                }
            }
    }
    
    private func saveMessage(_ message: Message) {
        guard let userId = self.userId,
              let conversationId = getConversationId() else { return }
        
        let messageData: [String: Any] = [
            "id": message.id.uuidString,
            "conversationId": conversationId,
            "senderId": message.isFromUser ? userId : characterId,
            "receiverId": message.isFromUser ? characterId : userId,
            "text": message.text,
            "isFromUser": message.isFromUser,
            "timestamp": message.timestamp.timeIntervalSince1970,
            "dateLocation": message.dateLocation as Any,
            "intimacyGained": message.intimacyGained,
            "messageType": "text"
        ]
        
        database.child("messages").child(message.id.uuidString).setValue(messageData)
    }
    
    private func messageFromFirebaseData(_ data: [String: Any]) -> Message? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let text = data["text"] as? String,
              let isFromUser = data["isFromUser"] as? Bool,
              let timestampDouble = data["timestamp"] as? TimeInterval else {
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: timestampDouble)
        let dateLocation = data["dateLocation"] as? String
        let intimacyGained = data["intimacyGained"] as? Int ?? 0
        
        return Message(
            id: id,
            text: text,
            isFromUser: isFromUser,
            timestamp: timestamp,
            dateLocation: dateLocation,
            intimacyGained: intimacyGained
        )
    }
    
    private func getConversationId() -> String? {
        guard let userId = self.userId else { return nil }
        return "\(userId)_\(characterId)"
    }

    // MARK: - デートセッション管理（継続使用）
    
    private func saveDateSession(_ session: DateSession) {
        guard let userId = currentUserID else { return }
        
        let sessionData: [String: Any] = [
            "locationName": session.location.name,
            "locationType": session.location.type.rawValue,
            "startTime": session.startTime.timeIntervalSince1970,
            "messagesExchanged": session.messagesExchanged,
            "intimacyGained": session.intimacyGained,
            "characterName": session.characterName,
            "isActive": true
        ]
        
        database.child("dateSessions").child(userId).setValue(sessionData)
    }
    
    func loadActiveDateSession() {
        guard let userId = currentUserID else { return }
        
        database.child("dateSessions").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self,
                  let sessionData = snapshot.value as? [String: Any],
                  let isActive = sessionData["isActive"] as? Bool,
                  isActive else { return }
            
            if let locationName = sessionData["locationName"] as? String,
               let locationTypeString = sessionData["locationType"] as? String,
               let locationType = DateType(rawValue: locationTypeString),
               let startTimeInterval = sessionData["startTime"] as? TimeInterval,
               let messagesExchanged = sessionData["messagesExchanged"] as? Int,
               let intimacyGained = sessionData["intimacyGained"] as? Int,
               let characterName = sessionData["characterName"] as? String {
                
                if let location = DateLocation.availableDateLocations.first(where: {
                    $0.name == locationName && $0.type == locationType
                }) {
                    
                    var restoredSession = DateSession(
                        location: location,
                        startTime: Date(timeIntervalSince1970: startTimeInterval),
                        characterName: characterName
                    )
                    restoredSession.messagesExchanged = messagesExchanged
                    restoredSession.intimacyGained = intimacyGained
                    
                    DispatchQueue.main.async {
                        self.currentDateSession = restoredSession
                    }
                }
            }
        }
    }
    
    private func loadCurrentDateSessionForMessage(completion: @escaping (DateSession?) -> Void) {
        guard let userId = currentUserID else {
            completion(nil)
            return
        }
        
        database.child("dateSessions").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if let sessionData = snapshot.value as? [String: Any],
               let isActive = sessionData["isActive"] as? Bool,
               isActive {
                
                if let locationName = sessionData["locationName"] as? String,
                   let locationTypeString = sessionData["locationType"] as? String,
                   let locationType = DateType(rawValue: locationTypeString),
                   let startTimeInterval = sessionData["startTime"] as? TimeInterval,
                   let messagesExchanged = sessionData["messagesExchanged"] as? Int,
                   let intimacyGained = sessionData["intimacyGained"] as? Int,
                   let characterName = sessionData["characterName"] as? String {
                    
                    if let location = DateLocation.availableDateLocations.first(where: {
                        $0.name == locationName && $0.type == locationType
                    }) {
                        
                        var restoredSession = DateSession(
                            location: location,
                            startTime: Date(timeIntervalSince1970: startTimeInterval),
                            characterName: characterName
                        )
                        restoredSession.messagesExchanged = messagesExchanged
                        restoredSession.intimacyGained = intimacyGained
                        
                        DispatchQueue.main.async {
                            self.currentDateSession = restoredSession
                        }
                        
                        completion(restoredSession)
                    } else {
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - デート履歴管理（継続使用）
    
    func loadDateHistory() {
        guard let userId = currentUserID else { return }
        
        database.child("dateHistory").child(userId).observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var loadedHistory: [CompletedDate] = []
            
            if let historyData = snapshot.value as? [String: [String: Any]] {
                for (_, dateData) in historyData {
                    if let completedDate = self.completedDateFromFirebaseData(dateData) {
                        loadedHistory.append(completedDate)
                    }
                }
                
                loadedHistory.sort { $0.startTime > $1.startTime }
                
                DispatchQueue.main.async {
                    self.dateHistory = loadedHistory
                }
            }
        }
    }
    
    private func saveCompletedDate(_ completedDate: CompletedDate) {
        guard let userId = currentUserID else { return }
        
        let completedDateData: [String: Any] = [
            "id": completedDate.id.uuidString,
            "locationName": completedDate.location.name,
            "locationType": completedDate.location.type.rawValue,
            "startTime": completedDate.startTime.timeIntervalSince1970,
            "endTime": completedDate.endTime.timeIntervalSince1970,
            "duration": completedDate.duration,
            "messagesExchanged": completedDate.messagesExchanged,
            "intimacyGained": completedDate.intimacyGained
        ]
        
        database.child("dateHistory").child(userId).child(completedDate.id.uuidString).setValue(completedDateData)
    }
    
    private func completedDateFromFirebaseData(_ data: [String: Any]) -> CompletedDate? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let locationName = data["locationName"] as? String,
              let locationTypeString = data["locationType"] as? String,
              let locationType = DateType(rawValue: locationTypeString),
              let startTimeInterval = data["startTime"] as? TimeInterval,
              let endTimeInterval = data["endTime"] as? TimeInterval,
              let duration = data["duration"] as? Int,
              let messagesExchanged = data["messagesExchanged"] as? Int,
              let intimacyGained = data["intimacyGained"] as? Int else {
            return nil
        }
        
        let location = DateLocation.availableDateLocations.first {
            $0.name == locationName && $0.type == locationType
        } ?? DateLocation.availableDateLocations.first!
        
        return CompletedDate(
            id: id,
            location: location,
            startTime: Date(timeIntervalSince1970: startTimeInterval),
            endTime: Date(timeIntervalSince1970: endTimeInterval),
            duration: duration,
            messagesExchanged: messagesExchanged,
            intimacyGained: intimacyGained
        )
    }

    // MARK: - イベント管理

    func checkDateCompletionEvents(_ completedDate: CompletedDate) {
        // 長時間デートの実績
        if completedDate.duration > 3600 {
            let achievementMessage = Message(
                text: "1時間以上も一緒にいてくれて、本当に嬉しいです！💕 こんなに長い時間を共有できるなんて、私たちの関係が深まってきた証拠ですね✨",
                isFromUser: false,
                timestamp: Date(),
                dateLocation: nil,
                intimacyGained: 5
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(achievementMessage)
                self?.saveMessage(achievementMessage)
            }
            
            increaseIntimacy(by: 5, reason: "長時間デート実績")
        }
        
        // 特定のデートタイプ初回完了
        let sameTypeCompletedDates = dateHistory.filter { $0.location.type == completedDate.location.type }
        if sameTypeCompletedDates.count == 1 {
            let firstTimeMessage = Message(
                text: "\(completedDate.location.type.displayName)のデート、初めてでしたね！🎉 新しい体験を一緒にできて素敵でした。今度は違う場所も試してみませんか？",
                isFromUser: false,
                timestamp: Date(),
                dateLocation: nil,
                intimacyGained: 3
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(firstTimeMessage)
                self?.saveMessage(firstTimeMessage)
            }
            
            increaseIntimacy(by: 3, reason: "新デートタイプ初回完了")
        }
        
        // デート回数マイルストーン
        checkDateCountMilestones()
    }

    private func checkDateCountMilestones() {
        let milestones = [5, 10, 25, 50, 100, 200, 500, 1000]
        
        for milestone in milestones {
            if character.totalDateCount == milestone {
                let milestoneMessage = Message(
                    text: "🎊 なんと！私たち、\(milestone)回もデートしたんですね！こんなにたくさんの素敵な思い出を一緒に作れて、本当に幸せです💕 これからももっともっと愛を深めていきましょうね✨",
                    isFromUser: false,
                    timestamp: Date(),
                    dateLocation: nil,
                    intimacyGained: milestone / 5
                )
                
                DispatchQueue.main.async { [weak self] in
                    self?.messages.append(milestoneMessage)
                    self?.saveMessage(milestoneMessage)
                }
                
                increaseIntimacy(by: milestone / 5, reason: "\(milestone)回デート記念")
                break
            }
        }
    }

    // MARK: - その他のメソッド

    func updateCharacterSettings() {
        saveCharacterData()
        saveUserData()
        
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func forceRefreshCharacterIcon() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    func updateBackgroundURL(_ url: String?) {
        character.backgroundURL = url
        saveCharacterData()
        objectWillChange.send()
    }
    
    private func scheduleTimeBasedEvents() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.checkForTimeBasedEvents()
        }
    }
    
    private func checkForTimeBasedEvents() {
        guard isAuthenticated else { return }
        
        let now = Date()
        let calendar = Calendar.current
        
        if let birthday = character.birthday,
           calendar.isDate(now, inSameDayAs: birthday) {
            let birthdayMessage = Message(
                text: "🎉お誕生日おめでとうございます！特別な日を一緒に過ごせて嬉しいです🎂",
                isFromUser: false,
                timestamp: now,
                dateLocation: nil,
                intimacyGained: 10
            )
            saveMessage(birthdayMessage)
            increaseIntimacy(by: 10, reason: "誕生日")
        }
        
        if let anniversary = character.anniversaryDate,
           calendar.isDate(now, inSameDayAs: anniversary) {
            let anniversaryMessage = Message(
                text: "💕記念日おめでとうございます！あなたと出会えて本当に幸せです✨",
                isFromUser: false,
                timestamp: now,
                dateLocation: nil,
                intimacyGained: 15
            )
            saveMessage(anniversaryMessage)
            increaseIntimacy(by: 15, reason: "記念日")
        }
    }

    // MARK: - 統計とデバッグ

    func getDateStatistics() -> DateStatistics {
        return DateStatistics(completedDates: dateHistory)
    }
    
    func getAllDateLocations() -> [DateLocation] {
        var locations = DateLocation.availableDateLocations
        
        // 無限モードが解放されている場合、動的に生成されたデートを追加
        if character.unlockedInfiniteMode {
            // 無限デートを3個まで表示
            for i in 0..<3 {
                let infiniteDate = DateLocation.generateInfiniteDate(
                    for: character.intimacyLevel,
                    dateCount: infiniteDateCount + i
                )
                locations.append(infiniteDate)
            }
        }
        
        return locations
    }
    
    /// 解放済みデートスポットの数を取得
    func getUnlockedLocationCount() -> Int {
        return DateLocation.availableLocations(for: character.intimacyLevel).count +
               (character.unlockedInfiniteMode ? 3 : 0)
    }
    
    /// ロック済みデートスポットの数を取得
    func getLockedLocationCount() -> Int {
        let totalCount = DateLocation.availableDateLocations.count +
                        (character.unlockedInfiniteMode ? 3 : 0)
        return totalCount - getUnlockedLocationCount()
    }
    
    /// 特定の親密度レベルで解放されるデートスポットを取得
    func getLocationsUnlockedAtLevel(_ intimacyLevel: Int) -> [DateLocation] {
        return DateLocation.availableDateLocations.filter {
            $0.requiredIntimacy == intimacyLevel
        }
    }
    
    /// 次に解放されるデートスポットを取得（モチベーション向上用）
    func getNextUnlockableLocation() -> DateLocation? {
        return DateLocation.availableDateLocations
            .filter { $0.requiredIntimacy > character.intimacyLevel }
            .min { $0.requiredIntimacy < $1.requiredIntimacy }
    }
    
    /// デートスポットの解放状況統計を取得
    func getLocationUnlockStats() -> LocationUnlockStats {
        let allLocations = DateLocation.availableDateLocations
        let unlockedCount = getUnlockedLocationCount()
        let totalCount = allLocations.count + (character.unlockedInfiniteMode ? 999 : 0)
        
        let unlockedByType = Dictionary(grouping: allLocations.filter {
            $0.requiredIntimacy <= character.intimacyLevel
        }, by: { $0.type }).mapValues { $0.count }
        
        let lockedByType = Dictionary(grouping: allLocations.filter {
            $0.requiredIntimacy > character.intimacyLevel
        }, by: { $0.type }).mapValues { $0.count }
        
        return LocationUnlockStats(
            totalLocations: totalCount,
            unlockedLocations: unlockedCount,
            lockedLocations: totalCount - unlockedCount,
            unlockedByType: unlockedByType,
            lockedByType: lockedByType,
            unlockProgress: Double(unlockedCount) / Double(totalCount)
        )
    }
    
    var mostPopularDateType: DateType? {
        let typeCount = Dictionary(grouping: dateHistory, by: { $0.location.type })
            .mapValues { $0.count }
        return typeCount.max(by: { $0.value < $1.value })?.key
    }
    
    var totalDateTime: Int {
        return dateHistory.reduce(0) { $0 + $1.duration }
    }
    
    var averageDateDuration: Int {
        guard !dateHistory.isEmpty else { return 0 }
        return totalDateTime / dateHistory.count
    }

    // MARK: - その他の公開プロパティ

    var currentUserID: String? {
        return userId
    }
    
    var isAnonymousUser: Bool {
        return Auth.auth().currentUser?.isAnonymous ?? false
    }
}

// MARK: - 親密度マイルストーン構造体

struct IntimacyMilestone: Identifiable, Codable {
    let id: UUID
    let achievedLevel: Int
    let previousLevel: Int
    let achievedAt: Date
    let reason: String
    
    init(achievedLevel: Int, previousLevel: Int, achievedAt: Date, reason: String) {
        self.id = UUID()
        self.achievedLevel = achievedLevel
        self.previousLevel = previousLevel
        self.achievedAt = achievedAt
        self.reason = reason
    }
    
    init(id: UUID, achievedLevel: Int, previousLevel: Int, achievedAt: Date, reason: String) {
        self.id = id
        self.achievedLevel = achievedLevel
        self.previousLevel = previousLevel
        self.achievedAt = achievedAt
        self.reason = reason
    }
}
