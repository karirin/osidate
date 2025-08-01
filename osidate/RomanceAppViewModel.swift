//
//  RomanceAppViewModel.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI

class RomanceAppViewModel: ObservableObject {
    @Published var character: Character
    @Published var messages: [Message] = []
    @Published var currentDateLocation: DateLocation?
    @Published var availableLocations: [DateLocation] = []
    @Published var showingDateView = false
    @Published var showingSettings = false
    
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
        updateAvailableLocations()
        scheduleTimeBasedEvents()
    }
    
    func updateAvailableLocations() {
        availableLocations = dateLocations.filter { $0.requiredIntimacy <= character.intimacyLevel }
    }
    
    func sendMessage(_ text: String) {
        let userMessage = Message(text: text, isFromUser: true, timestamp: Date(), dateLocation: currentDateLocation?.name)
        messages.append(userMessage)
        
        // 親密度を上げる
        character.intimacyLevel += 1
        updateAvailableLocations()
        
        // AI応答をシミュレート
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = self.generateAIResponse(to: text)
            let aiMessage = Message(text: response, isFromUser: false, timestamp: Date(), dateLocation: self.currentDateLocation?.name)
            self.messages.append(aiMessage)
        }
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
        
        let dateMessage = Message(
            text: "\(location.name)でのデートが始まりました！\(location.description)",
            isFromUser: false,
            timestamp: Date(),
            dateLocation: location.name
        )
        messages.append(dateMessage)
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
        }
    }
}
