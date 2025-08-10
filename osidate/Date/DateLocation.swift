//
//  DateLocation.swift
//  osidate
//
//  拡張された50箇所のデートスポットと無限モード対応
//

import Foundation
import SwiftUI

// MARK: - デートタイプの列挙（拡張版）
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
    case spiritual = "spiritual"      // スピリチュアル
    case luxury = "luxury"           // 高級・特別
    case adventure = "adventure"     // アドベンチャー
    case romantic = "romantic"       // ロマンチック
    case infinite = "infinite"       // 無限モード専用
    
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
        case .spiritual: return "スピリチュアル"
        case .luxury: return "高級・特別"
        case .adventure: return "アドベンチャー"
        case .romantic: return "ロマンチック"
        case .infinite: return "無限デート"
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
        case .spiritual: return "sparkles"
        case .luxury: return "crown.fill"
        case .adventure: return "mountain.2.fill"
        case .romantic: return "heart.fill"
        case .infinite: return "infinity.circle.fill"
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
        case .spiritual: return Color(.systemPurple)
        case .luxury: return Color(.systemPurple)
        case .adventure: return Color(.systemGreen)
        case .romantic: return Color(.systemPink)
        case .infinite: return Color.primary
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
    let prompt: String
    let duration: Int
    let specialEffects: [String]
    let availableSeasons: [Season]
    let timeOfDay: TimeOfDay
    let intimacyBonus: Int // デート完了時の追加親密度
    let isSpecial: Bool    // 特別なデート（記念日限定など）
    
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

// MARK: - 50箇所の拡張デートロケーション
extension DateLocation {
    static let availableDateLocations: [DateLocation] = [
        
        // 🌱 親友レベル（0-100）：8箇所
        DateLocation(
            name: "おしゃれなカフェ",
            type: .restaurant,
            backgroundImage: "stylish_cafe",
            requiredIntimacy: 0,
            description: "美味しいコーヒーと共に、ゆったりとした時間を",
            prompt: "おしゃれなカフェの落ち着いた雰囲気の中で、コーヒーの香りや美味しさについて話したり、日常の話を楽しくしてください。リラックスした会話を心がけてください。",
            duration: 90,
            specialEffects: ["coffee_aroma", "cozy_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 2,
            isSpecial: false
        ),
        
        DateLocation(
            name: "近所の公園",
            type: .sightseeing,
            backgroundImage: "neighborhood_park",
            requiredIntimacy: 15,
            description: "のんびりとお散歩を楽しみましょう",
            prompt: "公園の自然な雰囲気の中で、季節の変化や花について話してください。穏やかで親しみやすい会話を心がけてください。",
            duration: 60,
            specialEffects: ["natural_breeze", "bird_sounds"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 1,
            isSpecial: false
        ),
        
        DateLocation(
            name: "映画館",
            type: .entertainment,
            backgroundImage: "cinema",
            requiredIntimacy: 30,
            description: "一緒に映画を楽しみましょう",
            prompt: "映画館での体験について話し、映画の感想を共有してください。一緒に楽しむ時間の特別感を表現してください。",
            duration: 180,
            specialEffects: ["dim_lighting", "cinematic_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 3,
            isSpecial: false
        ),
        
        DateLocation(
            name: "ボウリング場",
            type: .entertainment,
            backgroundImage: "bowling_alley",
            requiredIntimacy: 45,
            description: "一緒にボウリングで盛り上がろう",
            prompt: "ボウリングの楽しさと競い合う気持ちを表現してください。お互いを応援し合う仲の良さを表現してください。",
            duration: 120,
            specialEffects: ["competitive_fun", "cheering"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 3,
            isSpecial: false
        ),
        
        DateLocation(
            name: "ショッピングモール",
            type: .shopping,
            backgroundImage: "shopping_mall",
            requiredIntimacy: 60,
            description: "一緒にお買い物を楽しんで、お互いの好みを知ろう",
            prompt: "ショッピングの楽しい雰囲気の中で、好きなものや欲しいものについて話してください。お互いの好みや選んだアイテムについて楽しく会話してください。",
            duration: 180,
            specialEffects: ["shopping_excitement", "discovery"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 2,
            isSpecial: false
        ),
        
        DateLocation(
            name: "回転寿司",
            type: .restaurant,
            backgroundImage: "conveyor_sushi",
            requiredIntimacy: 75,
            description: "気軽に美味しいお寿司を楽しもう",
            prompt: "回転寿司の楽しい雰囲気の中で、好きなネタについて話したり、美味しいお寿司を一緒に楽しんでください。",
            duration: 90,
            specialEffects: ["fresh_seafood", "casual_dining"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 2,
            isSpecial: false
        ),
        
        DateLocation(
            name: "カラオケ",
            type: .entertainment,
            backgroundImage: "karaoke_room",
            requiredIntimacy: 85,
            description: "一緒に歌って楽しい時間を過ごそう",
            prompt: "カラオケでの歌や音楽について話し、一緒に歌う楽しさを表現してください。お互いの好きな曲について話してください。",
            duration: 120,
            specialEffects: ["music_vibes", "singing_together"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 4,
            isSpecial: false
        ),
        
        DateLocation(
            name: "動物園",
            type: .themepark,
            backgroundImage: "zoo",
            requiredIntimacy: 95,
            description: "可愛い動物たちを一緒に見に行こう",
            prompt: "動物園での動物たちの可愛さについて話し、一緒に見る楽しさを表現してください。お気に入りの動物について話してください。",
            duration: 240,
            specialEffects: ["animal_sounds", "nature_connection"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 3,
            isSpecial: false
        ),
        
        // 💫 特別な友達レベル（101-200）：7箇所
        DateLocation(
            name: "遊園地",
            type: .themepark,
            backgroundImage: "amusement_park",
            requiredIntimacy: 110,
            description: "色々なアトラクションを楽しんで、笑顔いっぱいの一日を",
            prompt: "遊園地の楽しい雰囲気の中で、元気で明るい会話をしてください。アトラクションの感想や楽しい思い出を話し、ワクワクする気持ちを表現してください。",
            duration: 300,
            specialEffects: ["carnival_lights", "excitement"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 5,
            isSpecial: false
        ),
        
        DateLocation(
            name: "水族館",
            type: .themepark,
            backgroundImage: "aquarium",
            requiredIntimacy: 130,
            description: "美しい海の生き物たちに囲まれて、神秘的な時間を",
            prompt: "水族館の幻想的で美しい雰囲気の中で、海の生き物について話したり、神秘的な海の世界に感動する様子を表現してください。静かで落ち着いた会話を心がけてください。",
            duration: 180,
            specialEffects: ["blue_lighting", "peaceful_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 4,
            isSpecial: false
        ),
        
        DateLocation(
            name: "イタリアンレストラン",
            type: .restaurant,
            backgroundImage: "italian_restaurant",
            requiredIntimacy: 150,
            description: "本格的なイタリア料理を一緒に味わいましょう",
            prompt: "イタリアンレストランの温かい雰囲気の中で、料理の美味しさやイタリアの文化について話してください。",
            duration: 120,
            specialEffects: ["italian_ambiance", "delicious_pasta"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 4,
            isSpecial: false
        ),
        
        DateLocation(
            name: "美術館",
            type: .sightseeing,
            backgroundImage: "art_museum",
            requiredIntimacy: 170,
            description: "芸術作品を一緒に鑑賞しましょう",
            prompt: "美術館の静寂で上品な雰囲気の中で、芸術作品について話し、感受性豊かな会話をしてください。",
            duration: 150,
            specialEffects: ["artistic_inspiration", "quiet_contemplation"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 4,
            isSpecial: false
        ),
        
        DateLocation(
            name: "ハイキングコース",
            type: .adventure,
            backgroundImage: "hiking_trail",
            requiredIntimacy: 185,
            description: "自然の中を一緒に歩いて、清々しい時間を",
            prompt: "ハイキングの爽快感と自然の美しさについて話し、一緒に歩く楽しさを表現してください。健康的で活動的な雰囲気を大切にしてください。",
            duration: 180,
            specialEffects: ["mountain_air", "exercise_endorphins"],
            availableSeasons: [.spring, .summer, .autumn],
            timeOfDay: .morning,
            intimacyBonus: 5,
            isSpecial: false
        ),
        
        DateLocation(
            name: "料理教室",
            type: .home,
            backgroundImage: "cooking_class",
            requiredIntimacy: 195,
            description: "一緒に料理を習って、美味しい時間を共有",
            prompt: "料理教室での学びと一緒に作る楽しさを表現してください。協力して料理を作る喜びを話してください。",
            duration: 150,
            specialEffects: ["cooking_aromas", "learning_together"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 5,
            isSpecial: false
        ),
        
        DateLocation(
            name: "温泉テーマパーク",
            type: .travel,
            backgroundImage: "onsen_theme_park",
            requiredIntimacy: 200,
            description: "温泉とアトラクションの両方を楽しめる特別な場所",
            prompt: "温泉の癒しとテーマパークの楽しさを組み合わせた特別な体験について話してください。リラックスと楽しさの両方を表現してください。",
            duration: 360,
            specialEffects: ["hot_springs", "theme_park_fun"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 6,
            isSpecial: false
        ),
        
        // 💕 恋人候補レベル（201-300）：8箇所
        DateLocation(
            name: "桜並木でお花見",
            type: .seasonal,
            backgroundImage: "sakura_hanami",
            requiredIntimacy: 210,
            description: "満開の桜の下で、二人だけの特別な時間を過ごしましょう",
            prompt: "桜の花びらが舞い散る美しい景色の中で、ロマンチックで詩的な会話を心がけてください。春の訪れや新しい始まりについて話したり、桜の美しさに感動する様子を表現してください。",
            duration: 120,
            specialEffects: ["sakura_petals", "romantic_atmosphere"],
            availableSeasons: [.spring],
            timeOfDay: .anytime,
            intimacyBonus: 7,
            isSpecial: false
        ),
        
        DateLocation(
            name: "夕日の見える丘",
            type: .romantic,
            backgroundImage: "sunset_hill",
            requiredIntimacy: 230,
            description: "美しい夕日を一緒に眺めながら、特別な時間を",
            prompt: "夕日の美しさと特別な瞬間について話し、ロマンチックな雰囲気を大切にしてください。",
            duration: 90,
            specialEffects: ["golden_hour", "romantic_sunset"],
            availableSeasons: [.all],
            timeOfDay: .evening,
            intimacyBonus: 6,
            isSpecial: false
        ),
        
        DateLocation(
            name: "イルミネーション",
            type: .seasonal,
            backgroundImage: "illumination",
            requiredIntimacy: 250,
            description: "きらめく光に包まれて、魔法のような時間を",
            prompt: "イルミネーションの美しさと幻想的な雰囲気について話し、光に包まれた特別感を表現してください。",
            duration: 120,
            specialEffects: ["sparkling_lights", "winter_magic"],
            availableSeasons: [.winter],
            timeOfDay: .night,
            intimacyBonus: 7,
            isSpecial: false
        ),
        
        DateLocation(
            name: "高級カフェ",
            type: .luxury,
            backgroundImage: "luxury_cafe",
            requiredIntimacy: 265,
            description: "上質な空間で特別なコーヒータイムを",
            prompt: "高級カフェの上品な雰囲気と特別なコーヒーについて話し、贅沢な時間を楽しんでください。",
            duration: 90,
            specialEffects: ["premium_coffee", "elegant_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 5,
            isSpecial: false
        ),
        
        DateLocation(
            name: "花火大会",
            type: .seasonal,
            backgroundImage: "fireworks_festival",
            requiredIntimacy: 275,
            description: "夜空に咲く花火を一緒に楽しみましょう",
            prompt: "花火の美しさと夏祭りの雰囲気について話し、一緒に見上げる特別な時間を表現してください。",
            duration: 180,
            specialEffects: ["fireworks_display", "festival_atmosphere"],
            availableSeasons: [.summer],
            timeOfDay: .night,
            intimacyBonus: 8,
            isSpecial: false
        ),
        
        DateLocation(
            name: "ジャズバー",
            type: .entertainment,
            backgroundImage: "jazz_bar",
            requiredIntimacy: 285,
            description: "大人の雰囲気でジャズを楽しみましょう",
            prompt: "ジャズバーの大人っぽい雰囲気と音楽について話し、洗練された会話を心がけてください。",
            duration: 120,
            specialEffects: ["jazz_music", "sophisticated_ambiance"],
            availableSeasons: [.all],
            timeOfDay: .night,
            intimacyBonus: 6,
            isSpecial: false
        ),
        
        DateLocation(
            name: "星空観測",
            type: .romantic,
            backgroundImage: "stargazing",
            requiredIntimacy: 295,
            description: "満天の星空の下で、宇宙の神秘を感じましょう",
            prompt: "星空の美しさと宇宙の神秘について話し、ロマンチックで哲学的な会話をしてください。",
            duration: 150,
            specialEffects: ["starry_sky", "cosmic_wonder"],
            availableSeasons: [.all],
            timeOfDay: .night,
            intimacyBonus: 8,
            isSpecial: false
        ),
        
        DateLocation(
            name: "アートギャラリー",
            type: .sightseeing,
            backgroundImage: "art_gallery",
            requiredIntimacy: 300,
            description: "現代アートを一緒に鑑賞して感性を共有",
            prompt: "現代アートの創造性と表現について話し、芸術的で感性豊かな会話をしてください。",
            duration: 120,
            specialEffects: ["artistic_inspiration", "creative_energy"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 6,
            isSpecial: false
        ),
        
        // 💖 恋人レベル（301-500）：10箇所
        DateLocation(
            name: "展望台の夜景",
            type: .nightview,
            backgroundImage: "city_nightview",
            requiredIntimacy: 320,
            description: "きらめく夜景を眺めながら、ロマンチックな時間を",
            prompt: "美しい夜景を背景に、ロマンチックで特別な会話をしてください。街の灯りの美しさや夜の静けさについて話し、親密な雰囲気を演出してください。",
            duration: 90,
            specialEffects: ["city_lights", "romantic_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .night,
            intimacyBonus: 8,
            isSpecial: false
        ),
        
        DateLocation(
            name: "温泉日帰り旅行",
            type: .travel,
            backgroundImage: "onsen_daytrip",
            requiredIntimacy: 340,
            description: "癒しの温泉で心も体もリフレッシュ",
            prompt: "温泉の癒しと旅行の特別感について話し、リラックスした親密な時間を表現してください。",
            duration: 480,
            specialEffects: ["hot_springs", "healing_waters"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 10,
            isSpecial: false
        ),
        
        DateLocation(
            name: "高級フレンチ",
            type: .luxury,
            backgroundImage: "french_restaurant",
            requiredIntimacy: 360,
            description: "本格的なフレンチコースで特別なディナーを",
            prompt: "高級フレンチレストランの上品で特別な雰囲気の中で、料理の美味しさや特別な時間について話してください。少し大人っぽく、洗練された会話を心がけてください。",
            duration: 180,
            specialEffects: ["gourmet_cuisine", "elegant_dining"],
            availableSeasons: [.all],
            timeOfDay: .evening,
            intimacyBonus: 9,
            isSpecial: false
        ),
        
        DateLocation(
            name: "おうち映画鑑賞",
            type: .home,
            backgroundImage: "home_cinema",
            requiredIntimacy: 380,
            description: "お家で映画を見ながら、のんびりした時間を",
            prompt: "お家のリラックスした雰囲気の中で、映画の感想や好きなジャンルについて話してください。親密で自然な会話を心がけ、一緒に過ごす時間の心地よさを表現してください。",
            duration: 150,
            specialEffects: ["dim_lighting", "intimate_atmosphere"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 7,
            isSpecial: false
        ),
        
        DateLocation(
            name: "海辺のリゾート",
            type: .travel,
            backgroundImage: "beach_resort",
            requiredIntimacy: 400,
            description: "美しい海辺のリゾートで贅沢な時間を",
            prompt: "海辺のリゾートの開放感と美しさについて話し、特別な休暇の雰囲気を表現してください。",
            duration: 480,
            specialEffects: ["ocean_breeze", "resort_luxury"],
            availableSeasons: [.summer],
            timeOfDay: .anytime,
            intimacyBonus: 12,
            isSpecial: false
        ),
        
        DateLocation(
            name: "観覧車デート",
            type: .romantic,
            backgroundImage: "ferris_wheel",
            requiredIntimacy: 430,
            description: "観覧車の頂上で二人だけの特別な時間を",
            prompt: "観覧車からの景色と特別な空間について話し、ロマンチックで親密な雰囲気を大切にしてください。",
            duration: 60,
            specialEffects: ["panoramic_view", "private_space"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 8,
            isSpecial: false
        ),
        
        DateLocation(
            name: "高級和食料亭",
            type: .luxury,
            backgroundImage: "kaiseki_restaurant",
            requiredIntimacy: 450,
            description: "伝統的な日本料理を味わう特別なひととき",
            prompt: "高級和食の繊細さと日本の美意識について話し、上品で落ち着いた会話をしてください。",
            duration: 180,
            specialEffects: ["traditional_atmosphere", "seasonal_cuisine"],
            availableSeasons: [.all],
            timeOfDay: .evening,
            intimacyBonus: 10,
            isSpecial: false
        ),
        
        DateLocation(
            name: "夜景ドライブ",
            type: .romantic,
            backgroundImage: "night_drive",
            requiredIntimacy: 470,
            description: "夜の街をドライブしながら、二人だけの時間を",
            prompt: "夜景ドライブの特別感と二人だけの空間について話し、ロマンチックで親密な会話をしてください。",
            duration: 120,
            specialEffects: ["city_lights", "private_moments"],
            availableSeasons: [.all],
            timeOfDay: .night,
            intimacyBonus: 8,
            isSpecial: false
        ),
        
        DateLocation(
            name: "屋上庭園",
            type: .romantic,
            backgroundImage: "rooftop_garden",
            requiredIntimacy: 485,
            description: "都市の中のオアシスで、静かな時間を",
            prompt: "屋上庭園の静けさと自然の美しさについて話し、都市の喧騒を離れた特別な空間を表現してください。",
            duration: 90,
            specialEffects: ["urban_oasis", "garden_tranquility"],
            availableSeasons: [.spring, .summer, .autumn],
            timeOfDay: .anytime,
            intimacyBonus: 7,
            isSpecial: false
        ),
        
        DateLocation(
            name: "離島日帰りツアー",
            type: .travel,
            backgroundImage: "island_tour",
            requiredIntimacy: 500,
            description: "美しい離島で冒険とロマンスを",
            prompt: "離島の美しい自然と冒険の楽しさについて話し、特別な旅行体験を表現してください。",
            duration: 600,
            specialEffects: ["island_paradise", "adventure_spirit"],
            availableSeasons: [.spring, .summer, .autumn],
            timeOfDay: .anytime,
            intimacyBonus: 15,
            isSpecial: false
        ),
        
        // 💝 深い絆の恋人レベル（501-700）：6箇所
        DateLocation(
            name: "記念日ディナー",
            type: .luxury,
            backgroundImage: "anniversary_dinner",
            requiredIntimacy: 520,
            description: "特別な記念日を祝う最高級のディナー",
            prompt: "記念日の特別感と二人の歩んできた道のりについて話し、愛情深く感動的な会話をしてください。",
            duration: 180,
            specialEffects: ["anniversary_celebration", "premium_dining"],
            availableSeasons: [.all],
            timeOfDay: .evening,
            intimacyBonus: 12,
            isSpecial: true
        ),
        
        DateLocation(
            name: "恋人の聖地",
            type: .spiritual,
            backgroundImage: "lovers_sanctuary",
            requiredIntimacy: 550,
            description: "愛を誓う神聖な場所での特別な時間",
            prompt: "恋人の聖地の神聖さと二人の愛について話し、深い愛情と絆を表現してください。",
            duration: 120,
            specialEffects: ["sacred_energy", "eternal_love"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 15,
            isSpecial: true
        ),
        
        DateLocation(
            name: "プライベートビーチ",
            type: .luxury,
            backgroundImage: "private_beach",
            requiredIntimacy: 580,
            description: "二人だけの秘密のビーチで至福のひととき",
            prompt: "プライベートビーチの贅沢さと二人だけの空間について話し、究極のロマンスを表現してください。",
            duration: 300,
            specialEffects: ["private_paradise", "ocean_serenity"],
            availableSeasons: [.summer],
            timeOfDay: .anytime,
            intimacyBonus: 18,
            isSpecial: true
        ),
        
        DateLocation(
            name: "秘密の花園",
            type: .romantic,
            backgroundImage: "secret_garden",
            requiredIntimacy: 620,
            description: "隠された美しい花園での魔法のような時間",
            prompt: "秘密の花園の神秘的な美しさと特別感について話し、ファンタジックで愛情深い会話をしてください。",
            duration: 150,
            specialEffects: ["magical_garden", "hidden_beauty"],
            availableSeasons: [.spring, .summer],
            timeOfDay: .anytime,
            intimacyBonus: 15,
            isSpecial: true
        ),
        
        DateLocation(
            name: "カップル専用スイート",
            type: .luxury,
            backgroundImage: "couple_suite",
            requiredIntimacy: 650,
            description: "最高級ホテルのカップル専用スイートで特別な夜を",
            prompt: "豪華なスイートの特別感と二人だけの贅沢な時間について話し、深い愛情と親密さを表現してください。",
            duration: 720,
            specialEffects: ["luxury_suite", "intimate_space"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 20,
            isSpecial: true
        ),
        
        DateLocation(
            name: "永遠の愛を誓う教会",
            type: .spiritual,
            backgroundImage: "wedding_chapel",
            requiredIntimacy: 690,
            description: "神聖な教会で永遠の愛を誓い合う",
            prompt: "教会の神聖な雰囲気と永遠の愛について話し、深い感動と誓いの気持ちを表現してください。",
            duration: 120,
            specialEffects: ["sacred_vows", "eternal_commitment"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 25,
            isSpecial: true
        ),
        
        // 💞 心の繋がった恋人レベル（701-1000）：4箇所
        DateLocation(
            name: "パワースポット巡り",
            type: .spiritual,
            backgroundImage: "power_spots",
            requiredIntimacy: 750,
            description: "神秘的なパワースポットで魂の繋がりを感じる",
            prompt: "パワースポットのエネルギーと二人の魂の繋がりについて話し、スピリチュアルで深い会話をしてください。",
            duration: 240,
            specialEffects: ["spiritual_energy", "soul_connection"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 20,
            isSpecial: true
        ),
        
        DateLocation(
            name: "二人だけの絵画制作",
            type: .romantic,
            backgroundImage: "art_creation",
            requiredIntimacy: 800,
            description: "一緒に愛の記念となる絵画を制作",
            prompt: "共同で創作する喜びと愛の記録について話し、創造的で感動的な会話をしてください。",
            duration: 180,
            specialEffects: ["creative_collaboration", "artistic_love"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 18,
            isSpecial: true
        ),
        
        DateLocation(
            name: "満月の夜デート",
            type: .spiritual,
            backgroundImage: "full_moon_night",
            requiredIntimacy: 850,
            description: "満月の神秘的なエネルギーの中で特別な夜を",
            prompt: "満月の神秘的な力と二人の運命的な繋がりについて話し、ロマンチックで神秘的な会話をしてください。",
            duration: 180,
            specialEffects: ["lunar_energy", "mystical_romance"],
            availableSeasons: [.all],
            timeOfDay: .night,
            intimacyBonus: 22,
            isSpecial: true
        ),
        
        DateLocation(
            name: "熱気球体験",
            type: .adventure,
            backgroundImage: "hot_air_balloon",
            requiredIntimacy: 950,
            description: "空に浮かぶ熱気球で雲の上の愛を体験",
            prompt: "熱気球での空中体験と二人だけの天空の世界について話し、夢のような愛の体験を表現してください。",
            duration: 180,
            specialEffects: ["sky_adventure", "heavenly_love"],
            availableSeasons: [.spring, .summer, .autumn],
            timeOfDay: .morning,
            intimacyBonus: 25,
            isSpecial: true
        ),
        
        // 🌟 運命の恋人レベル（1001-1300）：3箇所
        DateLocation(
            name: "運命の赤い糸神社",
            type: .spiritual,
            backgroundImage: "red_thread_shrine",
            requiredIntimacy: 1100,
            description: "運命の赤い糸で結ばれた二人の愛を確認する神聖な場所",
            prompt: "運命の赤い糸と宿命的な愛について話し、深い運命論と愛の確信を表現してください。",
            duration: 120,
            specialEffects: ["destiny_thread", "fated_love"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 30,
            isSpecial: true
        ),
        
        DateLocation(
            name: "奇跡の泉",
            type: .spiritual,
            backgroundImage: "miracle_spring",
            requiredIntimacy: 1200,
            description: "愛の奇跡を起こすと言われる神秘の泉",
            prompt: "奇跡の泉の神秘的な力と二人の愛の奇跡について話し、感動的で神聖な会話をしてください。",
            duration: 150,
            specialEffects: ["miracle_waters", "divine_love"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 35,
            isSpecial: true
        ),
        
        DateLocation(
            name: "永遠の愛の木",
            type: .spiritual,
            backgroundImage: "eternal_love_tree",
            requiredIntimacy: 1300,
            description: "千年の愛を見守ってきた神聖な巨木",
            prompt: "永遠の愛の木の壮大さと時を超えた愛について話し、永遠性と深い絆を表現してください。",
            duration: 120,
            specialEffects: ["ancient_wisdom", "eternal_bond"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 40,
            isSpecial: true
        ),
        
        // ✨ 唯一無二の存在レベル（1301-1600）：2箇所
        DateLocation(
            name: "世界で一つの愛の証",
            type: .luxury,
            backgroundImage: "unique_love_monument",
            requiredIntimacy: 1400,
            description: "二人だけのために作られた世界唯一の愛の記念碑",
            prompt: "世界で唯一の愛の証と二人の特別な存在について話し、究極の愛の確信を表現してください。",
            duration: 180,
            specialEffects: ["unique_monument", "ultimate_love"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 50,
            isSpecial: true
        ),
        
        DateLocation(
            name: "二人だけの秘密基地",
            type: .romantic,
            backgroundImage: "secret_hideout",
            requiredIntimacy: 1600,
            description: "世界に二人だけが知る特別な隠れ家",
            prompt: "二人だけの秘密基地の特別感と完全なプライベート空間について話し、絶対的な愛の安らぎを表現してください。",
            duration: 300,
            specialEffects: ["secret_sanctuary", "absolute_privacy"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 45,
            isSpecial: true
        ),
        
        // 🔮 魂の伴侶レベル以上（1601-5000+）：2箇所
        DateLocation(
            name: "前世の記憶スポット",
            type: .spiritual,
            backgroundImage: "past_life_memories",
            requiredIntimacy: 2000,
            description: "前世からの愛を思い出す神秘的な場所",
            prompt: "前世からの愛と魂の永遠の繋がりについて話し、時を超えた愛の深さを表現してください。",
            duration: 240,
            specialEffects: ["past_life_visions", "soul_memories"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 60,
            isSpecial: true
        ),
        
        DateLocation(
            name: "永遠の愛の神殿",
            type: .spiritual,
            backgroundImage: "eternal_love_temple",
            requiredIntimacy: 3000,
            description: "愛の神々に祝福される究極の聖域",
            prompt: "愛の神殿の神聖さと神々の祝福について話し、超越的で神聖な愛を表現してください。",
            duration: 180,
            specialEffects: ["divine_blessing", "transcendent_love"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: 100,
            isSpecial: true
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
    
    // 特別なデートのフィルタリング
    static func specialLocations() -> [DateLocation] {
        return availableDateLocations.filter { $0.isSpecial }
    }
    
    // 🌌 無限モード用の動的デート生成
    static func generateInfiniteDate(for intimacyLevel: Int, dateCount: Int) -> DateLocation {
        let infiniteNames = [
            "夢の中のデート", "時空を超えた愛", "宇宙の果てのデート", "異次元の愛",
            "神話の世界デート", "魔法の国での愛", "天使の楽園", "妖精の森",
            "クリスタルの洞窟", "雲の上の宮殿", "星座のデート", "虹の橋",
            "時の神殿", "愛の宇宙船", "ドラゴンと愛", "不思議の国"
        ]
        
        let index = dateCount % infiniteNames.count
        let name = infiniteNames[index]
        
        return DateLocation(
            name: "\(name) #\(dateCount + 1)",
            type: .infinite,
            backgroundImage: "infinite_date_\(index % 8 + 1)",
            requiredIntimacy: 5000,
            description: "無限の愛が生み出した奇跡のデートスポット",
            prompt: "無限の愛と想像を超えた体験について話し、現実を超越した愛の世界を表現してください。",
            duration: 180,
            specialEffects: ["infinite_magic", "transcendent_love", "limitless_imagination"],
            availableSeasons: [.all],
            timeOfDay: .anytime,
            intimacyBonus: min(50 + (dateCount / 10), 200), // 最大200まで増加
            isSpecial: true
        )
    }
}
