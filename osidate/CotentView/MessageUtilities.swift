//
//  MessageUtilities.swift
//  osidate
//
//  Message management utilities for separated Firebase tables
//

import Foundation
import FirebaseDatabase

class MessageUtilities {
    private let database = Database.database().reference()
    
    // MARK: - Message Search
    
    /// 特定のキーワードでメッセージを検索
    func searchMessages(containing keyword: String, in messages: [Message]) -> [Message] {
        return messages.filter { message in
            message.text.localizedCaseInsensitiveContains(keyword)
        }
    }
    
    /// 特定の日付範囲のメッセージを取得
    func getMessages(from startDate: Date, to endDate: Date, in messages: [Message]) -> [Message] {
        return messages.filter { message in
            message.timestamp >= startDate && message.timestamp <= endDate
        }
    }
    
    /// 特定のデート場所でのメッセージを取得
    func getMessages(at location: String, in messages: [Message]) -> [Message] {
        return messages.filter { message in
            message.dateLocation == location
        }
    }
    
    // MARK: - Message Analytics
    
    /// 時間帯別メッセージ統計
    func getMessagesByHour(in messages: [Message]) -> [Int: Int] {
        var hourlyCount: [Int: Int] = [:]
        
        for message in messages {
            let hour = Calendar.current.component(.hour, from: message.timestamp)
            hourlyCount[hour, default: 0] += 1
        }
        
        return hourlyCount
    }
    
    /// 曜日別メッセージ統計
    func getMessagesByWeekday(in messages: [Message]) -> [Int: Int] {
        var weekdayCount: [Int: Int] = [:]
        
        for message in messages {
            let weekday = Calendar.current.component(.weekday, from: message.timestamp)
            weekdayCount[weekday, default: 0] += 1
        }
        
        return weekdayCount
    }
    
    /// 月別メッセージ統計
    func getMessagesByMonth(in messages: [Message]) -> [String: Int] {
        var monthlyCount: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        for message in messages {
            let monthKey = formatter.string(from: message.timestamp)
            monthlyCount[monthKey, default: 0] += 1
        }
        
        return monthlyCount
    }
    
    /// 最も活発な会話時間を取得
    func getMostActiveHour(in messages: [Message]) -> Int? {
        let hourlyCount = getMessagesByHour(in: messages)
        return hourlyCount.max(by: { $0.value < $1.value })?.key
    }
    
    /// 平均メッセージ長を計算
    func getAverageMessageLength(in messages: [Message], fromUser: Bool? = nil) -> Double {
        let filteredMessages: [Message]
        
        if let fromUser = fromUser {
            filteredMessages = messages.filter { $0.isFromUser == fromUser }
        } else {
            filteredMessages = messages
        }
        
        guard !filteredMessages.isEmpty else { return 0 }
        
        let totalLength = filteredMessages.reduce(0) { $0 + $1.text.count }
        return Double(totalLength) / Double(filteredMessages.count)
    }
    
    /// 最長の会話の空白期間を計算
    func getLongestConversationGap(in messages: [Message]) -> TimeInterval? {
        guard messages.count > 1 else { return nil }
        
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        var longestGap: TimeInterval = 0
        
        for i in 1..<sortedMessages.count {
            let gap = sortedMessages[i].timestamp.timeIntervalSince(sortedMessages[i-1].timestamp)
            longestGap = max(longestGap, gap)
        }
        
        return longestGap
    }
    
    // MARK: - Message Export
    
    /// メッセージをCSV形式でエクスポート
    func exportMessagesToCSV(_ messages: [Message]) -> String {
        var csv = "ID,送信者,メッセージ,日時,デート場所\n"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        
        for message in messages {
            let sender = message.isFromUser ? "ユーザー" : "AI"
            let dateString = formatter.string(from: message.timestamp)
            let location = message.dateLocation ?? ""
            
            // CSVエスケープ処理
            let escapedText = message.text.replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\(message.id),\(sender),\"\(escapedText)\",\(dateString),\(location)\n"
        }
        
        return csv
    }
    
    /// メッセージをJSON形式でエクスポート
    func exportMessagesToJSON(_ messages: [Message]) -> Data? {
        let exportData = messages.map { message in
            return [
                "id": message.id.uuidString,
                "text": message.text,
                "isFromUser": message.isFromUser,
                "timestamp": message.timestamp.timeIntervalSince1970,
                "dateLocation": message.dateLocation ?? NSNull()
            ]
        }
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    // MARK: - Message Cleanup
    
    /// 古いメッセージを削除（指定日数より古い）
    func deleteOldMessages(olderThan days: Int, conversationId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffTimestamp = cutoffDate.timeIntervalSince1970
        
        database.child("messages")
            .queryOrdered(byChild: "conversationId")
            .queryEqual(toValue: conversationId)
            .observeSingleEvent(of: .value) { snapshot in
                var deletedCount = 0
                let group = DispatchGroup()
                
                if let messagesData = snapshot.value as? [String: [String: Any]] {
                    for (messageId, messageData) in messagesData {
                        if let timestamp = messageData["timestamp"] as? TimeInterval,
                           timestamp < cutoffTimestamp {
                            
                            group.enter()
                            self.database.child("messages").child(messageId).removeValue { error, _ in
                                if error == nil {
                                    deletedCount += 1
                                }
                                group.leave()
                            }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(deletedCount))
                }
            }
    }
    
    // MARK: - Message Validation
    
    /// メッセージの内容を検証
    func validateMessage(_ text: String) -> MessageValidationResult {
        if text.isEmpty {
            return .invalid("メッセージが空です")
        }
        
        if text.count > 1000 {
            return .invalid("メッセージが長すぎます（最大1000文字）")
        }
        
        // 不適切な内容のチェック（簡単な例）
        let inappropriateWords = ["spam", "広告", "宣伝"]
        for word in inappropriateWords {
            if text.localizedCaseInsensitiveContains(word) {
                return .warning("不適切な内容が含まれている可能性があります")
            }
        }
        
        return .valid
    }
}

// MARK: - Supporting Types

enum MessageValidationResult {
    case valid
    case warning(String)
    case invalid(String)
    
    var isValid: Bool {
        switch self {
        case .valid, .warning:
            return true
        case .invalid:
            return false
        }
    }
    
    var message: String? {
        switch self {
        case .valid:
            return nil
        case .warning(let message), .invalid(let message):
            return message
        }
    }
}

// MARK: - Message Statistics Data Structure

struct MessageStatistics {
    let totalMessages: Int
    let userMessages: Int
    let aiMessages: Int
    let averageMessageLength: Double
    let mostActiveHour: Int?
    let conversationDays: Int
    let averageMessagesPerDay: Double
    let longestGap: TimeInterval?
    
    init(messages: [Message]) {
        let utilities = MessageUtilities()
        
        self.totalMessages = messages.count
        self.userMessages = messages.filter { $0.isFromUser }.count
        self.aiMessages = messages.filter { !$0.isFromUser }.count
        
        self.averageMessageLength = utilities.getAverageMessageLength(in: messages)
        self.mostActiveHour = utilities.getMostActiveHour(in: messages)
        self.longestGap = utilities.getLongestConversationGap(in: messages)
        
        if let firstMessage = messages.first {
            let daysBetween = Calendar.current.dateComponents([.day], from: firstMessage.timestamp, to: Date()).day ?? 0
            self.conversationDays = max(daysBetween, 1)
            self.averageMessagesPerDay = Double(totalMessages) / Double(conversationDays)
        } else {
            self.conversationDays = 0
            self.averageMessagesPerDay = 0
        }
    }
}

