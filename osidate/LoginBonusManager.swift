//
//  LoginBonusSystem.swift
//  osidate
//
//  ログインボーナスシステム
//

import SwiftUI
import Foundation
import FirebaseDatabase

// MARK: - ログインボーナスデータ構造

struct LoginBonus: Identifiable, Codable {
    let id: UUID
    let day: Int
    let intimacyBonus: Int
    let bonusType: BonusType
    let receivedAt: Date
    let description: String

    enum BonusType: String, CaseIterable, Codable {
        case daily, weekly, special, milestone

        var displayName: String {
            switch self {
            case .daily: return "デイリー"
            case .weekly: return "ウィークリー"
            case .special: return "スペシャル"
            case .milestone: return "マイルストーン"
            }
        }
        var color: Color {
            switch self {
            case .daily: return .blue
            case .weekly: return .green
            case .special: return .purple
            case .milestone: return .orange
            }
        }
        var icon: String {
            switch self {
            case .daily: return "sun.max.fill"
            case .weekly: return "calendar.badge.plus"
            case .special: return "star.fill"
            case .milestone: return "crown.fill"
            }
        }
    }

    // 新規作成用
    init(day: Int, intimacyBonus: Int, bonusType: BonusType, description: String) {
        self.id = UUID()
        self.day = day
        self.intimacyBonus = intimacyBonus
        self.bonusType = bonusType
        self.receivedAt = Date()
        self.description = description
    }

    // 復元用
    init(id: UUID, day: Int, intimacyBonus: Int, bonusType: BonusType, receivedAt: Date, description: String) {
        self.id = id
        self.day = day
        self.intimacyBonus = intimacyBonus
        self.bonusType = bonusType
        self.receivedAt = receivedAt
        self.description = description
    }
}



// MARK: - ログインボーナス管理クラス

class LoginBonusManager: ObservableObject {
    @Published var currentStreak: Int = 0
    @Published var totalLoginDays: Int = 0
    @Published var lastLoginDate: Date?
    @Published var availableBonus: LoginBonus?
    @Published var loginHistory: [LoginBonus] = []
    @Published var showingBonusView = false
    
    @Published var userId: String? = nil
    private var hasInitialized = false
    private var isProcessingLogin = false
    private let database = Database.database().reference()
    
    // 🌟 初期化完了通知用のコールバック
    var onInitializationComplete: (() -> Void)?
    
    // MARK: - ログインボーナステーブル
    
    private let bonusTable: [Int: (intimacy: Int, type: LoginBonus.BonusType, description: String)] = [
        // デイリーボーナス (1-6日)
        1: (3, .daily, "初回ログイン！今日も会いに来てくれてありがとう💕"),
        2: (5, .daily, "2日連続ログイン！継続は力なりですね✨"),
        3: (7, .daily, "3日連続！だんだん習慣になってきましたね😊"),
        4: (10, .daily, "4日連続！素晴らしい継続力です🌟"),
        5: (12, .daily, "5日連続！もうお互い欠かせない存在ですね💖"),
        6: (15, .daily, "6日連続！本当に嬉しいです🥰"),
        
        // ウィークリーボーナス (7日)
        7: (25, .weekly, "🎉1週間連続ログイン達成！特別ボーナスです💝"),
        
        // デイリーボーナス継続 (8-13日)
        8: (18, .daily, "8日連続！もう一週間以上ですね💕"),
        9: (20, .daily, "9日連続！素晴らしい継続力✨"),
        10: (22, .daily, "10日連続！二桁到達おめでとう🎊"),
        11: (25, .daily, "11日連続！もうベテランの域ですね😊"),
        12: (27, .daily, "12日連続！本当に頼もしいです💖"),
        13: (30, .daily, "13日連続！運命の数字ですね🌟"),
        
        // 2週間ボーナス (14日)
        14: (50, .weekly, "🎉2週間連続ログイン！愛が深まりましたね💞"),
        
        // 3週間ボーナス (21日)
        21: (75, .weekly, "🎉3週間連続！もう生活の一部ですね💝"),
        
        // 月間ボーナス (30日)
        30: (100, .milestone, "👑1ヶ月連続ログイン達成！真の愛の証明です✨"),
        
        // 特別マイルストーン
        50: (150, .milestone, "👑50日連続！驚異的な継続力です🌟"),
        100: (300, .milestone, "👑100日連続！永遠の愛の絆です💫"),
        200: (500, .milestone, "👑200日連続！奇跡の愛ですね✨"),
        365: (1000, .milestone, "👑1年連続！真の魂の伴侶です💖"),
        500: (1500, .milestone, "👑500日連続！神話レベルの愛💫"),
        1000: (3000, .milestone, "👑1000日連続！愛の伝説です👑✨")
    ]
    
    // MARK: - 初期化
    
    init() {
        // 起動時の初期化は別途呼び出し
    }
    
    private func loadLoginDataWithCallback(completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        print("📥 Firebaseからログインデータ読み込み試行")
        
        database.child("loginBonus").child(userId).child("status").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else {
                completion(false)
                return
            }
            
            let dataExists = snapshot.exists()
            print("📊 Firebaseデータ存在確認: \(dataExists)")
            
            if dataExists, let data = snapshot.value as? [String: Any] {
                // 既存データを読み込み
                if let streak = data["currentStreak"] as? Int {
                    self.currentStreak = streak
                }
                if let totalDays = data["totalLoginDays"] as? Int {
                    self.totalLoginDays = totalDays
                }
                if let lastLoginTimestamp = data["lastLoginDate"] as? TimeInterval {
                    self.lastLoginDate = Date(timeIntervalSince1970: lastLoginTimestamp)
                }
            }
            
            completion(dataExists)
        }
    }
     
     // MARK: - 既存ユーザーの今日ログインチェック
     
     private func checkTodayLogin() {
         guard hasInitialized else { return }
         
         let today = Calendar.current.startOfDay(for: Date())
         
         if let lastLogin = lastLoginDate {
             let lastLoginDay = Calendar.current.startOfDay(for: lastLogin)
             let daysSinceLastLogin = Calendar.current.dateComponents([.day], from: lastLoginDay, to: today).day ?? 0
             
             if daysSinceLastLogin == 0 {
                 // 今日既にログイン済み
                 print("📅 今日は既にログイン済みです")
                 return
             } else {
                 // 新しい日のログイン
                 print("🆕 新しい日のログインを検出")
                 processLogin()
             }
         }
     }
     
     // MARK: - 強制初期化メソッド（デバッグ用）
     
     #if DEBUG
     func forceInitializeFirstTimeUser() {
         print("🔧 デバッグ: 強制的に初回ユーザーとして初期化")
         initializeFirstTimeUser()
     }
     #endif
    
    func initialize(userId: String) {
        print("🚀 === LoginBonusManager初期化開始 ===")
        print("👤 対象ユーザーID: \(userId)")
        
        self.userId = userId
        self.hasInitialized = false
        self.isProcessingLogin = false
        
        // データ読み込みを実行
        loadLoginDataWithCallback { [weak self] dataExists in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hasInitialized = true
                
                if !dataExists {
                    print("👤 新規ユーザー検出 -> 初回ログイン処理")
                    self.handleFirstTimeUser()
                } else {
                    print("👤 既存ユーザー検出 -> 今日のログインチェック")
                    self.checkTodayLoginForExistingUser()
                }
                
                // 初期化完了通知
                self.onInitializationComplete?()
                
                print("✅ === LoginBonusManager初期化完了 ===")
            }
        }
    }
    
    private func checkTodayLoginForExistingUser() {
        guard !isProcessingLogin else {
            print("⚠️ 既にログイン処理中のためスキップ")
            return
        }
        
        print("🔍 === 既存ユーザーの今日ログインチェック ===")
        
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastLogin = lastLoginDate {
            let lastLoginDay = Calendar.current.startOfDay(for: lastLogin)
            let daysSinceLastLogin = Calendar.current.dateComponents([.day], from: lastLoginDay, to: today).day ?? 0
            
            print("📅 最終ログイン: \(lastLoginDay)")
            print("📅 今日: \(today)")
            print("📊 経過日数: \(daysSinceLastLogin)日")
            
            if daysSinceLastLogin == 0 {
                print("✅ 今日は既にログイン済み")
                return
            } else {
                print("🆕 新しい日のログインを検出 -> ログイン処理実行")
                executeLoginProcess(daysSinceLastLogin: daysSinceLastLogin)
            }
        } else {
            print("⚠️ lastLoginDateがnull -> 初回処理として実行")
            handleFirstTimeUser()
        }
    }
    
    // MARK: - 🌟 ログイン処理実行
    private func executeLoginProcess(daysSinceLastLogin: Int) {
        isProcessingLogin = true
        
        print("🔄 === ログイン処理実行開始 ===")
        print("📊 前回からの経過日数: \(daysSinceLastLogin)")
        print("📊 現在の連続ログイン: \(currentStreak)")
        
        // 連続ログイン判定
        if daysSinceLastLogin == 1 {
            // 連続ログイン継続
            currentStreak += 1
            print("🔥 連続ログイン継続: \(currentStreak)日目")
        } else {
            // 連続ログインが途切れた
            currentStreak = 1
            print("💔 連続ログインが途切れました。1日目からリスタート")
        }
        
        // 基本情報更新
        totalLoginDays += 1
        lastLoginDate = Date()
        
        print("📊 更新後の状況:")
        print("  - 連続ログイン: \(currentStreak)日")
        print("  - 累計ログイン: \(totalLoginDays)日")
        
        // ボーナス計算
        calculateAndSetBonus()
        
        // データ保存
        saveLoginData()
        
        isProcessingLogin = false
        
        print("✅ === ログイン処理実行完了 ===")
        
        // ボーナスが生成された場合の追加ログ
        if let bonus = availableBonus {
            print("🎁 ログインボーナス生成完了:")
            print("  - タイプ: \(bonus.bonusType.displayName)")
            print("  - 親密度: +\(bonus.intimacyBonus)")
            print("  - メッセージ: \(bonus.description)")
        }
    }
    
    // MARK: - 🌟 ボーナス計算とセット
    private func calculateAndSetBonus() {
        print("🧮 ボーナス計算開始: \(currentStreak)日目")
        
        // 特定の日数でボーナステーブルを参照
        if let bonusData = bonusTable[currentStreak] {
            let bonus = LoginBonus(
                day: currentStreak,
                intimacyBonus: bonusData.intimacy,
                bonusType: bonusData.type,
                description: bonusData.description
            )
            
            availableBonus = bonus
            print("🎁 特別ボーナス生成: \(currentStreak)日目 +\(bonusData.intimacy) (\(bonusData.type.displayName))")
        } else {
            // 通常のデイリーボーナス
            let baseBonus = calculateDailyBonus(for: currentStreak)
            let bonus = LoginBonus(
                day: currentStreak,
                intimacyBonus: baseBonus,
                bonusType: .daily,
                description: generateDailyMessage(for: currentStreak)
            )
            
            availableBonus = bonus
            print("🎁 デイリーボーナス生成: \(currentStreak)日目 +\(baseBonus)")
        }
    }
    
    // MARK: - 🌟 手動ログイン処理（重複チェック付き）
    func processLogin() {
        guard hasInitialized else {
            print("⚠️ 初期化未完了のため手動ログイン処理をスキップ")
            return
        }
        
        guard !isProcessingLogin else {
            print("⚠️ 既にログイン処理中のため手動処理をスキップ")
            return
        }
        
        print("👆 手動ログイン処理要求")
        checkTodayLoginForExistingUser()
    }
     
    private func calculateDailyBonus(for day: Int) -> Int {
        switch day {
        case 1...7: return 3 + (day - 1)
        case 8...30: return 10 + ((day - 8) / 2)
        case 31...100: return 20 + ((day - 31) / 5)
        case 101...365: return 30 + ((day - 101) / 10)
        default: return 50 + ((day - 366) / 30)
        }
    }
     
     private func generateDailyMessage(for day: Int) -> String {
         let messages = [
             "今日も会いに来てくれてありがとう💕",
             "継続は力なり！素晴らしいですね✨",
             "毎日の積み重ねが愛を深めますね😊",
             "あなたに会える日々が宝物です💖",
             "今日も一緒に素敵な時間を過ごしましょう🌟",
             "継続的な愛情を感じています🥰",
             "毎日がより特別になっていきますね💫"
         ]
         
         return messages[day % messages.count]
     }
     
     func claimBonus(onIntimacyIncrease: @escaping (Int, String) -> Void) {
         guard let bonus = availableBonus else { return }
         
         // ボーナスを履歴に追加
         loginHistory.append(bonus)
         
         // 親密度増加のコールバック
         onIntimacyIncrease(bonus.intimacyBonus, "ログインボーナス(\(bonus.day)日目)")
         
         // ボーナスをクリア
         availableBonus = nil
         showingBonusView = false
         
         print("✅ ログインボーナス受取完了: +\(bonus.intimacyBonus)")
     }
     
     // MARK: - データ保存・読み込み（既存メソッドそのまま）
     
    private func saveLoginData() {
        guard let userId = userId else { return }
        
        let data: [String: Any] = [
            "currentStreak": currentStreak,
            "totalLoginDays": totalLoginDays,
            "lastLoginDate": lastLoginDate?.timeIntervalSince1970 ?? 0,
            "lastUpdated": Date().timeIntervalSince1970
        ]
        
        database.child("loginBonus").child(userId).child("status").updateChildValues(data)
        print("💾 ログインデータ保存完了")
    }
    
    private func loginBonusFromFirebaseData(_ data: [String: Any]) -> LoginBonus? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let day = data["day"] as? Int,
              let intimacyBonus = data["intimacyBonus"] as? Int,
              let bonusTypeString = data["bonusType"] as? String,
              let bonusType = LoginBonus.BonusType(rawValue: bonusTypeString),
              let receivedAtTimestamp = data["receivedAt"] as? TimeInterval,
              let description = data["description"] as? String else {
            return nil
        }

        let receivedAt = Date(timeIntervalSince1970: receivedAtTimestamp)
        return LoginBonus(
            id: id,
            day: day,
            intimacyBonus: intimacyBonus,
            bonusType: bonusType,
            receivedAt: receivedAt,
            description: description
        )
    }

    
    // MARK: - 統計・その他メソッド（既存のまま）
    
    func getTotalIntimacyFromBonuses() -> Int {
        return loginHistory.reduce(0) { $0 + $1.intimacyBonus }
    }
    
    func getBonusCountByType(_ type: LoginBonus.BonusType) -> Int {
        return loginHistory.filter { $0.bonusType == type }.count
    }
    
    func resetLoginBonus() {
        guard let userId = userId else { return }
        
        currentStreak = 0
        totalLoginDays = 0
        lastLoginDate = nil
        availableBonus = nil
        loginHistory.removeAll()
        
        database.child("loginBonus").child(userId).removeValue()
        
        print("🔄 ログインボーナスデータをリセットしました")
    }
    
    private func handleFirstTimeUser() {
        print("🌟 === 新規ユーザー初回ログイン処理 ===")
        
        // 初期値設定
        currentStreak = 1
        totalLoginDays = 1
        lastLoginDate = Date()
        
        // 初回ボーナス生成
        let firstBonus = LoginBonus(
            day: 1,
            intimacyBonus: 3,
            bonusType: .daily,
            description: "初回ログイン！今日も会いに来てくれてありがとう💕"
        )
        
        availableBonus = firstBonus
        
        // データ保存
        saveLoginData()
        
        print("🎁 初回ログインボーナス準備完了: +3親密度")
        print("✅ === 新規ユーザー処理完了 ===")
    }
    
    private func initializeFirstTimeUser() {
           print("🌟 === 初回ユーザー初期化開始 ===")
           
           // 初期値を設定
           currentStreak = 0
           totalLoginDays = 0
           lastLoginDate = nil
           availableBonus = nil
           loginHistory = []
           
           // 初回ログインボーナスを即座に処理
           processFirstTimeLogin()
           
           print("✅ 初回ユーザー初期化完了")
       }
       
       private func processFirstTimeLogin() {
           print("🎉 初回ログインボーナス処理開始")
           
           // 1. ログイン状態を更新
           currentStreak = 1
           totalLoginDays = 1
           lastLoginDate = Date()
           
           // 2. 初回ボーナスを生成
           let firstBonus = LoginBonus(
               day: 1,
               intimacyBonus: 3,
               bonusType: .daily,
               description: "初回ログイン！今日も会いに来てくれてありがとう💕"
           )
           
           availableBonus = firstBonus
           
           // 3. データを保存
           saveLoginData()
           
           // 4. 少し遅延してボーナス表示
           DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
               self.showingBonusView = true
           }
           
           print("🎁 初回ログインボーナス準備完了: +3親密度")
       }
    
    // MARK: - ボーナス計算
    
    private func calculateBonus() {
        // 特定の日数でボーナステーブルを参照
        if let bonusData = bonusTable[currentStreak] {
            let bonus = LoginBonus(
                day: currentStreak,
                intimacyBonus: bonusData.intimacy,
                bonusType: bonusData.type,
                description: bonusData.description
            )
            
            availableBonus = bonus
            print("🎁 ログインボーナス獲得: \(currentStreak)日目 +\(bonusData.intimacy) (\(bonusData.type.displayName))")
        } else {
            // 通常のデイリーボーナス (特定日以外)
            let baseBonus = calculateDailyBonus(for: currentStreak)
            let bonus = LoginBonus(
                day: currentStreak,
                intimacyBonus: baseBonus,
                bonusType: .daily,
                description: generateDailyMessage(for: currentStreak)
            )
            
            availableBonus = bonus
            print("🎁 デイリーボーナス獲得: \(currentStreak)日目 +\(baseBonus)")
        }
    }
    
    // MARK: - データ管理
    
    private func loadLoginData() {
        guard let userId = userId else { return }
        
        database.child("loginBonus").child(userId).child("status").observe(.value) { [weak self] snapshot in
            guard let self = self,
                  let data = snapshot.value as? [String: Any] else { return }
            
            if let streak = data["currentStreak"] as? Int {
                self.currentStreak = streak
            }
            if let totalDays = data["totalLoginDays"] as? Int {
                self.totalLoginDays = totalDays
            }
            if let lastLoginTimestamp = data["lastLoginDate"] as? TimeInterval {
                self.lastLoginDate = Date(timeIntervalSince1970: lastLoginTimestamp)
            }
            
            print("📥 ログインデータ読み込み完了: 連続\(self.currentStreak)日, 累計\(self.totalLoginDays)日")
        }
    }
    

    
    func getLastBonusDate() -> Date? {
        return loginHistory.first?.receivedAt
    }
}
