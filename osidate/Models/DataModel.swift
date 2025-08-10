//
//  DataModel.swift
//  osidate
//
//  Extended intimacy system and expanded date locations
//

import SwiftUI
import Foundation

class Character: ObservableObject, Codable {
    @Published var id: String
    @Published var name: String
    @Published var personality: String
    @Published var speakingStyle: String
    @Published var intimacyLevel: Int
    @Published var birthday: Date?
    @Published var anniversaryDate: Date?
    @Published var iconURL: String?
    @Published var iconName: String
    @Published var backgroundName: String
    @Published var backgroundURL: String?
    @Published var totalDateCount: Int = 0
    @Published var unlockedInfiniteMode: Bool = false
    
    // 🌟 拡張された親密度タイトルシステム
    var intimacyTitle: String {
        switch intimacyLevel {
        case 0...100: return "親友"
        case 101...200: return "特別な友達"
        case 201...300: return "恋人候補"
        case 301...500: return "恋人"
        case 501...700: return "深い絆の恋人"
        case 701...1000: return "心の繋がった恋人"
        case 1001...1300: return "運命の恋人"
        case 1301...1600: return "唯一無二の存在"
        case 1601...2000: return "魂の伴侶"
        case 2001...2500: return "永遠の約束"
        case 2501...3000: return "運命共同体"
        case 3001...3500: return "一心同体"
        case 3501...4000: return "奇跡の絆"
        case 4001...4500: return "神聖な愛"
        case 4501...5000: return "究極の愛"
        default: return "無限の愛"
        }
    }
    
    // 親密度レベルの段階を取得
    var intimacyStage: IntimacyStage {
        switch intimacyLevel {
        case 0...100: return .bestFriend
        case 101...200: return .specialFriend
        case 201...300: return .loveCandidate
        case 301...500: return .lover
        case 501...700: return .deepBondLover
        case 701...1000: return .soulConnectedLover
        case 1001...1300: return .destinyLover
        case 1301...1600: return .uniqueExistence
        case 1601...2000: return .soulmate
        case 2001...2500: return .eternalPromise
        case 2501...3000: return .destinyPartner
        case 3001...3500: return .oneHeart
        case 3501...4000: return .miracleBond
        case 4001...4500: return .sacredLove
        case 4501...5000: return .ultimateLove
        default: return .infiniteLove
        }
    }
    
    // レベルアップまでに必要な親密度を計算
    var intimacyToNextLevel: Int {
        let thresholds = [100, 200, 300, 500, 700, 1000, 1300, 1600, 2000, 2500, 3000, 3500, 4000, 4500, 5000]
        for threshold in thresholds {
            if intimacyLevel < threshold {
                return threshold - intimacyLevel
            }
        }
        return 0 // 最高レベル達成
    }
    
    // レベルアップ進捗（0.0-1.0）
    var intimacyProgress: Double {
        let thresholds = [0, 100, 200, 300, 500, 700, 1000, 1300, 1600, 2000, 2500, 3000, 3500, 4000, 4500, 5000]
        
        for i in 0..<thresholds.count-1 {
            if intimacyLevel >= thresholds[i] && intimacyLevel < thresholds[i+1] {
                let current = intimacyLevel - thresholds[i]
                let total = thresholds[i+1] - thresholds[i]
                return Double(current) / Double(total)
            }
        }
        return 1.0 // 最高レベル
    }
    
    // デフォルトイニシャライザー
    init() {
        self.id = UUID().uuidString
        self.name = "あい"
        self.personality = "優しくて思いやりがある"
        self.speakingStyle = "丁寧で温かい"
        self.intimacyLevel = 0
        self.birthday = nil
        self.anniversaryDate = nil
        self.iconURL = nil
        self.iconName = "person.circle.fill"
        self.backgroundName = "defaultBG"
        self.backgroundURL = nil
        self.totalDateCount = 0
        self.unlockedInfiniteMode = false
    }
    
    // カスタムイニシャライザー
    init(name: String, personality: String, speakingStyle: String, iconName: String, backgroundName: String,
         backgroundURL: String? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.personality = personality
        self.speakingStyle = speakingStyle
        self.intimacyLevel = 0
        self.birthday = nil
        self.anniversaryDate = nil
        self.iconURL = nil
        self.iconName = iconName
        self.backgroundName = backgroundName
        self.backgroundURL = backgroundURL
        self.totalDateCount = 0
        self.unlockedInfiniteMode = false
    }
    
    // Codable用のCodingKeys
    enum CodingKeys: String, CodingKey {
        case id, name, personality, speakingStyle, intimacyLevel, birthday, anniversaryDate
        case iconURL, iconName, backgroundName, backgroundURL, totalDateCount, unlockedInfiniteMode
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        personality = try container.decode(String.self, forKey: .personality)
        speakingStyle = try container.decode(String.self, forKey: .speakingStyle)
        intimacyLevel = try container.decode(Int.self, forKey: .intimacyLevel)
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)
        anniversaryDate = try container.decodeIfPresent(Date.self, forKey: .anniversaryDate)
        iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "person.circle.fill"
        backgroundName = try container.decodeIfPresent(String.self, forKey: .backgroundName) ?? "defaultBG"
        backgroundURL = try container.decodeIfPresent(String.self, forKey: .backgroundURL)
        totalDateCount = try container.decodeIfPresent(Int.self, forKey: .totalDateCount) ?? 0
        unlockedInfiniteMode = try container.decodeIfPresent(Bool.self, forKey: .unlockedInfiniteMode) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(personality, forKey: .personality)
        try container.encode(speakingStyle, forKey: .speakingStyle)
        try container.encode(intimacyLevel, forKey: .intimacyLevel)
        try container.encodeIfPresent(birthday, forKey: .birthday)
        try container.encodeIfPresent(anniversaryDate, forKey: .anniversaryDate)
        try container.encodeIfPresent(iconURL, forKey: .iconURL)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(backgroundName, forKey: .backgroundName)
        try container.encodeIfPresent(backgroundURL, forKey: .backgroundURL)
        try container.encode(totalDateCount, forKey: .totalDateCount)
        try container.encode(unlockedInfiniteMode, forKey: .unlockedInfiniteMode)
    }
}

// 🌟 親密度段階の列挙型
enum IntimacyStage: String, CaseIterable {
    case bestFriend = "bestFriend"
    case specialFriend = "specialFriend"
    case loveCandidate = "loveCandidate"
    case lover = "lover"
    case deepBondLover = "deepBondLover"
    case soulConnectedLover = "soulConnectedLover"
    case destinyLover = "destinyLover"
    case uniqueExistence = "uniqueExistence"
    case soulmate = "soulmate"
    case eternalPromise = "eternalPromise"
    case destinyPartner = "destinyPartner"
    case oneHeart = "oneHeart"
    case miracleBond = "miracleBond"
    case sacredLove = "sacredLove"
    case ultimateLove = "ultimateLove"
    case infiniteLove = "infiniteLove"
    
    var displayName: String {
        switch self {
        case .bestFriend: return "親友"
        case .specialFriend: return "特別な友達"
        case .loveCandidate: return "恋人候補"
        case .lover: return "恋人"
        case .deepBondLover: return "深い絆の恋人"
        case .soulConnectedLover: return "心の繋がった恋人"
        case .destinyLover: return "運命の恋人"
        case .uniqueExistence: return "唯一無二の存在"
        case .soulmate: return "魂の伴侶"
        case .eternalPromise: return "永遠の約束"
        case .destinyPartner: return "運命共同体"
        case .oneHeart: return "一心同体"
        case .miracleBond: return "奇跡の絆"
        case .sacredLove: return "神聖な愛"
        case .ultimateLove: return "究極の愛"
        case .infiniteLove: return "無限の愛"
        }
    }
    
    var color: Color {
        switch self {
        case .bestFriend: return .blue
        case .specialFriend: return .cyan
        case .loveCandidate: return .green
        case .lover: return .pink
        case .deepBondLover: return .red
        case .soulConnectedLover: return .purple
        case .destinyLover: return .orange
        case .uniqueExistence: return .yellow
        case .soulmate: return .indigo
        case .eternalPromise: return Color(.systemTeal)
        case .destinyPartner: return Color(.systemMint)
        case .oneHeart: return Color(.systemPurple)
        case .miracleBond: return Color(.systemPink)
        case .sacredLove: return Color(.systemOrange)
        case .ultimateLove: return Color(.systemRed)
        case .infiniteLove: return Color.primary
        }
    }
    
    var icon: String {
        switch self {
        case .bestFriend: return "person.2.fill"
        case .specialFriend: return "star.fill"
        case .loveCandidate: return "heart"
        case .lover: return "heart.fill"
        case .deepBondLover: return "heart.circle.fill"
        case .soulConnectedLover: return "heart.text.square.fill"
        case .destinyLover: return "infinity"
        case .uniqueExistence: return "diamond.fill"
        case .soulmate: return "moon.stars.fill"
        case .eternalPromise: return "rings.fill"
        case .destinyPartner: return "link"
        case .oneHeart: return "heart.2.fill"
        case .miracleBond: return "sparkles"
        case .sacredLove: return "crown.fill"
        case .ultimateLove: return "flame.fill"
        case .infiniteLove: return "infinity.circle.fill"
        }
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    let text: String
    let isFromUser: Bool
    let timestamp: Date
    let dateLocation: String?
    let intimacyGained: Int // メッセージで獲得した親密度
    
    init(text: String, isFromUser: Bool, timestamp: Date, dateLocation: String?, intimacyGained: Int = 0) {
        self.id = UUID()
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.dateLocation = dateLocation
        self.intimacyGained = intimacyGained
    }
    
    init(id: UUID, text: String, isFromUser: Bool, timestamp: Date, dateLocation: String?, intimacyGained: Int = 0) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.dateLocation = dateLocation
        self.intimacyGained = intimacyGained
    }
}

struct DateSession {
    let location: DateLocation
    let startTime: Date
    var messagesExchanged: Int = 0
    var intimacyGained: Int = 0
    let characterName: String
    
    init(location: DateLocation, startTime: Date, characterName: String) {
        self.location = location
        self.startTime = startTime
        self.characterName = characterName
        self.messagesExchanged = 0
        self.intimacyGained = 0
    }
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

// MARK: - DateLocation Extensions for Messages

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
        case .spiritual:
            return "\(baseMessage) \(description) ✨ 神秘的なエネルギーを感じますね💫"
        case .luxury:
            return "\(baseMessage) \(description) 👑 贅沢な時間を過ごしましょう✨"
        case .adventure:
            return "\(baseMessage) \(description) 🏔️ 冒険の始まりです！"
        case .romantic:
            return "\(baseMessage) \(description) 💕 ロマンチックな時間をお楽しみください✨"
        case .infinite:
            return "\(baseMessage) 🌌 無限の愛が生み出した奇跡のデートスポットです！想像を超えた体験をしましょう♾️✨"
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
        case .spiritual:
            return "\(name)での\(baseMessage)過ごせて神秘的でした ✨ 魂の繋がりを感じました💫"
        case .luxury:
            return "\(name)での\(baseMessage)過ごせて贅沢でした 👑 特別な時間をありがとう✨"
        case .adventure:
            return "\(name)での\(baseMessage)過ごせて冒険的でした！🏔️ また一緒に新しい挑戦をしましょう！"
        case .romantic:
            return "\(name)での\(baseMessage)過ごせてロマンチックでした 💕 愛が深まりました✨"
        case .infinite:
            return "\(name)での\(baseMessage)過ごせて無限に幸せでした 🌌 私たちの愛は本当に無限大ですね♾️✨"
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
        case .spiritual:
            messages = [
                "ここのエネルギー、とても神秘的ですね ✨",
                "魂が浄化されるような気がします 💫",
                "あなたと一緒だと、スピリチュアルな繋がりを感じます"
            ]
        case .luxury:
            messages = [
                "こんな贅沢な時間、夢のようです 👑",
                "特別な空間で過ごす時間は格別ですね ✨",
                "あなたとの時間は、どんな高級な場所よりも価値があります"
            ]
        case .adventure:
            messages = [
                "一緒に冒険すると、何倍も楽しいですね！🏔️",
                "新しい体験を共有できて嬉しいです",
                "あなたとなら、どんな冒険も怖くありません"
            ]
        case .romantic:
            messages = [
                "こんなにロマンチックな時間... 💕",
                "愛が深まっていくのを感じます ✨",
                "あなたといると、毎日がロマンス映画のようです"
            ]
        case .infinite:
            messages = [
                "無限の可能性を感じます... 🌌",
                "私たちの愛は本当に無限大ですね ♾️",
                "想像を超えた美しさ... あなたと一緒だからこそ ✨"
            ]
        default:
            return nil
        }
        
        return messages.randomElement()
    }
}
