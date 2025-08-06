//
//  DateLocation.swift
//  osidate
//
//  デートスポットのモデル定義
//

import Foundation
import SwiftUI

// MARK: - デートタイプの列挙
enum DateType: String, CaseIterable, Codable {
    case seasonal = "seasonal"         // 季節・イベント
    case themepark = "themepark"      // テーマパーク
    case restaurant = "restaurant"     // レストラン・カフェ
    case entertainment = "entertainment" // 映画・ライブ
    case sightseeing = "sightseeing"  // 観光
    case shopping = "shopping"         // ショッピング
    case home = "home"                // おうちデート
    case nightview = "nightview"      // 夜景
    case travel = "travel"            // 旅行
    case surprise = "surprise"        // サプライズ
    
    var displayName: String {
        switch self {
        case .seasonal: return "季節・イベント"
        case .themepark: return "テーマパーク"
        case .restaurant: return "レストラン・カフェ"
        case .entertainment: return "映画・ライブ"
        case .sightseeing: return "観光地"
        case .shopping: return "ショッピング"
        case .home: return "おうちデート"
        case .nightview: return "夜景"
        case .travel: return "旅行"
        case .surprise: return "サプライズ"
        }
    }
    
    var icon: String {
        switch self {
        case .seasonal: return "leaf.fill"
        case .themepark: return "flag.fill"
        case .restaurant: return "fork.knife"
        case .entertainment: return "tv.fill"
        case .sightseeing: return "camera.fill"
        case .shopping: return "bag.fill"
        case .home: return "house.fill"
        case .nightview: return "moon.stars.fill"
        case .travel: return "airplane"
        case .surprise: return "gift.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .seasonal: return .green
        case .themepark: return .orange
        case .restaurant: return .brown
        case .entertainment: return .purple
        case .sightseeing: return .blue
        case .shopping: return .pink
        case .home: return .red
        case .nightview: return .indigo
        case .travel: return .cyan
        case .surprise: return .yellow
        }
    }
}

// MARK: - 拡張されたデートロケーション
struct DateLocation: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: DateType
    let backgroundImage: String
    let requiredIntimacy: Int
    let description: String
    let prompt: String           // AIへの特別なプロンプト
    let duration: Int            // デート時間（分）
    let specialEffects: [String] // 特別な効果やイベント
    let availableSeasons: [Season] // 利用可能な季節
    let timeOfDay: TimeOfDay     // 時間帯
    
    enum Season: String, CaseIterable, Codable {
        case spring = "spring"
        case summer = "summer"
        case autumn = "autumn"
        case winter = "winter"
        case all = "all"
        
        var displayName: String {
            switch self {
            case .spring: return "春"
            case .summer: return "夏"
            case .autumn: return "秋"
            case .winter: return "冬"
            case .all: return "通年"
            }
        }
    }
    
    enum TimeOfDay: String, CaseIterable, Codable {
        case morning = "morning"
        case afternoon = "afternoon"
        case evening = "evening"
        case night = "night"
        case anytime = "anytime"
        
        var displayName: String {
            switch self {
            case .morning: return "朝"
            case .afternoon: return "昼"
            case .evening: return "夕方"
            case .night: return "夜"
            case .anytime: return "いつでも"
            }
        }
        
        var icon: String {
            switch self {
            case .morning: return "sunrise.fill"
            case .afternoon: return "sun.max.fill"
            case .evening: return "sunset.fill"
            case .night: return "moon.fill"
            case .anytime: return "clock.fill"
            }
        }
    }
    
    // 現在の季節を取得
    static var currentSeason: Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        case 12, 1, 2: return .winter
        default: return .spring
        }
    }
    
    // 現在の時間帯を取得
    static var currentTimeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<20: return .evening
        case 20...23, 0..<6: return .night
        default: return .anytime
        }
    }
    
    // このデートが現在利用可能かチェック
    var isCurrentlyAvailable: Bool {
        let currentSeason = DateLocation.currentSeason
        return availableSeasons.contains(currentSeason) || availableSeasons.contains(.all)
    }
}

// MARK: - プリセットデートロケーション
extension DateLocation {
    static let availableDateLocations: [DateLocation] = [
        // 季節・イベント
        DateLocation(
            name: "桜並木でお花見",
            type: .seasonal,
            backgroundImage: "sakura_date",
            requiredIntimacy: 0,
            description: "満開の桜の下で、二人だけの特別な時間を過ごしましょう",
            prompt: "桜の花びらが舞い散る美しい景色の中で、ロマンチックで詩的な会話を心がけてください。春の訪れや新しい始まりについて話したり、桜の美しさに感動する様子を表現してください。",
            duration: 120,
            specialEffects: ["sakura_petals", "romantic_atmosphere"],
            availableSeasons: [.spring],
            timeOfDay: .anytime
        ),
        
        DateLocation(
            name: "海辺でサンセット",
            type: .seasonal,
            backgroundImage: "beach_sunset",
            requiredIntimacy: 30,
            description: "夕焼けに染まる海を眺めながら、静かな時間を共有",
            prompt: "夕焼けに染まる美しい海の景色を背景に、ロマンチックで感情的な会話をしてください。波の音や夕日の美しさについて言及し、特別な雰囲気を演出してください。",
            duration: 90,
            specialEffects: ["sunset_glow", "wave_sounds"],
            availableSeasons: [.summer],
            timeOfDay: .evening
        ),
        
        DateLocation(
            name: "紅葉の山道散歩",
            type: .seasonal,
            backgroundImage: "autumn_leaves",
            requiredIntimacy: 20,
            description: "色とりどりの紅葉を楽しみながら、のんびりお散歩",
            prompt: "紅葉で色づいた美しい山道を歩きながら、秋の美しさや季節の移ろいについて話してください。落ち葉を踏む音や涼しい風について言及し、心地よい雰囲気を作ってください。",
            duration: 100,
            specialEffects: ["falling_leaves", "crisp_air"],
            availableSeasons: [.autumn],
            timeOfDay: .afternoon
        ),
        
        DateLocation(
            name: "雪景色の温泉街",
            type: .seasonal,
            backgroundImage: "winter_onsen",
            requiredIntimacy: 60,
            description: "雪化粧した温泉街で、温かい時間を過ごしましょう",
            prompt: "雪が静かに降る温泉街で、温かくて親密な会話をしてください。雪の美しさや温泉の温かさについて話し、冬の特別な雰囲気を演出してください。",
            duration: 150,
            specialEffects: ["snow_falling", "warm_atmosphere"],
            availableSeasons: [.winter],
            timeOfDay: .anytime
        ),
        
        // テーマパーク
        DateLocation(
            name: "遊園地",
            type: .themepark,
            backgroundImage: "amusement_park",
            requiredIntimacy: 25,
            description: "色々なアトラクションを楽しんで、笑顔いっぱいの一日を",
            prompt: "遊園地の楽しい雰囲気の中で、元気で明るい会話をしてください。アトラクションの感想や楽しい思い出を話し、ワクワクする気持ちを表現してください。",
            duration: 300,
            specialEffects: ["carnival_lights", "excitement"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        
        DateLocation(
            name: "水族館",
            type: .themepark,
            backgroundImage: "aquarium",
            requiredIntimacy: 15,
            description: "美しい海の生き物たちに囲まれて、神秘的な時間を",
            prompt: "水族館の幻想的で美しい雰囲気の中で、海の生き物について話したり、神秘的な海の世界に感動する様子を表現してください。静かで落ち着いた会話を心がけてください。",
            duration: 180,
            specialEffects: ["blue_lighting", "peaceful_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        
        // レストラン・カフェ
        DateLocation(
            name: "おしゃれなカフェ",
            type: .restaurant,
            backgroundImage: "stylish_cafe",
            requiredIntimacy: 10,
            description: "美味しいコーヒーと共に、ゆったりとした時間を",
            prompt: "おしゃれなカフェの落ち着いた雰囲気の中で、コーヒーの香りや美味しさについて話したり、日常の話を楽しくしてください。リラックスした会話を心がけてください。",
            duration: 90,
            specialEffects: ["coffee_aroma", "cozy_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        
        DateLocation(
            name: "高級レストラン",
            type: .restaurant,
            backgroundImage: "fancy_restaurant",
            requiredIntimacy: 50,
            description: "特別な日にふさわしい、贅沢なディナータイム",
            prompt: "高級レストランの上品で特別な雰囲気の中で、料理の美味しさや特別な時間について話してください。少し大人っぽく、洗練された会話を心がけてください。",
            duration: 120,
            specialEffects: ["elegant_atmosphere", "romantic_lighting"],
            availableSeasons: [.all],
            timeOfDay: .evening
        ),
        
        // おうちデート
        DateLocation(
            name: "映画鑑賞",
            type: .home,
            backgroundImage: "home_cinema",
            requiredIntimacy: 40,
            description: "お家で映画を見ながら、のんびりした時間を",
            prompt: "お家のリラックスした雰囲気の中で、映画の感想や好きなジャンルについて話してください。親密で自然な会話を心がけ、一緒に過ごす時間の心地よさを表現してください。",
            duration: 150,
            specialEffects: ["dim_lighting", "intimate_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        
        DateLocation(
            name: "お料理作り",
            type: .home,
            backgroundImage: "cooking_together",
            requiredIntimacy: 35,
            description: "一緒にお料理を作って、美味しい時間を共有",
            prompt: "一緒に料理を作る楽しい雰囲気の中で、料理の手順や美味しそうな匂いについて話してください。協力する楽しさや完成した料理への喜びを表現してください。",
            duration: 120,
            specialEffects: ["cooking_sounds", "delicious_aromas"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        ),
        
        // 夜景
        DateLocation(
            name: "展望台の夜景",
            type: .nightview,
            backgroundImage: "city_nightview",
            requiredIntimacy: 45,
            description: "きらめく夜景を眺めながら、ロマンチックな時間を",
            prompt: "美しい夜景を背景に、ロマンチックで特別な会話をしてください。街の灯りの美しさや夜の静けさについて話し、親密な雰囲気を演出してください。",
            duration: 90,
            specialEffects: ["city_lights", "romantic_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .night
        ),
        
        // ショッピング
        DateLocation(
            name: "ショッピングモール",
            type: .shopping,
            backgroundImage: "shopping_mall",
            requiredIntimacy: 20,
            description: "一緒にお買い物を楽しんで、お互いの好みを知ろう",
            prompt: "ショッピングの楽しい雰囲気の中で、好きなものや欲しいものについて話してください。お互いの好みや選んだアイテムについて楽しく会話してください。",
            duration: 180,
            specialEffects: ["shopping_excitement", "discovery"],
            availableSeasons: [.all],
            timeOfDay: .anytime
        )
    ]
    
    // 親密度によるフィルタリング
    static func availableLocations(for intimacyLevel: Int) -> [DateLocation] {
        return availableDateLocations.filter { $0.requiredIntimacy <= intimacyLevel }
    }
    
    // 季節によるフィルタリング
    static func seasonalLocations(for season: Season) -> [DateLocation] {
        return availableDateLocations.filter {
            $0.availableSeasons.contains(season) || $0.availableSeasons.contains(.all)
        }
    }
    
    // タイプによるフィルタリング
    static func locations(of type: DateType) -> [DateLocation] {
        return availableDateLocations.filter { $0.type == type }
    }
}
