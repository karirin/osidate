//
//  RomanceAppViewModel.swift
//  osidate
//
//  広告視聴による親密度付与機能を削除したバージョン
//

import SwiftUI
import FirebaseCore
import FirebaseDatabase
import FirebaseAuth
import Combine

@MainActor
class RomanceAppViewModel: ObservableObject {

    // MARK: - Published State
    @Published var character: Character = Character() {
        didSet {
            hasValidCharacter = character.isValidCharacter
            // ログで確認したい場合
            print("hasValidCharacter -> \(hasValidCharacter) (id=\(character.id), name=\(character.name))")
        }
    }
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
    
    let loginBonusManager = LoginBonusManager()
    @Published var showingLoginBonus = false
    
    @Published var didTriggerAutoLoginBonus = false
    
    @Published private var hasAutoClaimedLoginBonus = false
    
    @Published private var isClaimingLoginBonus = false
    
    @Published var adMobManager = AdMobManager()
    @Published var showingAdRequiredAlert = false
    @Published var pendingDateLocation: DateLocation? = nil
    
    @Published var interstitialAdManager = InterstitialAdManager()
    
    private var isLoadingCharacterData = false

    // MARK: - Private Properties
    private let database = Database.database().reference()
    private var userId: String?
    private let characterId: String
    private var authStateListener: AuthStateDidChangeListenerHandle?

    @Published var hasValidCharacter = false
    
    private var cancellables = Set<AnyCancellable>()
    
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
        setupAuthStateListener()
//        initializeWithSubscription()
    }

    deinit {
        if let h = authStateListener {
            Auth.auth().removeStateDidChangeListener(h)
        }
    }
    
    func isAdRequiredForDate(at location: DateLocation) -> Bool {
        // 全てのデートで広告視聴を必須にする場合
        return true
        
        // 特定の条件でのみ広告を必須にしたい場合は以下のような条件を追加
        /*
        // 例：親密度500以上のデートスポットでは広告必須
        return location.requiredIntimacy >= 500
        
        // 例：特別なデートスポットでは広告必須
        return location.isSpecial
        
        // 例：一日に3回目以降のデートでは広告必須
        let today = Calendar.current.startOfDay(for: Date())
        let todayDates = messages.filter { message in
            !message.isFromUser &&
            message.dateLocation != nil &&
            Calendar.current.startOfDay(for: message.timestamp) == today
        }
        return todayDates.count >= 2
        */
    }
    
    /// 広告視聴後にデートを開始する（推奨メソッド）
    func startDateWithAdReward(at location: DateLocation, completion: @escaping (Bool) -> Void) {
        print("🎬 広告必須デート開始処理: \(location.name)")
        
        guard isAuthenticated && hasValidCharacter else {
            print("❌ 認証またはキャラクター無効")
            completion(false)
            return
        }
        
        // 親密度要件チェック
        guard location.requiredIntimacy <= character.intimacyLevel else {
            print("❌ 親密度不足: 必要\(location.requiredIntimacy) vs 現在\(character.intimacyLevel)")
            completion(false)
            return
        }
        
        // 広告が利用可能かチェック
        guard adMobManager.canShowAd else {
            print("❌ 広告が利用できません - 再読み込み試行")
            adMobManager.loadRewardedAd()
            
            // 広告の準備を待ってからもう一度試行
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.adMobManager.canShowAd {
                    self.startDateWithAdReward(at: location, completion: completion)
                } else {
                    completion(false)
                }
            }
            return
        }
        
        // 広告を表示
        adMobManager.showRewardedAd { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(false)
                    return
                }
                
                if success {
                    print("✅ 広告視聴完了 - デート開始")
                    
                    // デートを開始
                    self.startDate(at: location)
                    
                    // 🌟 新機能：タブ切り替え通知を送信
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SwitchToChatTab"),
                            object: nil
                        )
                        print("📱 ViewModle: チャットタブ切り替え通知を送信")
                    }
                    
                    completion(true)
                    
                } else {
                    print("❌ 広告視聴失敗またはキャンセル")
                    completion(false)
                }
            }
        }
    }
    
    /// 🔧 削除：広告視聴感謝メッセージを送信（削除済み）
    // private func sendAdThankYouMessage(for location: DateLocation) - 削除
    
    /// 広告が利用できない場合のエラーメッセージ
    func sendAdNotAvailableMessage() {
        let errorMessage = Message(
            text: "申し訳ございません。現在広告の読み込みに問題が発生しています😣 ネットワーク接続を確認して、しばらく時間をおいてから再度お試しください。",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: nil,
            intimacyGained: 0
        )
        
        DispatchQueue.main.async {
            self.messages.append(errorMessage)
            self.saveMessage(errorMessage)
        }
    }
    
    /// 広告視聴失敗時のメッセージ
    func sendAdFailedMessage() {
        let failMessages = [
            "広告の視聴に失敗しました😢 ネットワーク環境を確認してから、もう一度お試しください。",
            "申し訳ございません。広告の読み込みがうまくいきませんでした💦 少し時間をおいてから再度挑戦してみてくださいね。",
            "広告の表示に問題が発生しました🙏 アプリを再起動してから試していただくか、しばらく時間をおいてからお試しください。"
        ]
        
        let selectedMessage = failMessages.randomElement() ?? failMessages[0]
        
        let failMessage = Message(
            text: selectedMessage,
            isFromUser: false,
            timestamp: Date(),
            dateLocation: nil,
            intimacyGained: 0
        )
        
        DispatchQueue.main.async {
            self.messages.append(failMessage)
            self.saveMessage(failMessage)
        }
    }
    
    // MARK: - 🌟 広告ステータス管理
    
    /// 広告システムの状態を取得
    func getAdSystemStatus() -> AdSystemStatus {
        return AdSystemStatus(
            isAdManagerReady: adMobManager != nil,
            canShowRewardedAd: adMobManager.canShowAd,
            isAdLoading: adMobManager.isLoading,
            lastAdLoadError: adMobManager.adLoadError?.localizedDescription
        )
    }
    
    /// 広告の強制再読み込み
    func forceReloadAds() {
        print("🔄 広告を強制再読み込み")
        adMobManager.loadRewardedAd()
        
        // インタースティシャル広告も再読み込み
        interstitialAdManager.loadInterstitialAd()
    }
    
    /// デバッグ用：広告なしでデート開始（開発時のみ使用）
    #if DEBUG
    func startDateWithoutAd(at location: DateLocation) {
        print("🚧 デバッグ: 広告なしでデート開始")
        
        guard isAuthenticated && hasValidCharacter else {
            print("❌ 認証またはキャラクター無効")
            return
        }
        
        guard location.requiredIntimacy <= character.intimacyLevel else {
            print("❌ 親密度不足")
            return
        }
        
        // デバッグメッセージ
        let debugMessage = Message(
            text: "🚧 デバッグモード: 広告をスキップしてデートを開始します。本番環境では広告視聴が必要になります。",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: location.name,
            intimacyGained: 0
        )
        
        DispatchQueue.main.async {
            self.messages.append(debugMessage)
            self.saveMessage(debugMessage)
        }
        
        // デートを開始
        startDate(at: location)
    }
    #endif
    
    // MARK: - 🔧 削除：広告視聴回数の統計を取得（削除）
    // func getAdViewingStatistics() -> AdViewingStats - 削除
    
    func requestDateWithAd(at location: DateLocation) {
        print("🎬 広告付きデート開始要求: \(location.name)")
        
        // 広告が利用可能かチェック
        guard adMobManager.canShowAd else {
            print("❌ 広告が利用できません")
            // 広告読み込み中の場合は再読み込みを試行
            adMobManager.loadRewardedAd()
            showAdNotAvailableAlert()
            return
        }
        
        // デート場所を保存
        pendingDateLocation = location
        
        // 広告表示確認ダイアログを表示
        showingAdRequiredAlert = true
    }

    func startDateAfterAd() {
        guard let location = pendingDateLocation else {
            print("❌ 保留中のデート場所がありません")
            return
        }
        
        print("🎬 広告視聴開始...")
        
        adMobManager.showRewardedAd { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    print("✅ 広告視聴完了 - デート開始")
                    
                    // 🔧 削除：広告視聴感謝メッセージを削除
                    // self?.sendAdThankYouMessage(for: location)
                    
                    // 🔧 削除：広告視聴ボーナス親密度も削除
                    // self?.increaseIntimacy(by: 1, reason: "広告視聴協力")
                    
                    // デートを開始
                    self?.startDate(at: location)
                    
                } else {
                    print("❌ 広告視聴失敗 - デート開始できません")
                    self?.showAdFailedAlert()
                }
                
                // 保留中の場所をクリア
                self?.pendingDateLocation = nil
            }
        }
    }
    
    // 広告が利用できない場合のアラート
    private func showAdNotAvailableAlert() {
        DispatchQueue.main.async {
            // アラート表示のためのフラグを追加
            // 実装は後述のDateDetailViewで処理
        }
    }
    
    // 広告視聴失敗時のアラート
    private func showAdFailedAlert() {
        let failMessage = Message(
            text: "申し訳ございません。広告の読み込みに問題が発生しました。しばらく時間をおいてから再度お試しください。",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: nil,
            intimacyGained: 0
        )
        
        DispatchQueue.main.async {
            self.messages.append(failMessage)
            self.saveMessage(failMessage)
        }
    }
    
    private var chatCountKey: String {
        return "chatCount_\(character.id)"
    }
    
    // 現在のチャット回数を取得
    func getCurrentChatCount() -> Int {
        return UserDefaults.standard.integer(forKey: chatCountKey)
    }
    
    // チャット回数をリセット
    func resetChatCount() {
        UserDefaults.standard.set(0, forKey: chatCountKey)
        UserDefaults.standard.synchronize()
        print("🔄 チャット回数をリセット: \(character.name)")
    }
    
    func editMessage(_ message: Message, newText: String) {
        // 特定ユーザーかチェック
        if let userID = Auth.auth().currentUser?.uid,
           ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"].contains(userID) {
            print("❌ 編集権限がありません")
            return
        }
        
        print("✏️ メッセージ編集開始: \(message.id)")
        print("   - 編集前: \(message.text)")
        print("   - 編集後: \(newText)")
        
        // ローカルメッセージリストを更新
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var editedMessage = messages[index]
            editedMessage.text = newText
            
            DispatchQueue.main.async {
                self.messages[index] = editedMessage
            }
            
            // Firebaseも更新
            updateMessageInFirebase(editedMessage)
            
            print("✅ メッセージ編集完了")
        } else {
            print("❌ 編集対象メッセージが見つかりません")
        }
    }
    
    private func updateMessageInFirebase(_ message: Message) {
        let messageData: [String: Any] = [
            "id": message.id.uuidString,
            "text": message.text,
            "isFromUser": message.isFromUser,
            "timestamp": message.timestamp.timeIntervalSince1970,
            "dateLocation": message.dateLocation as Any,
            "intimacyGained": message.intimacyGained,
            "lastEditedAt": Date().timeIntervalSince1970 // 編集時刻を追加
        ]
        
        database.child("messages").child(message.id.uuidString).updateChildValues(messageData) { error, _ in
            if let error = error {
                print("❌ Firebase更新エラー: \(error.localizedDescription)")
            } else {
                print("✅ Firebase更新成功")
            }
        }
    }

    /// メッセージを削除する（特定ユーザーのみ）
    func deleteMessage(_ message: Message) {
        // 特定ユーザーかチェック
        if let userID = Auth.auth().currentUser?.uid,
           ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"].contains(userID) {
            print("❌ 削除権限がありません")
            return
        }
        
        print("🗑️ メッセージ削除開始: \(message.id)")
        print("   - 削除対象: \(message.text)")
        
        // ローカルメッセージリストから削除
        DispatchQueue.main.async {
            self.messages.removeAll { $0.id == message.id }
        }
        
        // Firebaseからも削除
        deleteMessageFromFirebase(message)
        
        print("✅ メッセージ削除完了")
    }
    
    private func deleteMessageFromFirebase(_ message: Message) {
        database.child("messages").child(message.id.uuidString).removeValue { error, _ in
            if let error = error {
                print("❌ Firebase削除エラー: \(error.localizedDescription)")
            } else {
                print("✅ Firebase削除成功")
            }
        }
    }
    
    // チャット回数を増加させてインタースティシャル表示をチェック
    private func incrementChatCountAndCheckAd() {
        let currentCount = getCurrentChatCount()
        let newCount = currentCount + 1
        
        UserDefaults.standard.set(newCount, forKey: chatCountKey)
        UserDefaults.standard.synchronize()
        
        print("💬 チャット回数更新: \(newCount) (キャラクター: \(character.name))")
        
        // 5回ごとにインタースティシャル広告を表示
        if newCount % 5 == 0 {
            print("🎬 チャット\(newCount)回に到達 - インタースティシャル広告を表示")
            
            // 少し遅延させて自然なタイミングで表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.interstitialAdManager.showInterstitialAd()
            }
        }
    }
    
    func sendMessageWithAdCheck(_ text: String) {
        print("\n💬 ==================== メッセージ送信開始（広告チェック付き） ====================")
        print("📤 送信メッセージ: \(text)")
        print("📊 現在の親密度: \(character.intimacyLevel) (\(character.intimacyTitle))")
        print("💬 現在のチャット回数: \(getCurrentChatCount())")

        guard isAuthenticated && hasValidCharacter else {
            print("❌ 認証またはキャラクター無効")
            return
        }

        // チャット回数を増加
        if let userID = Auth.auth().currentUser?.uid,
           ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"].contains(userID) {
            incrementChatCountAndCheckAd()
        }
        
        // 既存のメッセージ送信処理
        processSendMessage(text, with: currentDateSession)
    }

    func autoClaimLoginBonusIfAvailable() {
        // 既に自動受け取り済みの場合はスキップ
        guard !hasAutoClaimedLoginBonus else {
            print("ℹ️ ViewModel: 既にログインボーナス自動受け取り済み")
            return
        }
        
        print("🔍 ViewModel: ログインボーナス自動受け取りチェック開始")
        print("   - 認証状態: \(isAuthenticated)")
        print("   - キャラクター有効: \(hasValidCharacter)")
        print("   - キャラクター名: \(character.name)")
        print("   - LoginBonusManager初期化: \(loginBonusManager.userId != nil)")
        print("   - ログインボーナス利用可能: \(loginBonusManager.availableBonus != nil)")
        
        if let bonus = loginBonusManager.availableBonus {
            print("   - ボーナス詳細: 日数=\(bonus.day), 親密度=\(bonus.intimacyBonus), タイプ=\(bonus.bonusType.displayName)")
        }
        
        // 必要条件をチェック
        guard isAuthenticated else {
            print("❌ ViewModel: 認証されていません")
            return
        }
        
        guard hasValidCharacter else {
            print("❌ ViewModel: 有効なキャラクターが設定されていません")
            return
        }
        
        guard loginBonusManager.userId != nil else {
            print("❌ ViewModel: LoginBonusManager未初期化")
            return
        }
        
        guard let bonus = loginBonusManager.availableBonus else {
            print("ℹ️ ViewModel: 本日のログインボーナスは受取済みまたは条件未達成")
            return
        }
        
        // 全ての条件を満たした場合、自動受け取り処理
        print("🎉 ViewModel: 全ての条件を満たしました - ログインボーナスを自動受け取り")
        hasAutoClaimedLoginBonus = true
        
        // 自動受け取り処理を実行
        executeAutoClaimLoginBonus(bonus: bonus)
    }
    
    // MARK: - 🌟 saveMessageメソッド（public）
    func saveMessage(_ message: Message) {
        guard let userId = self.userId,
              let conversationId = getConversationId(),
              hasValidCharacter else {
            print("❌ ViewModel: saveMessage条件不足")
            return
        }
        
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
    
    // MARK: - 🌟 getConversationIdメソッド（public）
    func getConversationId() -> String? {
        guard let userId = self.userId, hasValidCharacter else { return nil }
        return "\(userId)_\(character.id)"
    }
    
    // MARK: - 🌟 デバッグ用：自動受け取りフラグリセット
    #if DEBUG
    func resetAutoClaimFlag() {
        hasAutoClaimedLoginBonus = false
        print("🔧 ViewModel: ログインボーナス自動受け取りフラグをリセット")
    }
    #endif
    
    private func handleAuthStateChange(user: User?) {
        DispatchQueue.main.async {
            if let u = user {
                self.userId = u.uid
                self.isAuthenticated = true
                self.isLoading = false
                
                print("🔐 認証完了: \(u.uid)")
                
                // 🌟 修正: 自動受け取りフラグをリセット
                self.hasAutoClaimedLoginBonus = false
                
                // 🌟 修正: 順序立てた初期化を実行
                self.setupUserDataSequentially(userId: u.uid)
                
            } else {
                self.userId = nil
                self.isAuthenticated = false
                self.isLoading = false
                self.hasAutoClaimedLoginBonus = false
                self.messages.removeAll()
                self.currentDateSession = nil
                self.character = Character()
                self.updateAvailableLocations()
                self.signInAnonymously()
            }
        }
    }
    
    // MARK: - 🌟 順序立てた初期化メソッド
    private func setupUserDataSequentially(userId: String) {
        print("🚀 === ユーザーデータ順序初期化開始 ===")
        
        // 1. 基本ユーザーデータを初期化
        setupInitialData()
        
        // 2. ログインボーナスシステムを初期化
        loginBonusManager.initialize(userId: userId)
        
        // 3. その他の初期化
        updateAvailableLocations()
        scheduleTimeBasedEvents()
        
        print("✅ === ユーザーデータ順序初期化完了 ===")
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
    
    func updateUserCsFlag(userId: String, userCsFlag: Int, completion: @escaping (Bool) -> Void) {
        let userRef = Database.database().reference().child("users").child(userId)
        let updates = ["userCsFlag": userCsFlag]
        print(updates)
        userRef.updateChildValues(updates) { (error, _) in
            if let error = error {
                print("Error updating tutorialNum: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func updateContact(userId: String, newContact: String, completion: @escaping (Bool) -> Void) {
        // contactテーブルの下の指定されたuserIdの参照を取得
        let contactRef = Database.database().reference().child("contacts").child(userId)
        // まず現在のcontactの値を読み取る
        contactRef.observeSingleEvent(of: .value, with: { snapshot in
            // 既存の問い合わせ内容を保持する変数を準備
            var contacts: [String] = []
            
            // 現在の問い合わせ内容がある場合、それを読み込む
            if let currentContacts = snapshot.value as? [String] {
                contacts = currentContacts
            }
            
            // 新しい問い合わせ内容をリストに追加
            contacts.append(newContact)
            
            // データベースを更新する
            contactRef.setValue(contacts, withCompletionBlock: { error, _ in
                if let error = error {
                    print("Error updating contact: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            })
        }) { error in
            print(error.localizedDescription)
            completion(false)
        }
    }
    
    /// 🔧 最適化：推しを切り替える（charactersテーブル直接管理）
    func switchToCharacter(_ newCharacter: Character) {
        print("\n🔄 ==================== キャラクター切り替え開始 ====================")
        print("📤 切り替え前: \(character.name) (ID: \(character.id))")
        print("📥 切り替え後: \(newCharacter.name) (ID: \(newCharacter.id))")
        
        // 🔧 修正：キャラクター切り替え時に現在のデートセッションを終了
        if let currentSession = currentDateSession {
            print("🏁 キャラクター切り替えのため現在のデートセッションを終了: \(currentSession.location.name)")
            endDate()
        }
        
        // 現在の状態を保存（有効なキャラクターの場合のみ）
        if character.isValidCharacter {
            saveCurrentCharacterState()
        }
        
        // 🔧 修正：メインスレッドで確実に更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // キャラクターを切り替え
            self.character = newCharacter
            
            // 🔧 修正：デートセッションをクリア（念のため）
            self.currentDateSession = nil
            
            // 🔧 修正：明示的に更新通知を送信
            self.objectWillChange.send()
            
            // 新しいキャラクターのデータを読み込み
            self.loadCharacterDataComplete()
            
            print("✅ キャラクター切り替え完了")
            print("🎭 新キャラクター情報:")
            print("   - 名前: \(self.character.name)")
            print("   - ID: \(self.character.id)")
            print("   - アイコンURL: \(self.character.iconURL ?? "なし")")
            print("   - 親密度: \(self.character.intimacyLevel)")
            print("   - デートセッション: \(self.currentDateSession?.location.name ?? "なし")")
            print("==================== キャラクター切り替え終了 ====================\n")
        }
    }
    
    func forceUpdateCharacterProperties() {
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    @MainActor
    func setupSubscriptionIntegration() {
        // サブスクリプション状態の変更を監視
        SubscriptionManager.shared.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSubscribed in
                self?.handleSubscriptionStatusChange(isSubscribed: isSubscribed)
            }
            .store(in: &cancellables)
    }
    
    func sendMessageWithSubscriptionCheck(_ text: String) {
        // SubscriptionManagerが利用可能でない場合は既存のメソッドを使用
        if SubscriptionManager.shared.shouldShowAds {
            sendMessageWithAdCheck(text)  // 既存のメソッド
        } else {
            sendMessage(text)  // 既存のメソッド（広告なし）
        }
    }

    // handleSubscriptionStatusChangeメソッド
    func handleSubscriptionStatusChange(isSubscribed: Bool) {
        print("📱 サブスクリプション状態変更: \(isSubscribed ? "有効" : "無効")")
    }
    
    /// ViewModelの初期化時にサブスクリプション統合をセットアップ
    func initializeWithSubscription() {
        setupSubscriptionIntegration()
        
        // サブスクリプション状態を即座に更新
        Task {
            await SubscriptionManager.shared.refreshSubscriptionStatus()
        }
    }
    
    func notifyCharacterChanged() {
        // UI更新のために少し遅延させる
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.objectWillChange.send()
        }
    }
    
    // アイコンのリフレッシュを強制的に行う
    func forceRefreshCharacterIcon() {
        // キャラクターアイコンの強制更新
        self.objectWillChange.send()
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
        
        print("💾 Firebase保存データ:")
        print("   - intimacyLevel: \(characterData["intimacyLevel"] ?? "nil")")
        print("   - id: \(characterData["id"] ?? "nil")")
        
        database.child("characters").child(character.id).updateChildValues(characterData) { error, _ in
            if let error = error {
                print("❌ キャラクターデータ保存失敗: \(error.localizedDescription)")
            } else {
                print("✅ キャラクターデータ保存成功")
                print("   - 保存された親密度: \(self.character.intimacyLevel)")
            }
        }
        
        print("💾 === キャラクター完全データ保存完了 ===")
    }
    
    /// 🔧 最適化：キャラクターの全データを読み込み（親密度含む）
    private func loadCharacterDataComplete() {
        guard !isLoadingCharacterData else {
            print("⏳ 既にキャラクターデータ読み込み中のためスキップ")
            return
        }
        isLoadingCharacterData = true
        
        guard character.isValidCharacter else {
            print("❌ 読み込み条件不足: キャラクター無効")
            return
        }
        
        print("📥 === キャラクター完全データ読み込み開始 ===")
        print("🎭 対象キャラクター: \(character.name) (ID: \(character.id))")
        print("📊 読み込み前の親密度: \(character.intimacyLevel)")
        
        database.child("characters").child(character.id).observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let self = self,
                  let data = snapshot.value as? [String: Any] else {
                print("❌ キャラクターデータが見つかりません")
                return
            }
            defer { self.isLoadingCharacterData = false }
            print("📥 キャラクターデータ読み込み中...")
            print("📊 Firebase内の親密度: \(data["intimacyLevel"] as? Int ?? 0)")
            
            // 🌟 修正：現在の親密度を保持
            let currentIntimacyLevel = self.character.intimacyLevel
            print("📊 現在メモリ内の親密度: \(currentIntimacyLevel)")
            
            // 基本プロパティを更新（親密度以外）
            if let name = data["name"] as? String { self.character.name = name }
            if let personality = data["personality"] as? String { self.character.personality = personality }
            if let speakingStyle = data["speakingStyle"] as? String { self.character.speakingStyle = speakingStyle }
            if let iconName = data["iconName"] as? String { self.character.iconName = iconName }
            if let iconURL = data["iconURL"] as? String { self.character.iconURL = iconURL }
            if let backgroundName = data["backgroundName"] as? String { self.character.backgroundName = backgroundName }
            if let backgroundURL = data["backgroundURL"] as? String { self.character.backgroundURL = backgroundURL }
            if let userNickname = data["userNickname"] as? String { self.character.userNickname = userNickname }
            if let useNickname = data["useNickname"] as? Bool { self.character.useNickname = useNickname }
            
            // 🌟 修正：親密度は現在の値とFirebaseの値を比較して大きい方を採用
            if let firebaseIntimacyLevel = data["intimacyLevel"] as? Int {
                let finalIntimacyLevel = max(currentIntimacyLevel, firebaseIntimacyLevel)
                self.character.intimacyLevel = finalIntimacyLevel
                
                print("📊 親密度決定ロジック:")
                print("   - Firebase値: \(firebaseIntimacyLevel)")
                print("   - メモリ値: \(currentIntimacyLevel)")
                print("   - 採用値: \(finalIntimacyLevel)")
                
                // 値が変更された場合は保存
                if finalIntimacyLevel != firebaseIntimacyLevel {
                    print("💾 親密度が更新されたため保存実行")
                    self.saveCharacterDataComplete()
                }
            } else {
                // Firebaseに親密度データがない場合は現在の値を保持
                print("📊 Firebase親密度データなし - 現在値を保持: \(currentIntimacyLevel)")
            }
            
            // その他のデータを読み込み
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
        })
    }
    
    func getLoginBonusStatistics() -> (totalBonuses: Int, totalIntimacy: Int, currentStreak: Int, totalDays: Int) {
        return (
            totalBonuses: loginBonusManager.loginHistory.count,
            totalIntimacy: loginBonusManager.getTotalIntimacyFromBonuses(),
            currentStreak: loginBonusManager.currentStreak,
            totalDays: loginBonusManager.totalLoginDays
        )
    }

    /// 今日のログインステータスを取得
    func getTodayLoginStatus() -> (hasLoggedIn: Bool, hasClaimed: Bool, availableBonus: LoginBonus?) {
        let tz = TimeZone(identifier: "Asia/Tokyo")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        let hasLoggedInToday = loginBonusManager.lastLoginDate.map {
            cal.isDateInToday($0)
        } ?? false

        let hasClaimed = (loginBonusManager.availableBonus == nil) && hasLoggedInToday

        return (hasLoggedIn: hasLoggedInToday,
                hasClaimed: hasClaimed,
                availableBonus: loginBonusManager.availableBonus)
    }
    
    // MARK: - 🌟 自動発火付きログインボーナス初期化
    private func initializeLoginBonusSystemWithAutoTrigger(userId: String) {
        print("🎁 === ログインボーナス自動発火システム初期化 ===")
        
        // LoginBonusManagerを初期化
        loginBonusManager.initialize(userId: userId)
        
        // 初期化完了を待って自動発火をチェック
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAndAutoTriggerLoginBonus()
        }
    }
    
    // MARK: - 🌟 ログインボーナス自動発火チェック
    private func checkAndAutoTriggerLoginBonus() {
        print("🔍 ログインボーナス自動発火チェック開始")
        
        // 認証とキャラクターの有効性を再確認
        guard isAuthenticated && hasValidCharacter else {
            print("❌ 自動発火条件不足: 認証=\(isAuthenticated), キャラクター有効=\(hasValidCharacter)")
            return
        }
        
        // ログインボーナスマネージャーの初期化完了を確認
        guard loginBonusManager.userId != nil else {
            print("❌ LoginBonusManager未初期化のため自動発火をスキップ")
            // リトライ
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkAndAutoTriggerLoginBonus()
            }
            return
        }
        
        print("📊 現在の状況:")
        print("  - 認証状態: \(isAuthenticated)")
        print("  - キャラクター有効: \(hasValidCharacter)")
        print("  - ログインボーナス利用可能: \(loginBonusManager.availableBonus != nil)")
        print("  - 連続ログイン: \(loginBonusManager.currentStreak)日")
        print("  - 最終ログイン: \(loginBonusManager.lastLoginDate?.description ?? "なし")")
        
        // 利用可能なボーナスがある場合は自動表示
        if loginBonusManager.availableBonus != nil {
            print("🎁 利用可能なログインボーナスを検出 -> 自動表示")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showingLoginBonus = true
            }
        } else {
            print("ℹ️ 本日のログインボーナスは受取済みまたは条件未達成")
        }
    }
    
    private func initializeLoginBonusSystem(userId: String) {
        print("🎁 ログインボーナスシステム初期化開始")
        
        // LoginBonusManagerを初期化
        loginBonusManager.initialize(userId: userId)
        
        print("✅ ログインボーナスシステム初期化完了")
    }
    
    func fetchUserFlag(completion: @escaping (Int?, Error?) -> Void) {
        guard let userId = userId else { return }

        let userRef = Database.database().reference().child("users").child(userId)
        // "userFlag"の値を取得する
        userRef.child("userFlag").observeSingleEvent(of: .value) { snapshot in
            if let userFlag = snapshot.value as? Int {
                // userFlagが存在し、Int型として取得できた場合
                DispatchQueue.main.async {
                    completion(userFlag, nil)
                }
            } else {
                // userFlagが存在しない場合は0を返す
                DispatchQueue.main.async {
                    completion(0, nil)
                }
            }
        } withCancel: { error in
            // データベースの読み取りに失敗した場合
            DispatchQueue.main.async {
                completion(nil, error)
            }
        }
    }
    
    func updateUserFlag(userId: String, userFlag: Int, completion: @escaping (Bool) -> Void) {
        let userRef = Database.database().reference().child("users").child(userId)
        let updates = ["userFlag": userFlag]
        userRef.updateChildValues(updates) { (error, _) in
            if let error = error {
                print("Error updating tutorialNum: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    // MARK: - setupInitialData の修正版

    private func setupInitialData() {
        guard let uid = userId else { return }
        
        // ユーザーデータの初期化をチェック
        database.child("users").child(uid).observeSingleEvent(of: .value, with: { [weak self] snap in
            if !(snap.exists()) {
                print("👤 新規ユーザー検出: 初期データを作成")
                self?.createInitialUserDataOnly()
            } else {
                print("👤 既存ユーザー検出: データ読み込み")
            }
        })
    }

    // MARK: - デバッグメソッド追加

    #if DEBUG

    /// デバッグ用：ログインボーナスシステムを強制再初期化
    func forceReinitializeLoginBonus() {
        guard let uid = userId else { return }
        
        print("🔧 デバッグ: ログインボーナスシステム強制再初期化")
        
        
        // 再初期化
        initializeLoginBonusSystem(userId: uid)
    }

    /// デバッグ用：初回ユーザーとして強制初期化
    func simulateFirstTimeUserLoginBonus() {
        loginBonusManager.forceInitializeFirstTimeUser()
    }

    /// デバッグ用：認証フローを再実行
    func debugReinitializeAuth() {
        if let currentUser = Auth.auth().currentUser {
            handleAuthStateChange(user: currentUser)
        }
    }

    #endif

    // MARK: - ログイン処理の改善

    /// ログインボーナス処理を実行（修正版）
    private func processLoginBonus() {
        guard isAuthenticated && hasValidCharacter else {
            print("❌ ログインボーナス処理: 認証またはキャラクター無効")
            return
        }
        
        print("🎁 ログインボーナス処理チェック")
        
        // LoginBonusManagerが初期化済みかチェック
        if loginBonusManager.userId != nil {
            // 既に初期化済みの場合は通常のログイン処理
            loginBonusManager.processLogin()
        } else {
            print("⚠️ LoginBonusManagerが初期化されていません")
            if let uid = userId {
                initializeLoginBonusSystem(userId: uid)
            }
        }
    }

    // MARK: - 手動ログインボーナス表示の修正

    func showLoginBonusManually() {
        print("👆 手動ログインボーナス表示要求")
        
        // 初期化チェック
        if loginBonusManager.userId == nil {
            if let uid = userId {
                print("🔄 ログインボーナスマネージャーを初期化してから表示")
                initializeLoginBonusSystemWithAutoTrigger(userId: uid)
                return
            }
        }
        
        if loginBonusManager.availableBonus != nil {
            print("🎁 手動表示: 利用可能なボーナスあり")
            showingLoginBonus = true
        } else {
            print("ℹ️ 手動表示: 本日は受取済み")
            let message = Message(
                text: "今日のログインボーナスは既に受け取り済みです。明日もお忘れなく！💕",
                isFromUser: false,
                timestamp: Date(),
                dateLocation: nil,
                intimacyGained: 0
            )
            
            DispatchQueue.main.async {
                self.messages.append(message)
                self.saveMessage(message)
            }
        }
    }
    
    private func executeAutoClaimLoginBonus(bonus: LoginBonus) {
        print("🎁 ViewModel: ログインボーナス自動受け取り実行開始")
        print("   - ボーナス: \(bonus.day)日目 +\(bonus.intimacyBonus) (\(bonus.bonusType.displayName))")
        print("   - 受け取り前の親密度: \(character.intimacyLevel)")
        
        // 🌟 受け取り中フラグを設定（データ読み込みによる上書きを防ぐ）
        isClaimingLoginBonus = true
        
        // ボーナスを受け取り（LoginBonusManagerのclaimBonusメソッドを使用）
        loginBonusManager.claimBonus { [weak self] intimacyBonus, reason in
            guard let self = self else { return }
            
            print("✅ ViewModel: ログインボーナス受け取りコールバック開始")
            print("   - 親密度増加予定: +\(intimacyBonus)")
            print("   - 理由: \(reason)")
            print("   - 現在の親密度: \(self.character.intimacyLevel)")
            
            // 🌟 明示的にメインスレッドで親密度増加を実行
            DispatchQueue.main.async {
                print("🔄 ViewModel: メインスレッドで親密度増加開始")
                let oldIntimacy = self.character.intimacyLevel
                
                // 親密度増加
                self.increaseIntimacy(by: intimacyBonus, reason: reason)
                
                print("📊 ViewModel: 親密度更新結果")
                print("   - 更新前: \(oldIntimacy)")
                print("   - 更新後: \(self.character.intimacyLevel)")
                print("   - 差分: +\(self.character.intimacyLevel - oldIntimacy)")
                
                // 🌟 受け取り完了フラグを解除
                self.isClaimingLoginBonus = false
                
                // 🌟 UI更新を確実にするため明示的に通知
                self.objectWillChange.send()
                
                // 🌟 自動受け取り後にモーダル画面を表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🎊 ViewModel: ログインボーナスモーダル画面を表示")
                    print("   - 表示時の親密度: \(self.character.intimacyLevel)")
                    self.showingLoginBonus = true
                }
            }
            
            print("🎊 ViewModel: ログインボーナス自動受け取り完了")
        }
    }

    // MARK: - その他のメソッド

    func updateAvailableLocations() {
        availableLocations = getAllAvailableLocations()
    }

    func getAllAvailableLocations() -> [DateLocation] {
        guard hasValidCharacter else { return [] }
        
        var locations = DateLocation.availableLocations(for: character.intimacyLevel)
        
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

        // ★ これを呼ぶ
        processSendMessage(text, with: currentDateSession)
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
            .observe(.value, with: { [weak self] snapshot in
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
            })
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
            
            // 新しい日になったらログインボーナスをチェック
            self.checkForNewDayLoginBonus()
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

    private func checkForNewDayLoginBonus() {
        guard isAuthenticated && hasValidCharacter else { return }
        
        let now = Date()
        let calendar = Calendar.current
        
        // 最後のログインから日付が変わっているかチェック
        if let lastLogin = loginBonusManager.lastLoginDate {
            if !calendar.isDate(lastLogin, inSameDayAs: now) {
                print("📅 新しい日を検出：ログインボーナスを再処理")
                processLoginBonus()
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
        print("💕 === increaseIntimacy開始 ===")
        print("   - 増加予定: +\(amount)")
        print("   - 理由: \(reason)")
        print("   - hasValidCharacter: \(hasValidCharacter)")
        print("   - キャラクター名: \(character.name)")
        print("   - 処理前の親密度: \(character.intimacyLevel)")
        
        guard hasValidCharacter else {
            print("❌ 無効なキャラクターのため親密度を増加できません")
            return
        }
        
        guard amount > 0 else {
            print("❌ 増加量が0以下のため処理をスキップ: \(amount)")
            return
        }
        
        let oldLevel = character.intimacyLevel
        let oldStage = character.intimacyStage
        
        print("   - 更新前レベル: \(oldLevel)")
        print("   - 更新前ステージ: \(oldStage.displayName)")
        
        // 🌟 確実な加算処理
        let newLevel = oldLevel + amount
        character.intimacyLevel = newLevel
        
        print("   - 加算計算: \(oldLevel) + \(amount) = \(newLevel)")
        print("   - 実際の設定値: \(character.intimacyLevel)")
        print("   - 検証: 正しく設定されている = \(character.intimacyLevel == newLevel)")
        
        // 🌟 加算が正しく行われたかダブルチェック
        if character.intimacyLevel != newLevel {
            print("⚠️ 親密度設定に問題発生！強制的に正しい値を設定")
            character.intimacyLevel = newLevel
        }
        
        let actualIncrease = character.intimacyLevel - oldLevel
        print("🔥 親密度増加実行: +\(amount) -> \(character.intimacyLevel) (実際の増加: +\(actualIncrease)) (\(reason))")
        
        // レベルアップチェック
        let newStage = character.intimacyStage
        print("   - 更新後ステージ: \(newStage.displayName)")
        
        if newStage != oldStage {
            print("🎉 レベルアップ発生! \(oldStage.displayName) -> \(newStage.displayName)")
            handleIntimacyLevelUp(from: oldStage, to: newStage, gainedIntimacy: amount)
        }
        
        // 無限モード解放の条件を5000レベルのまま維持（変更なし）
        if character.intimacyLevel >= 5000 && !character.unlockedInfiniteMode {
            character.unlockedInfiniteMode = true
            showInfiniteModeUnlockedMessage()
            print("♾️ 無限モード解放!")
        }
        
        // 🌟 即座にデータ保存（上書きされる前に）
        print("💾 親密度変更をFirebaseに即座に保存開始")
        let saveBeforeLevel = character.intimacyLevel
        saveCharacterDataComplete()
        print("💾 親密度変更をFirebase保存完了")
        print("💾 保存時の親密度: \(saveBeforeLevel)")
        print("💾 保存後の親密度: \(character.intimacyLevel)")
        
        updateAvailableLocations()
        
        // 🌟 UI更新を確実にするため明示的に通知
        DispatchQueue.main.async {
            self.objectWillChange.send()
            print("🔄 UI更新通知送信完了")
            print("🔄 通知送信時の親密度: \(self.character.intimacyLevel)")
        }
        
        print("💕 === increaseIntimacy完了 ===")
        print("   - 最終的な親密度: \(character.intimacyLevel)")
        print("   - 期待値との一致: \(character.intimacyLevel == newLevel)")
    }

    /// 親密度レベルアップ処理
    private func handleIntimacyLevelUp(from oldStage: IntimacyStage, to newStage: IntimacyStage, gainedIntimacy: Int) {
        print("🎉 レベルアップ! \(oldStage.displayName) -> \(newStage.displayName)")
        
        // 🌟 特定ユーザーの場合はレベルアップメッセージを表示しない
        if let userID = Auth.auth().currentUser?.uid,
           ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"].contains(userID) {
            print("🎯 特別ユーザー: レベルアップメッセージをスキップ")
            
            // 新しいデートスポット解放通知のみ処理
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
            
            return // ここで処理を終了
        }
        
        // 🌟 通常ユーザーの場合は従来通りレベルアップメッセージを表示
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
        database.child("users").child(uid).observe(.value, with: { [weak self] snap in
            guard let self = self, let dict = snap.value as? [String:Any] else { return }
            
            // 共通のユーザーデータのみ管理（親密度はcharactersテーブルで管理）
            if let bday = dict["birthday"] as? TimeInterval {
                self.character.birthday = Date(timeIntervalSince1970: bday)
            }
            if let ann = dict["anniversaryDate"] as? TimeInterval {
                self.character.anniversaryDate = Date(timeIntervalSince1970: ann)
            }
        })
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

    // MARK: - 公開プロパティ

    var currentUserID: String? {
        return userId
    }
    
    var isAnonymousUser: Bool {
        return Auth.auth().currentUser?.isAnonymous ?? false
    }
}

struct AdSystemStatus {
    let isAdManagerReady: Bool
    let canShowRewardedAd: Bool
    let isAdLoading: Bool
    let lastAdLoadError: String?
    
    var statusDescription: String {
        if !isAdManagerReady {
            return "広告システム初期化中..."
        } else if isAdLoading {
            return "広告読み込み中..."
        } else if canShowRewardedAd {
            return "広告利用可能"
        } else {
            return lastAdLoadError ?? "広告利用不可"
        }
    }
}

extension Image {
    static func safe(_ name: String, fallback: String = "bg_fallback") -> Image {
        UIImage(named: name) != nil ? Image(name) : Image(fallback)
    }
}
