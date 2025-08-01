//
//  DataModel.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI

// MARK: - データモデル
struct Character: Codable, Identifiable {
    let id = UUID()
    var name: String
    var personality: String
    var speakingStyle: String
    var iconName: String
    var backgroundName: String
    var intimacyLevel: Int = 0
    var birthday: Date?
    var anniversaryDate: Date?
    
    var intimacyTitle: String {
        switch intimacyLevel {
        case 0...10: return "知り合い"
        case 11...30: return "友達"
        case 31...60: return "親友"
        case 61...100: return "恋人"
        default: return "運命の人"
        }
    }
}

struct Message: Identifiable, Codable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp: Date
    let dateLocation: String?
}

struct DateLocation: Identifiable {
    let id = UUID()
    let name: String
    let backgroundImage: String
    let requiredIntimacy: Int
    let description: String
}
