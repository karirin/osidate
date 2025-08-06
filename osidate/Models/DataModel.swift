//
//  DataModel.swift
//  osidate
//
//  Updated for Firebase integration with image support
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
    
    var intimacyTitle: String {
        switch intimacyLevel {
        case 0...10: return "知り合い"
        case 11...30: return "友達"
        case 31...60: return "親友"
        case 61...100: return "恋人"
        default: return "特別な関係"
        }
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
    }
    
    // Codable用のCodingKeys
    enum CodingKeys: String, CodingKey {
        case id, name, personality, speakingStyle, intimacyLevel, birthday, anniversaryDate, iconURL, iconName, backgroundName, backgroundURL
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
        backgroundURL = try container.decodeIfPresent(String.self,
                                                      forKey: .backgroundURL)
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
        try container.encodeIfPresent(backgroundURL,
                                      forKey: .backgroundURL) 
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    let text: String
    let isFromUser: Bool
    let timestamp: Date
    let dateLocation: String?
    
    init(text: String, isFromUser: Bool, timestamp: Date, dateLocation: String?) {
        self.id = UUID()
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.dateLocation = dateLocation
    }
    
    init(id: UUID, text: String, isFromUser: Bool, timestamp: Date, dateLocation: String?) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.dateLocation = dateLocation
    }
}

//struct DateLocation: Identifiable {
//    let id = UUID()
//    let name: String
//    let backgroundImage: String
//    let requiredIntimacy: Int
//    let description: String
//}
