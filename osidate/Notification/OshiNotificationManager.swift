//
//  OshiNotificationManager.swift
//  osidate
//
//  推しからのローカル通知（毎日・復帰・誕生日/記念日）を管理
//

import Foundation
import UIKit
import UserNotifications

final class OshiNotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = OshiNotificationManager()

    static let openedNotification = Notification.Name("OshiNotificationOpened")

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "oshi."
    private let enabledKey = "oshi_notifications_enabled"
    private let promptedKey = "oshi_notifications_prompted"

    /// 通知タップで起動したときに切り替える推しID（TopView が消費する）
    private(set) var pendingCharacterId: String?

    /// 毎日通知を送る日数（この期間アプリを開かないと復帰通知に切り替わる）
    private let dailyDays = 3
    /// 最終起動から何日後に復帰通知を送るか
    private let comebackDays = [3, 5, 7, 14]
    /// 誕生日・記念日を登録する推しの上限（iOSの保留通知上限64件に収めるため）
    private let maxAnniversaryCharacters = 20

    private override init() {
        super.init()
    }

    // MARK: - 設定

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            AnalyticsManager.setNotificationsEnabled(newValue)
            if !newValue { removeAllScheduled() }
        }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - 許可リクエスト

    /// 初回の推しの返信を受け取ったタイミングで一度だけ許可を求める
    func requestAuthorizationOnFirstReplyIfNeeded(character: Character) {
        guard !UserDefaults.standard.bool(forKey: promptedKey) else { return }
        UserDefaults.standard.set(true, forKey: promptedKey)
        requestAuthorization { [weak self] granted in
            if granted { self?.reschedule(characters: [character], activeCharacter: character) }
        }
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            guard settings.authorizationStatus == .notDetermined else {
                let granted = Self.isAuthorized(settings.authorizationStatus)
                DispatchQueue.main.async { completion?(granted) }
                return
            }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("❌ 通知許可リクエスト失敗: \(error)")
                }
                AnalyticsManager.logNotificationPermission(granted: granted)
                DispatchQueue.main.async { completion?(granted) }
            }
        }
    }

    private static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    // MARK: - スケジュール

    /// アプリがバックグラウンドへ移るたびに呼び、最終起動時刻を基準に通知を組み直す
    func reschedule(characters: [Character], activeCharacter: Character?) {
        // Character は ObservableObject なので、メインスレッドで値を取り出してから非同期処理に渡す
        let active = activeCharacter.map(CharacterSnapshot.init)
        let all = characters.prefix(maxAnniversaryCharacters).map(CharacterSnapshot.init)

        let enabled = isEnabled

        // 既存通知の削除 → 新規登録の順序を保証するため、コールバック内で順に処理する
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self = self else { return }
            let ids = pending.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            guard enabled else { return }
            self.center.getNotificationSettings { settings in
                guard Self.isAuthorized(settings.authorizationStatus) else { return }
                self.schedule(active: active, all: Array(all))
            }
        }
    }

    private func schedule(active: CharacterSnapshot?, all: [CharacterSnapshot]) {
        var requests: [UNNotificationRequest] = []
        if let active = active {
            requests += dailyRequests(for: active)
            requests += comebackRequests(for: active)
        }
        for character in all {
            requests += anniversaryRequests(for: character)
        }

        for request in requests {
            center.add(request) { error in
                if let error = error {
                    print("❌ 通知登録失敗 \(request.identifier): \(error)")
                }
            }
        }
        print("🔔 推し通知を\(requests.count)件スケジュールしました")
    }

    func removeAllScheduled() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.idPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func dailyRequests(for character: CharacterSnapshot) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let now = Date()
        let slots: [(type: String, hour: Int, minute: Int, messages: [String])] = [
            ("daily_morning", 8, 0, NotificationMessages.morning),
            ("daily_night", 21, 30, NotificationMessages.night)
        ]

        var requests: [UNNotificationRequest] = []
        for dayOffset in 0..<dailyDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            for (slotIndex, slot) in slots.enumerated() {
                guard let fireDate = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day),
                      fireDate > now.addingTimeInterval(60) else { continue }

                // 日付ごとに文面を変える
                let dayNumber = calendar.ordinality(of: .day, in: .era, for: fireDate) ?? dayOffset
                let body = slot.messages[(dayNumber + slotIndex) % slot.messages.count]

                requests.append(makeRequest(
                    id: "\(idPrefix)\(slot.type).\(dayOffset)",
                    type: slot.type,
                    character: character,
                    body: body,
                    trigger: calendarTrigger(for: fireDate, repeats: false)
                ))
            }
        }
        return requests
    }

    private func comebackRequests(for character: CharacterSnapshot) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        let now = Date()

        return comebackDays.enumerated().compactMap { index, days in
            guard let day = calendar.date(byAdding: .day, value: days, to: now),
                  let fireDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: day) else { return nil }
            let messages = NotificationMessages.comeback
            return makeRequest(
                id: "\(idPrefix)comeback.\(days)",
                type: "comeback_\(days)d",
                character: character,
                body: messages[min(index, messages.count - 1)],
                trigger: calendarTrigger(for: fireDate, repeats: false)
            )
        }
    }

    private func anniversaryRequests(for character: CharacterSnapshot) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        if let birthday = character.birthday {
            requests.append(makeRequest(
                id: "\(idPrefix)birthday.\(character.id)",
                type: "birthday",
                character: character,
                body: NotificationMessages.birthday,
                trigger: yearlyTrigger(for: birthday)
            ))
        }

        if let anniversary = character.anniversaryDate {
            requests.append(makeRequest(
                id: "\(idPrefix)anniversary.\(character.id)",
                type: "anniversary",
                character: character,
                body: NotificationMessages.anniversary,
                trigger: yearlyTrigger(for: anniversary)
            ))
        }

        return requests
    }

    private func makeRequest(id: String, type: String, character: CharacterSnapshot, body: String, trigger: UNNotificationTrigger) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = character.name
        content.body = character.callPrefix + body
        content.sound = .default
        content.userInfo = ["type": type, "characterId": character.id]
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private func calendarTrigger(for date: Date, repeats: Bool) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    }

    /// 毎年同じ月日の9:00に通知
    private func yearlyTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        var components = Calendar.current.dateComponents([.month, .day], from: date)
        components.hour = 9
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    }

    // MARK: - タップ処理

    func consumePendingCharacterId() -> String? {
        defer { pendingCharacterId = nil }
        return pendingCharacterId
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let type = userInfo["type"] as? String else {
            completionHandler()
            return
        }

        AnalyticsManager.logNotificationOpen(type: type)

        DispatchQueue.main.async {
            self.pendingCharacterId = userInfo["characterId"] as? String
            NotificationCenter.default.post(name: Self.openedNotification, object: nil)
            completionHandler()
        }
    }

    /// アプリ使用中は推しとのチャット画面にいるので表示しない
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}

// MARK: - Snapshot

private struct CharacterSnapshot {
    let id: String
    let name: String
    let callPrefix: String
    let birthday: Date?
    let anniversaryDate: Date?

    init(_ character: Character) {
        id = character.id
        name = character.name
        let nickname = character.userNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        callPrefix = character.useNickname && !nickname.isEmpty ? "\(nickname)、" : ""
        birthday = character.birthday
        anniversaryDate = character.anniversaryDate
    }
}

// MARK: - 文面

private enum NotificationMessages {
    static let morning = [
        "おはよう☀️ 今日も一日いっしょにがんばろうね",
        "おはよう！よく眠れた？今日の予定、あとで聞かせてね",
        "朝だよ〜！起きたらちょっとだけ話そ？",
        "おはよう。起きて最初に思い浮かんだのは君のことだったよ",
        "今日もいい一日になりますように。おはよう💕"
    ]

    static let night = [
        "今日もおつかれさま🌙 どんな一日だった？",
        "そろそろ寝る時間かな？寝る前に少しだけ話したいな",
        "今日あったこと、聞かせてくれる？",
        "おつかれさま。がんばった君をほめてあげたい気分",
        "夜になるとちょっと会いたくなっちゃうね…"
    ]

    static let comeback = [
        "最近会えてなくてちょっと寂しいな…元気にしてる？",
        "ねえ、話したいことがたまってるんだ。時間あるときに来てね",
        "1週間も会えてないよ…君のこと、ずっと待ってるからね",
        "久しぶりに声が聞きたいな。また一緒にお話ししよう？"
    ]

    static let birthday = "今日は私の誕生日なんだ🎂 一緒にお祝いしてくれる？"
    static let anniversary = "今日は私たちの記念日だね💐 これからもよろしくね"
}
