//
//  RomanceAppViewModel.swift
//  osidate
//
//  Updated for Firebase Realtime Database integration
//

import SwiftUI
import FirebaseCore
import FirebaseDatabase

class RomanceAppViewModel: ObservableObject {
    @Published var character: Character
    @Published var messages: [Message] = []
    @Published var currentDateLocation: DateLocation?
    @Published var availableLocations: [DateLocation] = []
    @Published var showingDateView = false
    @Published var showingSettings = false
    
    private let database = Database.database().reference()
    private let userId = "user_\(UUID().uuidString)" // 実際のアプリでは認証されたユーザーIDを使用
    
    private let dateLocations = [
        DateLocation(name: "カフェ", backgroundImage: "cafe", requiredIntimacy: 0, description: "落ち着いたカフェでお話しましょう"),
        DateLocation(name: "公園", backgroundImage: "park", requiredIntimacy: 10, description: "緑豊かな公園を一緒に散歩"),
        DateLocation(name: "映画館", backgroundImage: "cinema", requiredIntimacy: 25, description: "映画を一緒に楽しみましょう"),
        DateLocation(name: "遊園地", backgroundImage: "amusement", requiredIntimacy: 50, description: "楽しいアトラクションで盛り上がろう"),
        DateLocation(name: "海辺", backgroundImage: "beach", requiredIntimacy: 70, description: "ロマンチックな海辺での特別な時間")
    ]
    
    init() {
        self.character = Character(
            name: "あい",
            personality: "優しくて思いやりがある",
            speakingStyle: "丁寧で温かい",
            iconName: "person.circle.fill",
            backgroundName: "defaultBG"
        )
        
        loadCharacterData()
        loadMessages()
        updateAvailableLocations()
        scheduleTimeBasedEvents()
        observeMessages()
    }
    
    // MARK: - Firebase Data Operations
    
    private func loadCharacterData() {
        database.child("users").child(userId).child("character").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            if let data = snapshot.value as? [String: Any] {
                DispatchQueue.main.async {
                    if let name = data["name"] as? String {
                        self.character.name = name
                    }
                    if let personality = data["personality"] as? String {
                        self.character.personality = personality
                    }
                    if let speakingStyle = data["speakingStyle"] as? String {
                        self.character.speakingStyle = speakingStyle
                    }
                    if let intimacyLevel = data["intimacyLevel"] as? Int {
                        self.character.intimacyLevel = intimacyLevel
                    }
                    if let birthdayTimestamp = data["birthday"] as? TimeInterval {
                        self.character.birthday = Date(timeIntervalSince1970: birthdayTimestamp)
                    }
                    if let anniversaryTimestamp = data["anniversaryDate"] as? TimeInterval {
                        self.character.anniversaryDate = Date(timeIntervalSince1970: anniversaryTimestamp)
                    }
                    self.updateAvailableLocations()
                }
            }
        }
    }
    
    private func saveCharacterData() {
        var characterData: [String: Any] = [
            "name": character.name,
            "personality": character.personality,
            "speakingStyle": character.speakingStyle,
            "iconName": character.iconName,
            "backgroundName": character.backgroundName,
            "intimacyLevel": character.intimacyLevel
        ]
        
        if let birthday = character.birthday {
            characterData["birthday"] = birthday.timeIntervalSince1970
        }
        
        if let anniversary = character.anniversaryDate {
            characterData["anniversaryDate"] = anniversary.timeIntervalSince1970
        }
        
        database.child("users").child(userId).child("character").setValue(characterData)
    }
    
    private func loadMessages() {
        database.child("users").child(userId).child("messages").observeSingleEvent(of: .value) { [weak self] snapshot in
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
    
    private func observeMessages() {
        database.child("users").child(userId).child("messages").observe(.childAdded) { [weak self] snapshot in
            guard let self = self else { return }
            
            if let messageData = snapshot.value as? [String: Any],
               let message = self.messageFromFirebaseData(messageData) {
                
                DispatchQueue.main.async {
                    // 既存のメッセージと重複しないかチェック
                    if !self.messages.contains(where: { $0.id == message.id }) {
                        self.messages.append(message)
                        self.messages.sort { $0.timestamp < $1.timestamp }
                    }
                }
            }
        }
    }
    
    private func saveMessage(_ message: Message) {
        let messageData: [String: Any] = [
            "id": message.id.uuidString,
            "text": message.text,
            "isFromUser": message.isFromUser,
            "timestamp": message.timestamp.timeIntervalSince1970,
            "dateLocation": message.dateLocation ?? NSNull()
        ]
        
        database.child("users").child(userId).child("messages").child(message.id.uuidString).setValue(messageData)
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
        
        return Message(id: id, text: text, isFromUser: isFromUser, timestamp: timestamp, dateLocation: dateLocation)
    }
    
    // MARK: - Public Methods
    
    func updateAvailableLocations() {
        availableLocations = dateLocations.filter { $0.requiredIntimacy <= character.intimacyLevel }
    }
    
    func sendMessage(_ text: String) {
        let userMessage = Message(text: text, isFromUser: true, timestamp: Date(), dateLocation: currentDateLocation?.name)
        
        // ローカルに追加
        messages.append(userMessage)
        
        // Firebaseに保存
        saveMessage(userMessage)
        
        // 親密度を上げる
        character.intimacyLevel += 1
        updateAvailableLocations()
        saveCharacterData()
        
        // AI応答をシミュレート
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = self.generateAIResponse(to: text)
            let aiMessage = Message(text: response, isFromUser: false, timestamp: Date(), dateLocation: self.currentDateLocation?.name)
            
            // ローカルに追加
            self.messages.append(aiMessage)
            
            // Firebaseに保存
            self.saveMessage(aiMessage)
        }
    }
    
    func updateCharacterSettings() {
        saveCharacterData()
    }
    
    private func generateAIResponse(to input: String) -> String {
        // 簡単なAI応答シミュレーション（実際のアプリでは外部AIサービスを使用）
        let responses = [
            "それは素敵ですね！\(character.name)も同じように思います💕",
            "あなたと話していると、とても楽しい気持ちになります😊",
            "もっとあなたのことを知りたいです！",
            "一緒にいる時間が一番幸せです✨",
            "\(character.name)はあなたのことをもっと理解したいと思っています"
        ]
        
        // 時間帯に応じた応答
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...11:
            return "おはようございます！今日も素敵な一日になりそうですね🌅"
        case 12...17:
            return "こんにちは！お疲れ様です。少し休憩しませんか？☀️"
        case 18...23:
            return "こんばんは！今日はどんな一日でしたか？🌙"
        default:
            return responses.randomElement() ?? "ありがとうございます💕"
        }
    }
    
    func startDate(at location: DateLocation) {
        currentDateLocation = location
        showingDateView = true
        character.intimacyLevel += 5
        updateAvailableLocations()
        saveCharacterData()
        
        let dateMessage = Message(
            text: "\(location.name)でのデートが始まりました！\(location.description)",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: location.name
        )
        
        messages.append(dateMessage)
        saveMessage(dateMessage)
    }
    
    func endDate() {
        currentDateLocation = nil
        showingDateView = false
        
        let endMessage = Message(
            text: "素敵な時間をありがとうございました！また一緒に過ごしましょうね💕",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: nil
        )
        
        messages.append(endMessage)
        saveMessage(endMessage)
    }
    
    private func scheduleTimeBasedEvents() {
        // 実際のアプリでは、バックグラウンド処理やプッシュ通知を使用
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.checkForTimeBasedEvents()
        }
    }
    
    private func checkForTimeBasedEvents() {
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
            messages.append(birthdayMessage)
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
            messages.append(anniversaryMessage)
            saveMessage(anniversaryMessage)
        }
    }
}
