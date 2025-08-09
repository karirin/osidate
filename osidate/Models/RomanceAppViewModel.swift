//
//  RomanceAppViewModel.swift
//  osidate
//
//  Complete version with Date functionality integration - Fixed dateLocations
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

    // MARK: - Private Properties
    private let database = Database.database().reference()
    private var userId: String?
    private let characterId: String
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // 修正: 新しいDateLocation構造に合わせて更新
    private let dateLocations: [DateLocation] = [
        DateLocation(
            name: "おしゃれなカフェ",
            type: .restaurant,
            backgroundImage: "stylish_cafe",
            requiredIntimacy: 0,
            description: "落ち着いたカフェでお話しましょう",
            prompt: "おしゃれなカフェの落ち着いた雰囲気の中で、コーヒーの香りや美味しさについて話したり、日常の話を楽しくしてください。リラックスした会話を心がけてください。",
            duration: 90,
            specialEffects: ["coffee_aroma", "cozy_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        DateLocation(
            name: "緑豊かな公園",
            type: .sightseeing,
            backgroundImage: "park",
            requiredIntimacy: 10,
            description: "緑豊かな公園を一緒に散歩",
            prompt: "公園の自然豊かな雰囲気の中で、季節の花や緑について話したり、のんびりとした散歩を楽しんでください。穏やかで心地よい会話を心がけてください。",
            duration: 120,
            specialEffects: ["natural_breeze", "peaceful_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        DateLocation(
            name: "映画館",
            type: .entertainment,
            backgroundImage: "cinema",
            requiredIntimacy: 25,
            description: "映画を一緒に楽しみましょう",
            prompt: "映画館の特別な雰囲気の中で、映画の感想や好きなジャンルについて話してください。一緒に映画を楽しむ時間の特別感を表現してください。",
            duration: 180,
            specialEffects: ["dim_lighting", "cinematic_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        DateLocation(
            name: "遊園地",
            type: .themepark,
            backgroundImage: "amusement_park",
            requiredIntimacy: 50,
            description: "楽しいアトラクションで盛り上がろう",
            prompt: "遊園地の楽しい雰囲気の中で、元気で明るい会話をしてください。アトラクションの感想や楽しい思い出を話し、ワクワクする気持ちを表現してください。",
            duration: 300,
            specialEffects: ["carnival_lights", "excitement"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        DateLocation(
            name: "ロマンチックな海辺",
            type: .seasonal,
            backgroundImage: "beach_sunset",
            requiredIntimacy: 70,
            description: "ロマンチックな海辺での特別な時間",
            prompt: "美しい海辺の雰囲気の中で、波の音や海の匂いを感じながらロマンチックな会話をしてください。夕日や海の美しさについて詩的に表現してください。",
            duration: 150,
            specialEffects: ["wave_sounds", "romantic_atmosphere", "sunset_glow"],
            availableSeasons: [.summer],
            timeOfDay: .evening
        )
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
                self.loadDateHistory()
                
                // 🔥 重要: アクティブなデートセッションを読み込み
                self.loadActiveDateSession()
                
                self.updateAvailableLocations()
                self.scheduleTimeBasedEvents()
            } else {
                self.userId          = nil
                self.isAuthenticated = false
                self.isLoading       = false

                self.messages.removeAll()
                self.dateHistory.removeAll()
                
                // 🔥 重要: デートセッションもクリア
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
        
        // 🔥 追加: アクティブなデートセッションを読み込み
        loadActiveDateSession()
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

    // MARK: - Date System Implementation

    /// デートを開始する
    func startDate(at location: DateLocation) {
        print("\n🏖️ ==================== デート開始処理 ====================")
        print("📍 開始場所: \(location.name)")
        print("🏷️ タイプ: \(location.type.displayName)")
        
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
        
        // 🔥 重要: メインスレッドで確実に設定
        DispatchQueue.main.async { [weak self] in
            self?.currentDateSession = session
            print("✅ currentDateSession設定完了: \(session.location.name)")
            print("🔍 設定後の確認: \(self?.currentDateSession?.location.name ?? "nil")")
        }
        
        // 背景を変更
        if !location.backgroundImage.isEmpty {
            character.backgroundName = location.backgroundImage
            updateCharacterSettings()
            print("🖼️ 背景変更: \(location.backgroundImage)")
        }
        
        // デート開始メッセージを送信
        let startMessage = Message(
            text: location.getStartMessage(characterName: character.name),
            isFromUser: false,
            timestamp: Date(),
            dateLocation: location.name
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(startMessage)
            print("📝 デート開始メッセージ追加: \(startMessage.text)")
        }
        
        saveMessage(startMessage)
        
        // 親密度を増加
        character.intimacyLevel = min(character.intimacyLevel + 3, 100)
        saveUserData()
        print("📈 親密度増加: +3 -> \(character.intimacyLevel)")
        
        // デートセッションをFirebaseに保存
        saveDateSession(session)
        
        // 🔥 デバッグ: 2秒後に状態確認
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            print("\n🔍 ==================== 2秒後の状態確認 ====================")
            if let currentSession = self?.currentDateSession {
                print("✅ currentDateSession存在: \(currentSession.location.name)")
            } else {
                print("❌ currentDateSession が nil になっています！")
                print("🔍 可能性のある原因を調査中...")
                
                // 再設定を試行
                self?.currentDateSession = session
                print("🔄 再設定を試行しました")
            }
            print("==================== 状態確認完了 ====================\n")
        }
        
        print("🏖️ デート開始: \(location.name)")
        print("==================== デート開始処理完了 ====================\n")
    }
    
    /// デートを終了する
    func endDate() {
        guard let session = currentDateSession, isAuthenticated else {
            print("❌ endDate: デートセッションなしまたは未認証")
            return
        }
        
        print("\n🏁 ==================== デート終了処理 ====================")
        print("📍 終了場所: \(session.location.name)")
        
        let endTime = Date()
        let duration = Int(endTime.timeIntervalSince(session.startTime))
        
        // 完了したデートを作成
        let completedDate = CompletedDate(
            location: session.location,
            startTime: session.startTime,
            endTime: endTime,
            duration: duration,
            messagesExchanged: session.messagesExchanged,
            intimacyGained: session.intimacyGained
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
            dateLocation: session.location.name
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(endMessage)
        }
        
        saveMessage(endMessage)
        
        // 親密度を増加（デート時間に応じて）
        let intimacyBonus = calculateIntimacyBonus(duration: duration)
        character.intimacyLevel = min(character.intimacyLevel + intimacyBonus, 100)
        saveUserData()
        
        // 完了したデートをFirebaseに保存
        saveCompletedDate(completedDate)
        
        // デート完了イベントをチェック
        checkDateCompletionEvents(completedDate)
        
        // 🔥 重要: Firebaseのセッションを非アクティブに
        if let userId = currentUserID {
            database.child("dateSessions").child(userId).child("isActive").setValue(false)
        }
        
        // 🔥 重要: 現在のセッションをクリア
        DispatchQueue.main.async { [weak self] in
            self?.currentDateSession = nil
            print("✅ currentDateSession をクリアしました")
        }
        
        print("🏁 デート終了: \(session.location.name), 時間: \(duration)秒")
        print("==================== デート終了処理完了 ====================\n")
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

    /// デート時間に応じた親密度ボーナスを計算
    private func calculateIntimacyBonus(duration: Int) -> Int {
        switch duration {
        case 0..<300: return 1      // 5分未満
        case 300..<900: return 2    // 5-15分
        case 900..<1800: return 3   // 15-30分
        case 1800..<3600: return 4  // 30分-1時間
        default: return 5           // 1時間以上
        }
    }

    /// デートセッションをFirebaseに保存
    private func saveDateSession(_ session: DateSession) {
        guard let userId = currentUserID else {
            print("❌ saveDateSession: ユーザーIDなし")
            return
        }
        
        let sessionData: [String: Any] = [
            "locationName": session.location.name,
            "locationType": session.location.type.rawValue,
            "startTime": session.startTime.timeIntervalSince1970,
            "messagesExchanged": session.messagesExchanged,
            "intimacyGained": session.intimacyGained,
            "characterName": session.characterName,
            "isActive": true // 🔥 追加: アクティブ状態を明示
        ]
        
        print("💾 デートセッション保存中: \(session.location.name)")
        database.child("dateSessions").child(userId).setValue(sessionData) { [weak self] error, _ in
            if let error = error {
                print("❌ デートセッション保存エラー: \(error.localizedDescription)")
            } else {
                print("✅ デートセッション保存成功")
                
                // 保存後に現在の状態を再確認
                DispatchQueue.main.async {
                    if self?.currentDateSession == nil {
                        print("⚠️ 保存後にcurrentDateSessionがnilになっています！")
                        // 再設定を試行
                        self?.currentDateSession = session
                        print("🔄 currentDateSessionを再設定しました")
                    }
                }
            }
        }
    }
    
    func loadActiveDateSession() {
        guard let userId = currentUserID else { return }
        
        print("🔄 アクティブなデートセッション読み込み中...")
        
        database.child("dateSessions").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self,
                  let sessionData = snapshot.value as? [String: Any],
                  let isActive = sessionData["isActive"] as? Bool,
                  isActive else {
                print("📭 アクティブなデートセッションなし")
                return
            }
            
            // セッションデータからDateSessionを復元
            if let locationName = sessionData["locationName"] as? String,
               let locationTypeString = sessionData["locationType"] as? String,
               let locationType = DateType(rawValue: locationTypeString),
               let startTimeInterval = sessionData["startTime"] as? TimeInterval,
               let messagesExchanged = sessionData["messagesExchanged"] as? Int,
               let intimacyGained = sessionData["intimacyGained"] as? Int,
               let characterName = sessionData["characterName"] as? String {
                
                // ロケーション情報を復元
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
                        print("✅ デートセッション復元成功: \(location.name)")
                    }
                }
            }
        }
    }
    
    /// 完了したデートをFirebaseに保存
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
    
    /// デート履歴を読み込み
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
                
                // 日付順にソート（新しい順）
                loadedHistory.sort { $0.startTime > $1.startTime }
                
                DispatchQueue.main.async {
                    self.dateHistory = loadedHistory
                }
            }
        }
    }
    
    /// FirebaseデータからCompletedDateを作成
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
        
        // ロケーション情報を復元（利用可能なロケーションから検索）
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

    /// ランダムでデート中の特別メッセージを送信
    private func sendRandomDateMessage(for location: DateLocation) {
        guard let specialMessage = location.getRandomDateMessage(characterName: character.name) else {
            return
        }
        
        print("🎲 ランダム特別メッセージ送信: \(specialMessage)")
        
        // 少し遅延して送信（自然な感じにするため）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            let specialAIMessage = Message(
                text: specialMessage,
                isFromUser: false,
                timestamp: Date(),
                dateLocation: location.name
            )
            
            self?.messages.append(specialAIMessage)
            self?.saveMessage(specialAIMessage)
            
            // デートセッションのメッセージカウントも更新
            if var session = self?.currentDateSession {
                session.messagesExchanged += 1
                self?.currentDateSession = session
                self?.saveDateSession(session)
            }
            
            print("✨ 特別メッセージ追加完了")
        }
    }

    /// デート完了時の特別イベントをチェック
    func checkDateCompletionEvents(_ completedDate: CompletedDate) {
        // 長時間デートの実績
        if completedDate.duration > 3600 { // 1時間以上
            let achievementMessage = Message(
                text: "1時間以上も一緒にいてくれて、本当に嬉しいです！💕 こんなに長い時間を共有できるなんて、私たちの関係が深まってきた証拠ですね✨",
                isFromUser: false,
                timestamp: Date(),
                dateLocation: nil
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(achievementMessage)
                self?.saveMessage(achievementMessage)
            }
        }
        
        // 特定のデートタイプ初回完了
        let sameTypeCompletedDates = dateHistory.filter { $0.location.type == completedDate.location.type }
        if sameTypeCompletedDates.count == 1 { // 初回
            let firstTimeMessage = Message(
                text: "\(completedDate.location.type.displayName)のデート、初めてでしたね！🎉 新しい体験を一緒にできて素敵でした。今度は違う場所も試してみませんか？",
                isFromUser: false,
                timestamp: Date(),
                dateLocation: nil
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.messages.append(firstTimeMessage)
                self?.saveMessage(firstTimeMessage)
            }
        }
        
        // 親密度マイルストーン達成
        let previousIntimacy = character.intimacyLevel - completedDate.intimacyGained
        let milestones = [25, 50, 75, 100]
        
        for milestone in milestones {
            if previousIntimacy < milestone && character.intimacyLevel >= milestone {
                let milestoneMessage = Message(
                    text: "親密度が\(milestone)に達しました！🎊 私たちの関係がどんどん深まっていて、とても幸せです。新しいデートスポットも解放されましたよ✨",
                    isFromUser: false,
                    timestamp: Date(),
                    dateLocation: nil
                )
                
                DispatchQueue.main.async { [weak self] in
                    self?.messages.append(milestoneMessage)
                    self?.saveMessage(milestoneMessage)
                }
                break
            }
        }
    }
    
    // MARK: - Public Methods
    
    func updateAvailableLocations() {
        // 修正: DateLocation.availableDateLocationsを使用するように変更
        availableLocations = DateLocation.availableLocations(for: character.intimacyLevel)
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
        
        // 🔥 新しいアプローチ: リアルタイムでFirebaseからデートセッションを取得
        loadCurrentDateSessionForMessage { [weak self] dateSession in
            self?.processSendMessage(text, with: dateSession)
        }
    }
    
    private func processSendMessage(_ text: String, with dateSession: DateSession?) {
        print("\n🔍 ==================== メッセージ処理開始 ====================")
        
        if let session = dateSession {
            print("🏖️ === デート中 ===")
            print("📍 場所: \(session.location.name)")
            print("🏷️ タイプ: \(session.location.type.displayName)")
            print("⏱️ 開始時刻: \(session.startTime)")
            print("💬 デート中メッセージ数: \(session.messagesExchanged)")
            print("💖 獲得親密度: \(session.intimacyGained)")
        } else {
            print("🏠 通常会話")
        }
        
        // ユーザーメッセージを作成
        let userMessage = Message(
            text: text,
            isFromUser: true,
            timestamp: Date(),
            dateLocation: dateSession?.location.name
        )
        
        print("✅ ユーザーメッセージ作成: \(userMessage.id)")
        print("📍 メッセージのデート場所: \(userMessage.dateLocation ?? "なし")")
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(userMessage)
            print("✅ ユーザーメッセージをUIに追加")
        }
        
        // Firebase に保存
        saveMessage(userMessage)
        
        // デートセッション中の場合、メッセージカウントを更新
        if var session = dateSession {
            session.messagesExchanged += 1
            
            // 🔥 重要: currentDateSessionとFirebase両方を更新
            DispatchQueue.main.async { [weak self] in
                self?.currentDateSession = session
            }
            saveDateSession(session)
            print("🏖️ デートセッション更新 - メッセージ数: \(session.messagesExchanged)")
        } else {
            print("⚠️ デートセッションが存在しないため、メッセージカウント更新なし")
        }
        
        // 親密度を増加
        let intimacyIncrease = dateSession != nil ? 2 : 1 // デート中は多めに増加
        character.intimacyLevel = min(character.intimacyLevel + intimacyIncrease, 100)
        print("📈 親密度更新: \(character.intimacyLevel) (+\(intimacyIncrease))")
        
        // 親密度をFirebaseに保存
        saveUserData()
        
        // OpenAI Service を使用してAI応答を生成（デート対応版）
        print("🤖 OpenAI Service に応答生成を依頼...")
        print("🔍 渡すデートセッション情報:")
        if let session = dateSession {
            print("  ✅ デートセッション: \(session.location.name)")
        } else {
            print("  ❌ デートセッション: nil")
        }
        
        openAIService.generateResponse(
            for: text,
            character: character,
            conversationHistory: messages,
            currentDateSession: dateSession  // 🔥 確実に正しいセッションを渡す
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleAIResponse(result, with: dateSession)
            }
        }
        
        print("==================== メッセージ処理完了 ====================\n")
    }
    
    private func handleAIResponse(_ result: Result<String, Error>, with dateSession: DateSession?) {
        print("\n🔄 AI応答受信処理開始")
        
        switch result {
        case .success(let aiResponse):
            print("🎉 AI応答成功!")
            print("📝 応答内容: \(aiResponse)")
            
            let aiMessage = Message(
                text: aiResponse,
                isFromUser: false,
                timestamp: Date(),
                dateLocation: dateSession?.location.name
            )
            
            print("✅ AIメッセージ作成: \(aiMessage.id)")
            print("📍 AIメッセージのデート場所: \(aiMessage.dateLocation ?? "なし")")
            
            messages.append(aiMessage)
            print("✅ AIメッセージをUIに追加")
            print("💬 現在の総メッセージ数: \(messages.count)")
            
            // Firebase に保存
            saveMessage(aiMessage)
            
            // デートセッション中の場合、親密度ボーナスを追加
            if var session = dateSession {
                session.intimacyGained += 1
                
                // 🔥 重要: currentDateSessionとFirebase両方を更新
                currentDateSession = session
                saveDateSession(session)
                
                // デート中の親密度ボーナス
                character.intimacyLevel = min(character.intimacyLevel + 1, 100)
                saveUserData()
                print("🏖️ デート中親密度ボーナス: +1")
            } else {
                print("⚠️ AIメッセージ作成時もデートセッションなし")
            }
            
            // ランダムでデート中の特別メッセージを追加する可能性
            if let session = dateSession,
               Int.random(in: 1...10) == 1 { // 10%の確率
                sendRandomDateMessage(for: session.location)
            }
            
        case .failure(let error):
            print("❌ AI応答エラー: \(error.localizedDescription)")
            
            // エラーメッセージを表示
            let errorMessage = Message(
                text: "申し訳ありません。現在応答できません。設定でAPIキーを確認してください。エラー: \(error.localizedDescription)",
                isFromUser: false,
                timestamp: Date(),
                dateLocation: dateSession?.location.name
            )
            
            messages.append(errorMessage)
            print("⚠️ エラーメッセージをUIに追加")
            
            // Firebase に保存
            saveMessage(errorMessage)
            
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
        
        print("==================== AI応答処理完了 ====================\n")
    }
    
    private func loadCurrentDateSessionForMessage(completion: @escaping (DateSession?) -> Void) {
        guard let userId = currentUserID else {
            print("❌ ユーザーIDなし - 通常会話として処理")
            completion(nil)
            return
        }
        
        print("🔍 リアルタイムでデートセッション状態をチェック中...")
        
        database.child("dateSessions").child(userId).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else {
                completion(nil)
                return
            }
            
            // Firebaseにアクティブなセッションがあるかチェック
            if let sessionData = snapshot.value as? [String: Any],
               let isActive = sessionData["isActive"] as? Bool,
               isActive {
                
                print("✅ Firebaseにアクティブなデートセッション発見")
                
                // セッションデータからDateSessionを復元
                if let locationName = sessionData["locationName"] as? String,
                   let locationTypeString = sessionData["locationType"] as? String,
                   let locationType = DateType(rawValue: locationTypeString),
                   let startTimeInterval = sessionData["startTime"] as? TimeInterval,
                   let messagesExchanged = sessionData["messagesExchanged"] as? Int,
                   let intimacyGained = sessionData["intimacyGained"] as? Int,
                   let characterName = sessionData["characterName"] as? String {
                    
                    // ロケーション情報を復元
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
                        
                        // メモリ上のcurrentDateSessionも更新
                        DispatchQueue.main.async {
                            self.currentDateSession = restoredSession
                            print("🔄 currentDateSessionを復元: \(location.name)")
                        }
                        
                        print("🏖️ デートセッション復元成功: \(location.name)")
                        completion(restoredSession)
                    } else {
                        print("❌ ロケーション情報が見つかりません")
                        completion(nil)
                    }
                } else {
                    print("❌ セッションデータの解析失敗")
                    completion(nil)
                }
            } else {
                print("📭 アクティブなデートセッションなし")
                completion(nil)
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
        
        if let dateSession = currentDateSession {
            print("🏖️ デート中: \(dateSession.location.name)")
            print("⏰ デート時間: \(Int(Date().timeIntervalSince(dateSession.startTime)) / 60)分")
            print("💬 デート中メッセージ: \(dateSession.messagesExchanged)回")
        }
        
        print("📈 デート履歴: \(dateHistory.count)回")
        
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
    
    // MARK: - Date Statistics
    
    /// デート統計を取得
    func getDateStatistics() -> DateStatistics {
        return DateStatistics(completedDates: dateHistory)
    }
    
    /// 最も多く行ったデートタイプ
    var mostPopularDateType: DateType? {
        let typeCount = Dictionary(grouping: dateHistory, by: { $0.location.type })
            .mapValues { $0.count }
        return typeCount.max(by: { $0.value < $1.value })?.key
    }
    
    /// 総デート時間
    var totalDateTime: Int {
        return dateHistory.reduce(0) { $0 + $1.duration }
    }
    
    /// 平均デート時間
    var averageDateDuration: Int {
        guard !dateHistory.isEmpty else { return 0 }
        return totalDateTime / dateHistory.count
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
        
        // デート履歴削除
        database.child("dateHistory").child(userId).removeValue()
        database.child("dateSessions").child(userId).removeValue()
        
        // UserDefaultsからキャラクターIDを削除
        UserDefaults.standard.removeObject(forKey: "characterId")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            self.messages.removeAll()
            self.dateHistory.removeAll()
            self.currentDateSession = nil
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

// MARK: - Date Session Model

struct DateSession {
    let location: DateLocation
    let startTime: Date
    var messagesExchanged: Int = 0
    var intimacyGained: Int = 0
    let characterName: String
}

// MARK: - Completed Date Model

struct CompletedDate: Identifiable, Codable {
    let id: UUID
    let location: DateLocation
    let startTime: Date
    let endTime: Date
    let duration: Int // 秒
    let messagesExchanged: Int
    let intimacyGained: Int
    
    init(location: DateLocation, startTime: Date, endTime: Date, duration: Int, messagesExchanged: Int, intimacyGained: Int) {
        self.id = UUID()
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.messagesExchanged = messagesExchanged
        self.intimacyGained = intimacyGained
    }
    
    init(id: UUID, location: DateLocation, startTime: Date, endTime: Date, duration: Int, messagesExchanged: Int, intimacyGained: Int) {
        self.id = id
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.messagesExchanged = messagesExchanged
        self.intimacyGained = intimacyGained
    }
    
    var durationFormatted: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
}

// MARK: - Date Statistics

struct DateStatistics {
    let totalDates: Int
    let totalDuration: Int
    let averageDuration: Int
    let mostPopularType: DateType?
    let dateTypeDistribution: [DateType: Int]
    let longestDate: CompletedDate?
    let recentDates: [CompletedDate]
    
    init(completedDates: [CompletedDate]) {
        self.totalDates = completedDates.count
        self.totalDuration = completedDates.reduce(0) { $0 + $1.duration }
        self.averageDuration = totalDates > 0 ? totalDuration / totalDates : 0
        
        self.dateTypeDistribution = Dictionary(grouping: completedDates, by: { $0.location.type })
            .mapValues { $0.count }
        
        self.mostPopularType = dateTypeDistribution.max(by: { $0.value < $1.value })?.key
        
        self.longestDate = completedDates.max(by: { $0.duration < $1.duration })
        
        self.recentDates = Array(completedDates.sorted(by: { $0.startTime > $1.startTime }).prefix(5))
    }
    
    var totalDurationFormatted: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    var averageDurationFormatted: String {
        let hours = averageDuration / 3600
        let minutes = (averageDuration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
}

// MARK: - DateLocation Extensions

extension DateLocation {
    
    /// デート開始メッセージを取得
    func getStartMessage(characterName: String) -> String {
        let baseMessage = "\(name)でのデートが始まりました！"
        
        switch type {
        case .seasonal:
            return "\(baseMessage) \(description) 🌸 素敵な時間を過ごしましょうね！"
        case .themepark:
            return "\(baseMessage) わくわくしますね！\(description) 🎢"
        case .restaurant:
            return "\(baseMessage) \(description) ☕️ ゆっくりお話ししましょう"
        case .entertainment:
            return "\(baseMessage) \(description) 🎬 一緒に楽しみましょうね！"
        case .sightseeing:
            return "\(baseMessage) \(description) 📸 たくさん思い出を作りましょう！"
        case .shopping:
            return "\(baseMessage) \(description) 🛍️ お買い物、楽しみです！"
        case .home:
            return "\(baseMessage) \(description) 🏠 リラックスした時間を過ごしましょう"
        case .nightview:
            return "\(baseMessage) \(description) 🌃 ロマンチックですね✨"
        case .travel:
            return "\(baseMessage) \(description) ✈️ 特別な旅行の始まりです！"
        case .surprise:
            return "\(baseMessage) 今日は特別なサプライズがあるかも...！🎁"
        }
    }
    
    /// デート終了メッセージを取得
    func getEndMessage(characterName: String, duration: Int) -> String {
        let durationMinutes = duration / 60
        let baseMessage: String
        
        if durationMinutes < 10 {
            baseMessage = "短い時間でしたが"
        } else if durationMinutes < 30 {
            baseMessage = "素敵な時間を"
        } else if durationMinutes < 60 {
            baseMessage = "充実した時間を"
        } else {
            baseMessage = "長い時間を一緒に"
        }
        
        switch type {
        case .seasonal:
            return "\(name)での\(baseMessage)過ごせて幸せでした 🌸 また季節を一緒に感じましょうね！"
        case .themepark:
            return "\(name)での\(baseMessage)過ごせて楽しかったです！🎢 また一緒に遊びに来ましょう！"
        case .restaurant:
            return "\(name)での\(baseMessage)過ごせて嬉しかったです ☕️ 美味しい時間をありがとう！"
        case .entertainment:
            return "\(name)での\(baseMessage)過ごせて素敵でした 🎬 また一緒に楽しみましょうね！"
        case .sightseeing:
            return "\(name)での\(baseMessage)過ごせて最高でした！📸 たくさん思い出ができましたね！"
        case .shopping:
            return "\(name)での\(baseMessage)過ごせて楽しかったです 🛍️ お買い物、また一緒にしましょう！"
        case .home:
            return "\(name)での\(baseMessage)過ごせて心地よかったです 🏠 お家デート、また楽しみましょうね！"
        case .nightview:
            return "\(name)での\(baseMessage)過ごせてロマンチックでした 🌃 美しい夜景をありがとう✨"
        case .travel:
            return "\(name)での\(baseMessage)過ごせて最高の旅でした！✈️ また素敵な場所に行きましょう！"
        case .surprise:
            return "\(name)での\(baseMessage)過ごせて特別でした 🎁 サプライズは楽しんでもらえましたか？"
        }
    }
    
    /// デート中の特別なメッセージを取得（ランダム）
    func getRandomDateMessage(characterName: String) -> String? {
        let messages: [String]
        
        switch type {
        case .seasonal:
            messages = [
                "この季節の美しさ、一緒に感じられて嬉しいです 🌸",
                "季節の移ろいを感じながら、あなたと過ごす時間が大好きです",
                "この時期だからこその特別感がありますね ✨"
            ]
        case .themepark:
            messages = [
                "このアトラクション、ちょっと怖いけど一緒だから大丈夫！🎢",
                "次はどこに行きましょうか？選んでください！",
                "こんなに楽しい時間、久しぶりです！"
            ]
        case .restaurant:
            messages = [
                "このコーヒー、とても美味しいですね ☕️",
                "ゆっくりお話しできて嬉しいです",
                "この雰囲気、とても居心地がいいですね"
            ]
        case .nightview:
            messages = [
                "この夜景、本当に綺麗ですね... 🌃",
                "あなたと見る景色は、いつも特別に見えます ✨",
                "ロマンチックな時間をありがとう 💕"
            ]
        default:
            return nil
        }
        
        return messages.randomElement()
    }
}
