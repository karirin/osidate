//
//  RomanceAppViewModel.swift
//  osidate
//
//  複数推し対応・自動登録停止版の最終コード
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
    @Published var showingDateView = false
    @Published var showingSettings = false
    @Published var showingBackgroundSelector = false
    @Published var showingDateSelector = false
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var openAIService = OpenAIService()

    // MARK: - Date System Properties
    @Published var currentDateSession: DateSession? = nil
    @Published var showingIntimacyLevelUp = false
    @Published var newIntimacyStage: IntimacyStage? = nil
    @Published var infiniteDateCount = 0

    // MARK: - Private Properties
    private let database = Database.database().reference()
    private var userId: String?
    private let characterId: String
    private var authStateListener: AuthStateDidChangeListenerHandle?

    var hasValidCharacter: Bool {
        return character.isValidCharacter
    }
    
    var chatDisplayMode: ChatDisplayMode {
        get {
            if let modeString = UserDefaults.standard.string(forKey: "chatDisplayMode"),
               let mode = ChatDisplayMode(rawValue: modeString) {
                return mode
            }
            return .traditional
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "chatDisplayMode")
            UserDefaults.standard.synchronize()
            let message = getChatModeChangeMessage(newMode: newValue)
            sendSystemMessage(message)
            print("🔄 チャット表示モードを変更: \(newValue.displayName)")
        }
    }

    // MARK: - Init / Deinit
    init() {
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

    private func getChatModeChangeMessage(newMode: ChatDisplayMode) -> String {
        switch newMode {
        case .traditional:
            return "チャット表示をLINE形式に変更しました！横並びでメッセージが見やすくなりますね✨"
        case .floating:
            return "チャット表示を吹き出し形式に変更しました！私からの吹き出しでもっと親密に会話できますね💕"
        }
    }
    
    func toggleChatDisplayMode() {
        let newMode: ChatDisplayMode = chatDisplayMode == .traditional ? .floating : .traditional
        chatDisplayMode = newMode
    }
    
    /// 🔧 最適化：推しを切り替える（charactersテーブル直接管理）
    func switchToCharacter(_ newCharacter: Character) {
        print("\n🔄 ==================== キャラクター切り替え開始 ====================")
        print("📤 切り替え前: \(character.name) (ID: \(character.id))")
        print("📥 切り替え後: \(newCharacter.name) (ID: \(newCharacter.id))")
        
        // 現在の状態を保存（有効なキャラクターの場合のみ）
        if character.isValidCharacter {
            saveCurrentCharacterState()
        }
        
        // 🔧 修正：メインスレッドで確実に更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // キャラクターを切り替え
            self.character = newCharacter
            
            // 🔧 修正：明示的に更新通知を送信
            self.objectWillChange.send()
            
            // 新しいキャラクターのデータを読み込み
            self.loadCharacterSpecificData()
            
            print("✅ キャラクター切り替え完了")
            print("🎭 新キャラクター情報:")
            print("   - 名前: \(self.character.name)")
            print("   - ID: \(self.character.id)")
            print("   - アイコンURL: \(self.character.iconURL ?? "なし")")
            print("   - 親密度: \(self.character.intimacyLevel)")
            print("==================== キャラクター切り替え終了 ====================\n")
        }
    }
    
    func forceUpdateCharacterProperties() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    /// キャラクターアイコンを強制リフレッシュ（修正版）
    func forceRefreshCharacterIcon() {
        print("🔄 キャラクターアイコンを強制リフレッシュ")
        print("   - キャラクター名: \(character.name)")
        print("   - アイコンURL: \(character.iconURL ?? "なし")")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 明示的に更新を通知
            self.objectWillChange.send()
            
            // 少し遅延を入れてもう一度更新を通知（確実に反映させるため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.objectWillChange.send()
            }
        }
    }
    
    /// キャラクター設定更新時の処理（修正版）
    func updateCharacterSettings() {
        guard hasValidCharacter else {
            print("❌ updateCharacterSettings: 無効なキャラクター")
            return
        }
        
        print("💾 キャラクター設定を更新中...")
        print("   - 名前: \(character.name)")
        print("   - アイコンURL: \(character.iconURL ?? "なし")")
        
        saveCharacterData()
        saveUserData()
        
        // 🔧 修正：確実にUI更新を通知
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.objectWillChange.send()
            
            // 少し遅延してもう一度更新（Viewの再描画を確実にするため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.objectWillChange.send()
            }
        }
        
        print("✅ キャラクター設定更新完了")
    }
    
    // 既存のメソッドはそのまま保持...
    private func saveCurrentCharacterState() {
        if character.isValidCharacter {
            updateCharacterSettings()
            saveUserData()
        }
    }
    
    private func loadCharacterSpecificData() {
        if character.isValidCharacter {
            loadMessages()
            updateAvailableLocations()
            
            // キャラクターデータも再読み込み
            loadCharacterData()
        }
    }
    
    /// デバッグ用：現在のキャラクター状態を出力
    func debugCharacterState() {
        print("\n🔍 ==================== キャラクター状態デバッグ ====================")
        print("🎭 キャラクター名: \(character.name)")
        print("🆔 キャラクターID: \(character.id)")
        print("🖼️ アイコンURL: \(character.iconURL ?? "未設定")")
        print("📊 親密度: \(character.intimacyLevel)")
        print("✅ 有効なキャラクター: \(hasValidCharacter ? "YES" : "NO")")
        print("🔐 認証状態: \(isAuthenticated ? "認証済み" : "未認証")")
        print("==================== デバッグ情報終了 ====================\n")
    }
    
    /// 🔧 最適化：キャラクターの全データを保存（親密度含む）
    private func saveCharacterDataComplete() {
        guard character.isValidCharacter else {
            print("❌ 保存条件不足: キャラクター無効")
            return
        }
        
        print("💾 === キャラクター完全データ保存開始 ===")
        print("🎭 対象キャラクター: \(character.name) (ID: \(character.id))")
        print("📊 保存する親密度: \(character.intimacyLevel)")
        print("📅 デート回数: \(character.totalDateCount)")
        print("♾️ 無限モード: \(character.unlockedInfiniteMode)")
        print("🔢 無限デート回数: \(infiniteDateCount)")
        
        // 🔧 最適化：charactersテーブルで全て管理（親密度含む）
        let characterData: [String: Any] = [
            "id": character.id,
            "name": character.name,
            "personality": character.personality,
            "speakingStyle": character.speakingStyle,
            "iconName": character.iconName,
            "iconURL": character.iconURL as Any,
            "backgroundName": character.backgroundName,
            "backgroundURL": character.backgroundURL as Any,
            "userNickname": character.userNickname,
            "useNickname": character.useNickname,
            // 🔧 最適化：親密度データもcharactersテーブルに含める
            "intimacyLevel": character.intimacyLevel,
            "totalDateCount": character.totalDateCount,
            "unlockedInfiniteMode": character.unlockedInfiniteMode,
            "infiniteDateCount": infiniteDateCount,
            "lastUpdated": Date().timeIntervalSince1970
        ]
        
        database.child("characters").child(character.id).updateChildValues(characterData) { error, _ in
            if let error = error {
                print("❌ キャラクターデータ保存失敗: \(error.localizedDescription)")
            } else {
                print("✅ キャラクターデータ保存成功")
            }
        }
        
        print("💾 === キャラクター完全データ保存完了 ===")
    }
    
    /// 🔧 最適化：キャラクターの全データを読み込み（親密度含む）
    private func loadCharacterDataComplete() {
        guard character.isValidCharacter else {
            print("❌ 読み込み条件不足: キャラクター無効")
            return
        }
        
        print("📥 === キャラクター完全データ読み込み開始 ===")
        print("🎭 対象キャラクター: \(character.name) (ID: \(character.id))")
        
        database.child("characters").child(character.id).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self,
                  let data = snapshot.value as? [String: Any] else {
                print("❌ キャラクターデータが見つかりません")
                return
            }
            
            print("📥 キャラクターデータ読み込み中...")
            
            // 基本プロパティを更新
            if let name = data["name"] as? String { self.character.name = name }
            if let personality = data["personality"] as? String { self.character.personality = personality }
            if let speakingStyle = data["speakingStyle"] as? String { self.character.speakingStyle = speakingStyle }
            if let iconName = data["iconName"] as? String { self.character.iconName = iconName }
            if let iconURL = data["iconURL"] as? String { self.character.iconURL = iconURL }
            if let backgroundName = data["backgroundName"] as? String { self.character.backgroundName = backgroundName }
            if let backgroundURL = data["backgroundURL"] as? String { self.character.backgroundURL = backgroundURL }
            if let userNickname = data["userNickname"] as? String { self.character.userNickname = userNickname }
            if let useNickname = data["useNickname"] as? Bool { self.character.useNickname = useNickname }
            
            // 🔧 最適化：親密度データもcharactersテーブルから読み込み
            if let intimacyLevel = data["intimacyLevel"] as? Int {
                self.character.intimacyLevel = intimacyLevel
                print("📊 親密度読み込み: \(intimacyLevel)")
            }
            if let totalDateCount = data["totalDateCount"] as? Int {
                self.character.totalDateCount = totalDateCount
                print("📅 デート回数読み込み: \(totalDateCount)")
            }
            if let unlockedInfiniteMode = data["unlockedInfiniteMode"] as? Bool {
                self.character.unlockedInfiniteMode = unlockedInfiniteMode
                print("♾️ 無限モード読み込み: \(unlockedInfiniteMode)")
            }
            if let infiniteDateCount = data["infiniteDateCount"] as? Int {
                self.infiniteDateCount = infiniteDateCount
                print("🔢 無限デート回数読み込み: \(infiniteDateCount)")
            }
            
            print("✅ キャラクターデータ読み込み完了")
            print("📊 最終的な親密度: \(self.character.intimacyLevel)")
            
            // 関連データを読み込み
            DispatchQueue.main.async {
                self.loadCharacterSpecificData()
                self.objectWillChange.send()
            }
            
            print("📥 === キャラクター完全データ読み込み完了 ===")
        }
    }

    // MARK: - Auth
    private func handleAuthStateChange(user: User?) {
        DispatchQueue.main.async {
            if let u = user {
                self.userId = u.uid
                self.isAuthenticated = true
                self.isLoading = false
                self.setupInitialData()
                if self.hasValidCharacter {
                    self.loadCharacterDataComplete() // 🔧 最適化版メソッドを使用
                }
                self.updateAvailableLocations()
                self.scheduleTimeBasedEvents()
            } else {
                self.userId = nil
                self.isAuthenticated = false
                self.isLoading = false
                self.messages.removeAll()
                self.currentDateSession = nil
                self.character = Character()
                self.updateAvailableLocations()
                self.signInAnonymously()
            }
        }
    }

    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.handleAuthStateChange(user: user)
        }
    }

    // MARK: - 親密度システム

    /// 親密度を増加させる（レベルアップチェック付き）
    func increaseIntimacy(by amount: Int, reason: String = "") {
        guard hasValidCharacter else {
            print("❌ 無効なキャラクターのため親密度を増加できません")
            return
        }
        
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
        
        // 🔧 最適化：親密度変更時に即座に保存
        saveCharacterDataComplete()
        updateAvailableLocations()
    }

    /// 親密度レベルアップ処理
    private func handleIntimacyLevelUp(from oldStage: IntimacyStage, to newStage: IntimacyStage, gainedIntimacy: Int) {
        print("🎉 レベルアップ! \(oldStage.displayName) -> \(newStage.displayName)")
        
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

    // MARK: - データ管理（最適化）

    /// 🔧 最適化：ユーザーデータ読み込み（親密度は除外）
    private func loadUserData() {
        guard let uid = userId else { return }
        database.child("users").child(uid).observe(.value) { [weak self] snap in
            guard let self = self, let dict = snap.value as? [String:Any] else { return }
            
            // 共通のユーザーデータのみ管理（親密度はcharactersテーブルで管理）
            if let bday = dict["birthday"] as? TimeInterval {
                self.character.birthday = Date(timeIntervalSince1970: bday)
            }
            if let ann = dict["anniversaryDate"] as? TimeInterval {
                self.character.anniversaryDate = Date(timeIntervalSince1970: ann)
            }
        }
    }

    /// 🔧 最適化：ユーザーデータ保存（親密度は除外）
    private func saveUserData() {
        guard let uid = userId, hasValidCharacter else { return }
        let data: [String:Any] = [
            "birthday": character.birthday?.timeIntervalSince1970 as Any,
            "anniversaryDate": character.anniversaryDate?.timeIntervalSince1970 as Any,
            "lastActiveAt": Date().timeIntervalSince1970
        ]
        database.child("users").child(uid).updateChildValues(data)
    }

    // MARK: - 既存のキャラクターデータ管理メソッドを統合

    private func loadCharacterData() {
        loadCharacterDataComplete()
    }

    private func saveCharacterData() {
        saveCharacterDataComplete()
    }

    // MARK: - その他のメソッド

    func updateAvailableLocations() {
        availableLocations = getAllAvailableLocations()
    }

    func getAllAvailableLocations() -> [DateLocation] {
        guard hasValidCharacter else { return [] }
        
        var locations = DateLocation.availableLocations(for: character.intimacyLevel)
        
        if character.unlockedInfiniteMode {
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

    // MARK: - デートシステム

    /// デートを開始する
    func startDate(at location: DateLocation) {
        print("\n🏖️ ==================== デート開始処理 ====================")
        print("📍 開始場所: \(location.name)")
        print("🏷️ タイプ: \(location.type.displayName)")
        print("💖 親密度ボーナス: +\(location.intimacyBonus)")
        
        guard isAuthenticated && hasValidCharacter else {
            print("❌ 認証またはキャラクター無効")
            return
        }
        
        if let existingSession = currentDateSession {
            print("⚠️ 既存のデートセッションを終了: \(existingSession.location.name)")
            endDate()
        }
        
        let session = DateSession(
            location: location,
            startTime: Date(),
            characterName: character.name
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.currentDateSession = session
        }
        
        if !location.backgroundImage.isEmpty {
            character.backgroundName = location.backgroundImage
            updateCharacterSettings()
        }
        
        let startMessage = Message(
            text: location.getStartMessage(characterName: character.name),
            isFromUser: false,
            timestamp: Date(),
            dateLocation: location.name,
            intimacyGained: 0
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(startMessage)
        }
        
        saveMessage(startMessage)
        
        character.totalDateCount += 1
        
        if location.type == .infinite {
            infiniteDateCount += 1
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
        
        guard hasValidCharacter else {
            print("❌ 有効なキャラクターが設定されていません")
            return
        }
        
        print("\n🏁 ==================== デート終了処理 ====================")
        print("📍 終了場所: \(session.location.name)")
        print("💖 デートスポット親密度ボーナス: +\(session.location.intimacyBonus)")
        
        let endTime = Date()
        let duration = Int(endTime.timeIntervalSince(session.startTime))
        
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
        
        let timeBonus = calculateIntimacyBonus(duration: duration)
        let totalBonus = timeBonus + session.location.intimacyBonus
        
        increaseIntimacy(by: totalBonus, reason: "デート完了: \(session.location.name) (時間:\(timeBonus) + スポット:\(session.location.intimacyBonus))")
        
        if let userId = currentUserID {
            database.child("dateSessions").child(userId).child("isActive").setValue(false)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.currentDateSession = nil
        }
        
        print("🏁 デート終了: \(session.location.name), 総親密度ボーナス: +\(totalBonus)")
        print("==================== デート終了処理完了 ====================\n")
    }

    private func calculateIntimacyBonus(duration: Int) -> Int {
        switch duration {
        case 0..<300: return 0
        case 300..<600: return 2
        case 600..<1200: return 4
        case 1200..<1800: return 6
        case 1800..<3600: return 8
        case 3600..<7200: return 12
        default: return 15
        }
    }

    // MARK: - メッセージシステム

    func sendMessage(_ text: String) {
        print("\n💬 ==================== メッセージ送信開始 ====================")
        print("📤 送信メッセージ: \(text)")
        print("📊 現在の親密度: \(character.intimacyLevel) (\(character.intimacyTitle))")
        
        guard isAuthenticated && hasValidCharacter else {
            print("❌ 認証またはキャラクター無効")
            return
        }
    }
    
    private func processSendMessage(_ text: String, with dateSession: DateSession?) {
        let userMessage = Message(
            text: text,
            isFromUser: true,
            timestamp: Date(),
            dateLocation: dateSession?.location.name,
            intimacyGained: 0
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
        }
        
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
            }
            
            // AI応答による親密度増加
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
    
    func sendSystemMessage(_ text: String) {
        guard isAuthenticated && hasValidCharacter else { return }
        
        let systemMessage = Message(
            text: text,
            isFromUser: false,
            timestamp: Date(),
            dateLocation: currentDateSession?.location.name,
            intimacyGained: 1
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(systemMessage)
        }
        
        saveMessage(systemMessage)
        increaseIntimacy(by: 1, reason: "設定変更への反応")
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

    // MARK: - Firebase関連メソッド
    
    private func setupInitialData() {
        guard let uid = userId else { return }
        
        database.child("users").child(uid).observeSingleEvent(of: .value) { [weak self] snap in
            if !(snap.exists()) {
                self?.createInitialUserDataOnly()
            }
        }
    }

    private func createInitialUserDataOnly() {
        guard let uid = userId else { return }
        let data: [String:Any] = [
            "id": uid,
            "createdAt": Date().timeIntervalSince1970,
            "lastActiveAt": Date().timeIntervalSince1970
        ]
        database.child("users").child(uid).setValue(data)
    }
    
    func updateBackgroundURL(_ url: String?) {
        guard hasValidCharacter else { return }
        character.backgroundURL = url
        saveCharacterDataComplete()
        objectWillChange.send()
    }

    // MARK: - メッセージ管理

    private func loadMessages() {
        guard let conversationId = getConversationId(), hasValidCharacter else { return }
        
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
              let conversationId = getConversationId(),
              hasValidCharacter else { return }
        
        let messageData: [String: Any] = [
            "id": message.id.uuidString,
            "conversationId": conversationId,
            "senderId": message.isFromUser ? userId : character.id,
            "receiverId": message.isFromUser ? character.id : userId,
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
        guard let userId = self.userId, hasValidCharacter else { return nil }
        return "\(userId)_\(character.id)"
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

    private func scheduleTimeBasedEvents() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.checkForTimeBasedEvents()
        }
    }
    
    private func checkForTimeBasedEvents() {
        guard isAuthenticated && hasValidCharacter else { return }
        
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

    // MARK: - 認証メソッド

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

    // MARK: - デバッグ・管理メソッド

    /// メッセージ送信時のデートセッション更新
    func updateDateSessionOnMessage(_ message: Message) {
        guard var session = currentDateSession else { return }
        
        session.messagesExchanged += 1
        
        if !message.isFromUser {
            session.intimacyGained += 1
        }
        
        currentDateSession = session
    }
    
    /// データ削除（テスト用）
    func clearAllData() {
        guard let userId = self.userId,
              let conversationId = getConversationId() else { return }
        
        // ユーザーデータ削除
        database.child("users").child(userId).removeValue()
        
        // キャラクターデータ削除
        if character.isValidCharacter {
            database.child("characters").child(character.id).removeValue()
        }
        
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
            self.currentDateSession = nil
            self.character = Character()
            self.infiniteDateCount = 0
            self.updateAvailableLocations()
        }
    }
    
    /// 親密度リセット
    func resetIntimacyLevel() {
        guard isAuthenticated && hasValidCharacter else { return }
        
        character.intimacyLevel = 0
        character.totalDateCount = 0
        character.unlockedInfiniteMode = false
        infiniteDateCount = 0
        updateAvailableLocations()
        saveCharacterDataComplete()
        
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

    // MARK: - 公開プロパティ

    var currentUserID: String? {
        return userId
    }
    
    var isAnonymousUser: Bool {
        return Auth.auth().currentUser?.isAnonymous ?? false
    }
}
