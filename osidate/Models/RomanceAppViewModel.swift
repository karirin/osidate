//
//  RomanceAppViewModel.swift
//  osidate
//
//  Updated for Firebase Realtime Database with Firebase Auth
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

    @Published var isAuthenticated = false
    @Published var isLoading       = true

    @Published var openAIService = OpenAIService()

    // MARK: - Private Properties
    private let database = Database.database().reference()
    private var userId: String?
    private let characterId: String
    private var authStateListener: AuthStateDidChangeListenerHandle?

    private let dateLocations = [
        DateLocation(name: "カフェ",   backgroundImage: "cafe",      requiredIntimacy: 0,  description: "落ち着いたカフェでお話しましょう"),
        DateLocation(name: "公園",     backgroundImage: "park",      requiredIntimacy: 10, description: "緑豊かな公園を一緒に散歩"),
        DateLocation(name: "映画館",   backgroundImage: "cinema",    requiredIntimacy: 25, description: "映画を一緒に楽しみましょう"),
        DateLocation(name: "遊園地",   backgroundImage: "amusement", requiredIntimacy: 50, description: "楽しいアトラクションで盛り上がろう"),
        DateLocation(name: "海辺",     backgroundImage: "beach",     requiredIntimacy: 70, description: "ロマンチックな海辺での特別な時間")
    ]

    // MARK: - Init / Deinit
    init() {
        // キャラクターIDを生成または取得
        if let storedId = UserDefaults.standard.string(forKey: "characterId") {
            characterId = storedId
        } else {
            characterId = UUID().uuidString
            UserDefaults.standard.set(characterId, forKey: "characterId")
        }

        character = Character(
            name:         "あい",
            personality:  "優しくて思いやりがある",
            speakingStyle:"丁寧で温かい",
            iconName:     "person.circle.fill",
            backgroundName:"defaultBG",
            backgroundURL: nil
        )

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
                self.updateAvailableLocations()
                self.scheduleTimeBasedEvents()
            } else {
                self.userId          = nil
                self.isAuthenticated = false
                self.isLoading       = false

                self.messages.removeAll()
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

    // MARK: - Initial Data
    private func setupInitialData() {
        guard let uid = userId else { return }

        // Users
        database.child("users").child(uid).observeSingleEvent(of: .value) { [weak self] snap in
            if !(snap.exists()) { self?.createInitialUserData() }
        }

        // Characters
        database.child("characters").child(characterId).observeSingleEvent(of: .value) { [weak self] snap in
            if !(snap.exists()) { self?.createInitialCharacterData() }
        }
    }

    private func createInitialUserData() {
        guard let uid = userId else { return }
        let data: [String:Any] = [
            "id": uid,
            "characterId": characterId,
            "intimacyLevel": 0,
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

    // MARK: - Load / Save
    private func loadUserData() {
        guard let uid = userId else { return }
        database.child("users").child(uid).observe(.value) { [weak self] snap in
            guard let self = self, let dict = snap.value as? [String:Any] else { return }
            if let level = dict["intimacyLevel"] as? Int { self.character.intimacyLevel = level }
            if let bday  = dict["birthday"]       as? TimeInterval { self.character.birthday = Date(timeIntervalSince1970: bday) }
            if let ann   = dict["anniversaryDate"]as? TimeInterval { self.character.anniversaryDate = Date(timeIntervalSince1970: ann) }
            self.updateAvailableLocations()
        }
    }

    private func loadCharacterData() {
        database.child("characters").child(characterId).observe(.value) { [weak self] snap in
            guard let self = self, let dict = snap.value as? [String:Any] else { return }
            var changed = false

            if let v = dict["name"]            as? String, v != character.name            { character.name            = v; changed = true }
            if let v = dict["personality"]     as? String, v != character.personality     { character.personality     = v; changed = true }
            if let v = dict["speakingStyle"]   as? String, v != character.speakingStyle   { character.speakingStyle   = v; changed = true }
            if let v = dict["iconName"]        as? String, v != character.iconName        { character.iconName        = v; changed = true }
            if let v = dict["iconURL"]         as? String, v != character.iconURL         { character.iconURL         = v; changed = true }
            if let v = dict["backgroundName"]  as? String, v != character.backgroundName  { character.backgroundName  = v; changed = true }
            if let v = dict["backgroundURL"]   as? String, v != character.backgroundURL   { character.backgroundURL   = v; changed = true }

            if changed { self.objectWillChange.send() }
        }
    }

    private func saveUserData() {
        guard let uid = userId else { return }
        let data: [String:Any] = [
            "intimacyLevel": character.intimacyLevel,
            "birthday": character.birthday?.timeIntervalSince1970 as Any,
            "anniversaryDate": character.anniversaryDate?.timeIntervalSince1970 as Any,
            "lastActiveAt": Date().timeIntervalSince1970
        ]
        database.child("users").child(uid).updateChildValues(data)
    }

    private func saveCharacterData() {
        let data: [String:Any] = [
            "name":           character.name,
            "personality":    character.personality,
            "speakingStyle":  character.speakingStyle,
            "iconName":       character.iconName,
            "iconURL":        character.iconURL as Any,
            "backgroundName": character.backgroundName,
            "backgroundURL":  character.backgroundURL as Any,
            "updatedAt":      Date().timeIntervalSince1970
        ]
        database.child("characters").child(characterId).updateChildValues(data)
    }
    
    private func loadMessages() {
        guard let conversationId = getConversationId() else { return }
        
        // メッセージをタイムスタンプ順で取得
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
                    
                    // メッセージを時系列順にソート
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
            "messageType": "text" // 将来的に画像やスタンプなどに対応
        ]
        
        database.child("messages").child(message.id.uuidString).setValue(messageData) { error, _ in
            if let error = error {
                print("メッセージの保存でエラーが発生しました: \(error.localizedDescription)")
            } else {
                print("メッセージが正常に保存されました: \(message.text)")
            }
        }
    }
    
    private func messageFromFirebaseData(_ data: [String: Any]) -> Message? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let text = data["text"] as? String,
              let isFromUser = data["isFromUser"] as? Bool,
              let timestampDouble = data["timestamp"] as? TimeInterval else {
            print("メッセージデータの解析でエラーが発生しました: \(data)")
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: timestampDouble)
        let dateLocation = data["dateLocation"] as? String
        
        return Message(id: id, text: text, isFromUser: isFromUser, timestamp: timestamp, dateLocation: dateLocation)
    }
    
    private func getConversationId() -> String? {
        guard let userId = self.userId else { return nil }
        // ユーザーIDとキャラクターIDから一意の会話IDを生成
        return "\(userId)_\(characterId)"
    }
    
    // MARK: - Public Methods
    
    func updateAvailableLocations() {
        availableLocations = dateLocations.filter { $0.requiredIntimacy <= character.intimacyLevel }
    }

    func sendMessage(_ text: String) {
        print("\n💬 ==================== メッセージ送信開始 ====================")
        print("📤 送信メッセージ: \(text)")
        print("👤 現在のユーザー: \(currentUserID ?? "未設定")")
        print("🎭 キャラクター: \(character.name)")
        print("📊 現在の親密度: \(character.intimacyLevel)")
        print("💬 現在の会話数: \(messages.count)")
        
        guard isAuthenticated else {
            print("❌ 認証されていません")
            return
        }
        
        // ユーザーメッセージを追加
        let userMessage = Message(
            text: text,
            isFromUser: true,
            timestamp: Date(),
            dateLocation: nil
        )
        
        print("✅ ユーザーメッセージ作成: \(userMessage.id)")
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(userMessage)
            print("✅ ユーザーメッセージをUIに追加")
        }
        
        // Firebase に保存
        saveMessage(userMessage)
        
        // 親密度を増加
        character.intimacyLevel = min(character.intimacyLevel + 1, 100)
        print("📈 親密度更新: \(character.intimacyLevel)")
        
        // 親密度をFirebaseに保存
        saveUserData()
        
        // OpenAI Service を使用してAI応答を生成
        print("🤖 OpenAI Service に応答生成を依頼...")
        
        openAIService.generateResponse(
            for: text,
            character: character,
            conversationHistory: messages
        ) { [weak self] result in
            DispatchQueue.main.async {
                print("\n🔄 AI応答受信処理開始")
                
                switch result {
                case .success(let aiResponse):
                    print("🎉 AI応答成功!")
                    print("📝 応答内容: \(aiResponse)")
                    
                    let aiMessage = Message(
                        text: aiResponse,
                        isFromUser: false,
                        timestamp: Date(),
                        dateLocation: nil
                    )
                    
                    print("✅ AIメッセージ作成: \(aiMessage.id)")
                    
                    self?.messages.append(aiMessage)
                    print("✅ AIメッセージをUIに追加")
                    print("💬 現在の総メッセージ数: \(self?.messages.count ?? 0)")
                    
                    // Firebase に保存
                    self?.saveMessage(aiMessage)
                    
                case .failure(let error):
                    print("❌ AI応答エラー: \(error.localizedDescription)")
                    
                    // エラーメッセージを表示
                    let errorMessage = Message(
                        text: "申し訳ありません。現在応答できません。設定でAPIキーを確認してください。エラー: \(error.localizedDescription)",
                        isFromUser: false,
                        timestamp: Date(),
                        dateLocation: nil
                    )
                    
                    self?.messages.append(errorMessage)
                    print("⚠️ エラーメッセージをUIに追加")
                    
                    // Firebase に保存
                    self?.saveMessage(errorMessage)
                    
                    // エラーの詳細をログ出力
                    if let openAIError = error as? OpenAIError {
                        switch openAIError {
                        case .missingAPIKey:
                            print("🔑 APIキーが設定されていません")
                        case .invalidURL:
                            print("🌐 無効なURL")
                        case .noData:
                            print("📭 データなし")
                        case .noResponse:
                            print("📪 応答なし")
                        case .apiError(let message):
                            print("🚨 API エラー: \(message)")
                        }
                    }
                }
                
                print("==================== メッセージ送信完了 ====================\n")
            }
        }
    }

    // MARK: - デバッグ用ヘルパーメソッド

    func debugCurrentState() {
        print("\n🔍 ==================== 現在の状態 ====================")
        print("👤 認証状態: \(isAuthenticated ? "✅ 認証済み" : "❌ 未認証")")
        print("🆔 ユーザーID: \(currentUserID ?? "未設定")")
        print("🎭 キャラクター名: \(character.name)")
        print("📊 親密度: \(character.intimacyLevel)")
        print("💬 メッセージ数: \(messages.count)")
        print("🔑 OpenAI API状態: \(openAIService.hasValidAPIKey ? "✅ 設定済み" : "❌ 未設定")")
        
        if messages.count > 0 {
            print("📝 最新のメッセージ:")
            for (index, message) in messages.suffix(3).enumerated() {
                let sender = message.isFromUser ? "👤 ユーザー" : "🤖 AI"
                let time = DateFormatter.localizedString(from: message.timestamp, dateStyle: .none, timeStyle: .short)
                print("   \(index + 1). [\(time)] \(sender): \(message.text.prefix(50))...")
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
            conversationHistory: []
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

    
    func updateCharacterSettings() {
        print("updateCharacterSettings() 呼び出し")
        print("現在のアイコンURL: \(character.iconURL ?? "nil")")
        
        saveCharacterData()
        saveUserData()
        
        // 強制的にオブザーバーに変更を通知
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
            print("RomanceAppViewModel: 強制的に変更通知を送信")
        }
    }

    func forceRefreshCharacterIcon() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
            print("RomanceAppViewModel: アイコン強制リフレッシュ")
        }
    }
    
    private func generateAIResponse(to input: String) -> String {
        // キーワードベースの応答
        let inputLower = input.lowercased()
        
        if inputLower.contains("おはよう") || inputLower.contains("朝") {
            return "おはようございます！\(character.name)も今日という新しい日を一緒に過ごせて嬉しいです🌅"
        } else if inputLower.contains("こんにちは") {
            return "こんにちは！お疲れ様です。あなたと話せて幸せです☀️"
        } else if inputLower.contains("こんばんは") || inputLower.contains("夜") {
            return "こんばんは！今日はどんな一日でしたか？一緒にお話ししましょう🌙"
        } else if inputLower.contains("好き") || inputLower.contains("愛") {
            return "私もあなたのことが大好きです💕一緒にいる時間が一番幸せです✨"
        } else if inputLower.contains("疲れ") || inputLower.contains("つらい") {
            return "お疲れ様です。少し休んでくださいね。私がそばにいますから大丈夫ですよ😊"
        } else if inputLower.contains("楽しい") || inputLower.contains("嬉しい") {
            return "私も同じ気持ちです！あなたの笑顔を見ているととても幸せになります😄"
        }
        
        // 親密度に応じた応答
        if character.intimacyLevel < 20 {
            let responses = [
                "もっとあなたのことを知りたいです！",
                "一緒にお話しできて楽しいです😊",
                "あなたはどんなことが好きですか？"
            ]
            return responses.randomElement() ?? "ありがとうございます💕"
        } else if character.intimacyLevel < 50 {
            let responses = [
                "あなたと話していると、とても楽しい気持ちになります😊",
                "今度はどこかにお出かけしませんか？",
                "あなたの考えていることをもっと聞かせてください"
            ]
            return responses.randomElement() ?? "素敵ですね✨"
        } else {
            let responses = [
                "一緒にいる時間が一番幸せです✨",
                "あなたといると心が穏やかになります💕",
                "ずっと一緒にいたいです",
                "あなたは私にとって特別な存在です"
            ]
            return responses.randomElement() ?? "愛しています💖"
        }
    }
    
    func startDate(at location: DateLocation) {
        guard isAuthenticated else { return }
        
        currentDateLocation = location
        character.intimacyLevel += 5
        updateAvailableLocations()
        saveUserData()
        
        let dateMessage = Message(
            text: "\(location.name)でのデートが始まりました！\(location.description)",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: location.name
        )
        
        saveMessage(dateMessage)
    }
    
    func endDate() {
        guard let location = currentDateLocation, isAuthenticated else { return }
        
        currentDateLocation = nil
        
        let endMessage = Message(
            text: "\(location.name)でのデート、素敵な時間をありがとうございました！また一緒に過ごしましょうね💕",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: nil
        )
        
        saveMessage(endMessage)
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
        
        // 誕生日チェック
        if let birthday = character.birthday,
           calendar.isDate(now, inSameDayAs: birthday) {
            let birthdayMessage = Message(
                text: "🎉お誕生日おめでとうございます！特別な日を一緒に過ごせて嬉しいです🎂",
                isFromUser: false,
                timestamp: now,
                dateLocation: nil
            )
            saveMessage(birthdayMessage)
        }
        
        // 記念日チェック
        if let anniversary = character.anniversaryDate,
           calendar.isDate(now, inSameDayAs: anniversary) {
            let anniversaryMessage = Message(
                text: "💕記念日おめでとうございます！あなたと出会えて本当に幸せです✨",
                isFromUser: false,
                timestamp: now,
                dateLocation: nil
            )
            saveMessage(anniversaryMessage)
        }
    }
    
    // MARK: - データ削除（テスト用）
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
        
        // UserDefaultsからキャラクターIDを削除
        UserDefaults.standard.removeObject(forKey: "characterId")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            self.messages.removeAll()
            self.character.intimacyLevel = 0
            self.updateAvailableLocations()
        }
    }
    
    // MARK: - UserDefaults リセット機能
    func resetUserDefaults() {
        // キャラクターIDのみを削除（UserIDはFirebase Authが管理）
        UserDefaults.standard.removeObject(forKey: "characterId")
        UserDefaults.standard.synchronize()
        
        print("UserDefaultsがリセットされました")
    }
    
    func resetAllUserDefaults() {
        // アプリの全てのUserDefaultsを削除
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
            print("全てのUserDefaultsがリセットされました")
        }
    }
    
    // MARK: - Analytics and Statistics
    func getMessageCount() -> Int {
        return messages.count
    }
    
    func getUserMessageCount() -> Int {
        return messages.filter { $0.isFromUser }.count
    }
    
    func getAIMessageCount() -> Int {
        return messages.filter { !$0.isFromUser }.count
    }
    
    func resetIntimacyLevel() {
        guard isAuthenticated else { return }
        
        character.intimacyLevel = 0
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
    
    func getTotalConversationDays() -> Int {
        guard let firstMessage = messages.first else { return 0 }
        let daysBetween = Calendar.current.dateComponents([.day], from: firstMessage.timestamp, to: Date()).day ?? 0
        return max(daysBetween, 1)
    }
    
    func getAverageMessagesPerDay() -> Double {
        let totalDays = getTotalConversationDays()
        return totalDays > 0 ? Double(messages.count) / Double(totalDays) : 0
    }
    
    // MARK: - Auth State Helpers
    var currentUserID: String? {
        return userId
    }
    
    var isAnonymousUser: Bool {
        return Auth.auth().currentUser?.isAnonymous ?? false
    }
}
