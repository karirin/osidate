//
//  AnalyticsManager.swift
//  osidate
//
//  Firebase Analytics のイベント送信を一元管理
//

import Foundation
import StoreKit
import FirebaseAnalytics

enum AnalyticsManager {

    // MARK: - ユーザー識別・属性

    static func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    static func setIntimacyStage(_ stage: IntimacyStage) {
        Analytics.setUserProperty(stage.rawValue, forName: "intimacy_stage")
    }

    static func setSubscribed(_ isSubscribed: Bool) {
        Analytics.setUserProperty(isSubscribed ? "true" : "false", forName: "is_subscribed")
    }

    static func setCharacterCount(_ count: Int) {
        Analytics.setUserProperty(String(count), forName: "character_count")
    }

    static func setNotificationsEnabled(_ enabled: Bool) {
        Analytics.setUserProperty(enabled ? "true" : "false", forName: "notifications_enabled")
    }

    // MARK: - 画面

    static func logScreen(_ name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name
        ])
    }

    // MARK: - オンボーディング

    static func logTutorialComplete() {
        Analytics.logEvent(AnalyticsEventTutorialComplete, parameters: nil)
    }

    static func logCharacterCreate(totalCount: Int) {
        Analytics.logEvent("character_create", parameters: ["total_count": totalCount])
    }

    // MARK: - コア行動

    static func logMessageSend(intimacyStage: IntimacyStage, inDate: Bool) {
        Analytics.logEvent("message_send", parameters: [
            "intimacy_stage": intimacyStage.rawValue,
            "in_date": inDate ? 1 : 0
        ])
    }

    static func logAIReplyFailed() {
        Analytics.logEvent("ai_reply_failed", parameters: nil)
    }

    static func logDateStart(location: DateLocation) {
        Analytics.logEvent("date_start", parameters: [
            "location": location.name,
            "location_type": location.type.displayName
        ])
    }

    static func logDateEnd(location: DateLocation, durationSeconds: Int, messages: Int) {
        Analytics.logEvent("date_end", parameters: [
            "location": location.name,
            "duration_sec": durationSeconds,
            "messages": messages
        ])
    }

    static func logIntimacyLevelUp(to stage: IntimacyStage) {
        Analytics.logEvent("intimacy_level_up", parameters: ["stage": stage.rawValue])
        setIntimacyStage(stage)
    }

    static func logLoginBonusClaim(day: Int, intimacyBonus: Int) {
        Analytics.logEvent("login_bonus_claim", parameters: [
            "day": day,
            "intimacy_bonus": intimacyBonus
        ])
    }

    // MARK: - 課金

    static func logSubscriptionPurchase(_ transaction: Transaction) {
        // StoreKit 2 の購入は自動計測されないため明示的に送る
        Analytics.logTransaction(transaction)
        Analytics.logEvent("subscription_purchase", parameters: ["product_id": transaction.productID])
    }

    // MARK: - ペイウォール（source ごとの成約率を見るため全イベントに source を付ける）

    static func logPaywallView(source: String) {
        Analytics.logEvent("paywall_view", parameters: ["source": source])
    }

    static func logPaywallClose(source: String, purchased: Bool) {
        Analytics.logEvent("paywall_close", parameters: [
            "source": source,
            "purchased": purchased ? 1 : 0
        ])
    }

    static func logPaywallPlanSelect(source: String, productId: String) {
        Analytics.logEvent("paywall_plan_select", parameters: [
            "source": source,
            "product_id": productId
        ])
    }

    static func logPurchaseStart(source: String, productId: String, hasTrial: Bool) {
        Analytics.logEvent("purchase_start", parameters: [
            "source": source,
            "product_id": productId,
            "has_trial": hasTrial ? 1 : 0
        ])
    }

    /// result: "success" / "cancelled" / "pending" / "failed"
    static func logPurchaseResult(source: String, productId: String, result: String) {
        Analytics.logEvent("purchase_result", parameters: [
            "source": source,
            "product_id": productId,
            "result": result
        ])
    }

    // MARK: - 通知

    static func logNotificationPermission(granted: Bool) {
        Analytics.logEvent("notification_permission", parameters: ["granted": granted ? 1 : 0])
        setNotificationsEnabled(granted)
    }

    static func logNotificationOpen(type: String) {
        Analytics.logEvent("notification_open", parameters: ["type": type])
    }
}
