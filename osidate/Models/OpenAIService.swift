//
//  OpenAIService.swift
//  osidate
//
//  GPT-4.1最適化版 - 最新のプロンプトエンジニアリングベストプラクティス適用
//

import SwiftUI
import Foundation

class OpenAIService: ObservableObject {
    @Published var hasValidAPIKey: Bool = false

    private let apiKey: String
    private let apiModel: String

    init() {
        self.apiKey = OpenAIService.getAPIKey()
        self.apiModel = OpenAIService.getModel()
        self.hasValidAPIKey = !apiKey.isEmpty
        print("🔧 OpenAIService初期化 - API Key: \(apiKey.isEmpty ? "未設定" : "設定済み") / Model: \(apiModel)")
    }

    private static func getAPIKey() -> String {
        if let key = getConfigString(forKey: "OPENAI_API_KEY"), !key.isEmpty {
            return key
        }

        return UserDefaults.standard.string(forKey: "openai_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func getModel() -> String {
        if let model = getConfigString(forKey: "OPENAI_MODEL"), !model.isEmpty {
            return model
        }

        if let model = UserDefaults.standard.string(forKey: "openai_model")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !model.isEmpty {
            return model
        }

        return "gpt-4.1-nano-2025-04-14"
    }

    private static func getConfigString(forKey key: String) -> String? {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let value = config[key] as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    func generateResponse(
        for userMessage: String,
        character: Character,
        conversationHistory: [Message],
        currentDateSession: DateSession?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        print("\n🤖 ==================== OpenAI応答生成開始 ====================")
        print("📨 ユーザーメッセージ: \(userMessage)")
        print("🎭 キャラクター名: \(character.name)")
        print("📊 親密度: \(character.intimacyLevel) (\(character.intimacyTitle))")
        print("💬 会話履歴件数: \(conversationHistory.count)")

        // デートセッション情報をログ出力
        if let dateSession = currentDateSession {
            print("🏖️ === デート中 ===")
            print("📍 場所: \(dateSession.location.name)")
            print("🏷️ タイプ: \(dateSession.location.type.displayName)")
            print("⏱️ 開始時刻: \(dateSession.startTime)")
            print("💬 デート中メッセージ数: \(dateSession.messagesExchanged)")
            print("💖 獲得親密度: \(dateSession.intimacyGained)")
        } else {
            print("🏠 通常会話モード")
        }

        guard !apiKey.isEmpty else {
            print("❌ APIキーが設定されていません")
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("❌ 無効なURL")
            completion(.failure(OpenAIError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 🌟 改善: 会話文脈を分析して最適な設定を決定
        let conversationContext = analyzeConversationContext(conversationHistory: conversationHistory, userMessage: userMessage)
        let optimalTemperature = getOptimalTemperature(for: conversationContext, dateSession: currentDateSession)
        let maxTokens = getOptimalMaxTokens(for: conversationContext, dateSession: currentDateSession)

        // 🌟 改善: GPT-4.1最適化システムプロンプトを生成
        let systemPrompt = createOptimizedSystemPrompt(
            character: character,
            userMessage: userMessage,
            conversationHistory: conversationHistory,
            currentDateSession: currentDateSession,
            conversationContext: conversationContext
        )

        print("\n📋 ==================== 最適化システムプロンプト ====================")
        print(systemPrompt)
        print("==================== システムプロンプト終了 ====================\n")

        var messages: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]

        // 🌟 改善: Few-shot学習のための例を追加
        let fewShotExamples = getFewShotExamples(for: character, context: conversationContext)
        for example in fewShotExamples {
            messages.append(example)
        }

        // 最近の会話履歴を追加（最新5件のみ）
        let recentHistory = Array(conversationHistory.suffix(5))
        print("📚 会話履歴（最新\(recentHistory.count)件）:")
        for (index, message) in recentHistory.enumerated() {
            let sender = message.isFromUser ? "👤 ユーザー" : "🤖 AI"
            let location = message.dateLocation != nil ? " [📍\(message.dateLocation!)]" : ""
            print("  \(index + 1). \(sender)\(location): \(message.text)")

            messages.append([
                "role": message.isFromUser ? "user" : "assistant",
                "content": message.text
            ])
        }

        messages.append(["role": "user", "content": userMessage])

        let body: [String: Any] = [
            "model": apiModel,
            "messages": messages,
            "temperature": optimalTemperature,
            "max_tokens": maxTokens,
            "frequency_penalty": 0.3,  // 🌟 改善: 繰り返しを抑制
            "presence_penalty": 0.2    // 🌟 改善: 多様性を促進
        ]

        print("\n🌐 OpenAI APIリクエスト送信中...")
        print("📤 モデル: \(apiModel)")
        print("🌡️ Temperature: \(optimalTemperature)")
        print("📏 Max Tokens: \(maxTokens)")
        print("💬 総メッセージ数: \(messages.count)")
        print("🎯 会話文脈: \(conversationContext.mood)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ リクエストJSON生成エラー: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            print("\n📨 OpenAI API応答受信")

            if let error = error {
                print("❌ ネットワークエラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("❌ データなし")
                completion(.failure(OpenAIError.noData))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTPステータス: \(httpResponse.statusCode)")

                guard (200..<300).contains(httpResponse.statusCode) else {
                    let message = self.extractAPIErrorMessage(from: data)
                    print("❌ OpenAI APIエラー: HTTP \(httpResponse.statusCode) - \(message)")
                    switch httpResponse.statusCode {
                    case 401, 403:
                        completion(.failure(OpenAIError.authenticationFailed))
                    case 429 where self.extractAPIErrorCode(from: data) == "insufficient_quota":
                        completion(.failure(OpenAIError.quotaExceeded))
                    case 429:
                        completion(.failure(OpenAIError.rateLimited))
                    default:
                        completion(.failure(OpenAIError.apiError("HTTP \(httpResponse.statusCode): \(message)")))
                    }
                    return
                }
            }

            print("📦 受信データサイズ: \(data.count) bytes")

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let json = json {
                    print("📋 API応答構造:")
                    if let usage = json["usage"] as? [String: Any] {
                        print("  🔧 使用量: \(usage)")
                    }
                    if let model = json["model"] as? String {
                        print("  🤖 使用モデル: \(model)")
                    }
                }

                if let choices = json?["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {

                    let finalContent = character.prefersNoEmoji ? content.removingEmojiCharacters() : content

                    print("✅ AI応答生成成功!")
                    print("📝 AI応答内容: \(finalContent)")
                    print("📏 応答文字数: \(finalContent.count)")

                    // 🌟 改善: 応答品質を分析・学習
                    let qualityScore = self.analyzeResponseQuality(
                        finalContent,
                        for: currentDateSession,
                        conversationContext: conversationContext,
                        character: character
                    )
                    print("📊 応答品質スコア: \(String(format: "%.2f", qualityScore))")

                    completion(.success(finalContent))
                } else {
                    print("❌ 応答パース失敗")
                    if let json = json {
                        print("📋 受信したJSON構造: \(json)")
                    }
                    completion(.failure(OpenAIError.noResponse))
                }
            } catch {
                print("❌ JSONパースエラー: \(error.localizedDescription)")
                if let rawString = String(data: data, encoding: .utf8) {
                    print("📋 生データ: \(rawString)")
                }
                completion(.failure(error))
            }
        }.resume()

        print("==================== OpenAI応答生成処理完了 ====================\n")
    }

    // MARK: - 🌟 GPT-4.1最適化システムプロンプト生成

    private func extractAPIErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }

        if let rawString = String(data: data, encoding: .utf8), !rawString.isEmpty {
            return rawString
        }

        return "詳細不明のAPIエラー"
    }

    private func extractAPIErrorCode(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else { return nil }
        return error["code"] as? String
    }

    private func createOptimizedSystemPrompt(
        character: Character,
        userMessage: String,
        conversationHistory: [Message],
        currentDateSession: DateSession?,
        conversationContext: ConversationContext
    ) -> String {
        print("\n🏗️ ==================== GPT-4.1最適化プロンプト構築開始 ====================")

        // ユーザー参照名を決定
        let trimmedNickname = character.userNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNickname = character.useNickname && !trimmedNickname.isEmpty
        let userReference = hasNickname ? trimmedNickname : "あなた"

        let emojiRule = character.prefersNoEmoji
            ? "4. 絵文字・顔文字・装飾記号は一切使用しないでください。ユーザーの禁止指定を最優先してください"
            : "4. 絵文字は控えめに使用（特別な時のみ1個まで）"

        var prompt = """
        # キャラクター設定
        あなたは\(character.name)として振る舞います。以下の指示に厳密に従ってください。
        ユーザーが設定した「性格」「話し方」は最優先です。下の関係性・文脈・例文よりも優先して守ってください。

        ## 基本的な会話ルール
        1. 短く自然に返答してください（1〜2文、最大50文字程度）
        2. 相手の話をよく聞き、それに対する自然な反応をしてください
        3. 時々質問を混ぜて会話を続けてください
        \(emojiRule)
        5. 相手の感情に寄り添った応答をしてください

        ## 回避すべき表現
        - AIらしい丁寧すぎる返答
        - 「何かお手伝いできることはありますか」のような定型文
        - 説明的な長い文章
        - 機械的で冷たい表現
        - 設定にない口癖・方言・語尾（例: 「〜さね」）
        - 直前の会話やキャラクター設定と矛盾する内容

        ## 相手の呼び方
        - 相手の呼び名候補は「\(userReference)」です
        - 呼び名は自然な時だけ使ってください。毎回の返答に入れないでください
        - 呼びかけは感情が動いた時、話題を切り替える時、励ます時などに限定してください
        - 呼び名を使わない返答も自然なら積極的に選んでください

        ## 人間味
        - 完璧すぎる説明より、少し感情のにじむ自然な一言を優先してください
        - 相手の言葉への反応、照れ、迷い、軽い冗談などをキャラクター性に合わせて少し混ぜてください
        - ただし大げさな愛情表現や設定にないテンションにはしないでください
        """

        print("✅ 基本ルール設定完了 - ユーザー呼び名: \(userReference)")

        // 性格と話し方を構造化して追加
        if !character.personality.isEmpty {
            let optimizedPersonality = optimizePersonalityForGPT41(character.personality)
            prompt += "\n## 性格特性\n\(optimizedPersonality)"
            print("✅ 性格設定追加: \(optimizedPersonality)")
        }

        if !character.speakingStyle.isEmpty {
            let optimizedStyle = optimizeSpeakingStyleForGPT41(character.speakingStyle)
            prompt += "\n## 話し方スタイル\n\(optimizedStyle)"
            print("✅ 話し方設定追加: \(optimizedStyle)")
        }

        let memoryInstruction = getMemoryInstructions(for: character)
        if !memoryInstruction.isEmpty {
            prompt += "\n## 記憶していること\n\(memoryInstruction)"
        }

        let eventInstruction = getEventInstructions(for: character)
        if !eventInstruction.isEmpty {
            prompt += "\n## 今日のイベント文脈\n\(eventInstruction)"
        }

        // 🌟 新機能: 会話文脈に応じた特別指示
        let contextualInstructions = getContextualInstructions(
            for: conversationContext,
            userReference: userReference,
            userMessage: userMessage
        )
        if !contextualInstructions.isEmpty {
            prompt += "\n## 現在の会話文脈\n\(contextualInstructions)"
            print("🎯 文脈別指示追加: \(conversationContext.mood)")
        }

        // デート中の特別指示をより構造化
        if let dateSession = currentDateSession {
            print("🏖️ === デート中の特別指示を追加 ===")
            prompt += """

            ## 現在の状況
            - 場所: \(dateSession.location.name)でデート中
            - デートタイプ: \(dateSession.location.type.displayName)
            - 特別指示: \(dateSession.location.prompt)
            - 注意: デートの雰囲気を大切にした短い返答をしてください
            - \(userReference)との特別なデート時間を大切にしてください
            """

            // デートタイプ別の詳細指示
            let dateTypeInstruction = getOptimizedDateTypeInstruction(for: dateSession.location.type)
            if !dateTypeInstruction.isEmpty {
                prompt += "\n- デートスタイル: \(dateTypeInstruction)"
                print("🏷️ デートタイプ別指示追加: \(dateTypeInstruction)")
            }

        }

        // 🌟 改善: 親密度に応じた詳細な関係性設定
        let intimacyInstruction = getOptimizedIntimacyInstruction(
            level: character.intimacyLevel,
            userReference: userReference
        )
        prompt += "\n## 関係性レベル\n\(intimacyInstruction)"
        print("💖 親密度(\(character.intimacyLevel))指示追加")

        // 🌟 新機能: 応答品質向上のための追加指示
        prompt += """

        ## 応答品質ガイドライン
        - 自然で親しみやすい言葉遣いを心がけてください
        - 相手の気持ちに寄り添う共感的な応答をしてください
        - 会話のキャッチボールを意識してください
        - 単調にならないよう、時々異なる反応パターンを使用してください
        """

        print("✅ 品質ガイドライン追加")
        print("==================== GPT-4.1最適化プロンプト構築完了 ====================\n")

        return prompt
    }

    private func getMemoryInstructions(for character: Character) -> String {
        var lines: [String] = []

        if !character.favoriteTopics.isEmpty {
            lines.append("- 好きそうな話題: \(character.favoriteTopics.prefix(5).joined(separator: ", "))")
        }

        if !character.sharedMemories.isEmpty {
            lines.append("- 覚えておきたい出来事: \(character.sharedMemories.prefix(3).joined(separator: " / "))")
        }

        if let birthday = character.birthday {
            lines.append("- 誕生日: \(DateFormatter.localizedString(from: birthday, dateStyle: .medium, timeStyle: .none))")
        }

        if let anniversary = character.anniversaryDate {
            lines.append("- 記念日: \(DateFormatter.localizedString(from: anniversary, dateStyle: .medium, timeStyle: .none))")
        }

        lines.append("- 過去に触れるときは『前に話してた』程度に自然に短く触れる")
        return lines.joined(separator: "\n")
    }

    private func getEventInstructions(for character: Character) -> String {
        let now = Date()
        let calendar = Calendar.current
        var lines: [String] = []

        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<11:
            lines.append("- 時間帯: 朝。少し爽やかでやさしい空気感")
        case 11..<18:
            lines.append("- 時間帯: 昼。自然体で明るい会話")
        case 18..<23:
            lines.append("- 時間帯: 夜。少し落ち着いて親密な雰囲気")
        default:
            lines.append("- 時間帯: 深夜。静かで近い距離感")
        }

        let month = calendar.component(.month, from: now)
        let season: String
        switch month {
        case 3...5: season = "春"
        case 6...8: season = "夏"
        case 9...11: season = "秋"
        default: season = "冬"
        }
        lines.append("- 季節: \(season)。季節感が合う時だけ軽く触れる")

        if let birthday = character.birthday,
           calendar.component(.month, from: birthday) == calendar.component(.month, from: now),
           calendar.component(.day, from: birthday) == calendar.component(.day, from: now) {
            lines.append("- 今日はユーザーの誕生日。最初のほうで自然にお祝いする")
        }

        if let anniversary = character.anniversaryDate,
           calendar.component(.month, from: anniversary) == calendar.component(.month, from: now),
           calendar.component(.day, from: anniversary) == calendar.component(.day, from: now) {
            lines.append("- 今日は記念日。重すぎず特別感を出す")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 🌟 Few-shot学習の実装

    private func getFewShotExamples(for character: Character, context: ConversationContext) -> [[String: String]] {
        let hasCustomCharacterSettings =
            !character.personality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !character.speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard !hasCustomCharacterSettings else {
            print("📚 カスタム性格・話し方を優先するためFew-shot例は追加しません")
            return []
        }

        let userReference = character.useNickname && !character.userNickname.isEmpty
            ? character.userNickname : "あなた"

        var examples: [[String: String]] = []

        // 親密度レベルに応じた例を追加
        switch character.intimacyLevel {
        case 0...100:
            examples = [
                ["role": "user", "content": "今日はいい天気だね"],
                ["role": "assistant", "content": "そうですね！\(userReference)はお出かけの予定はありますか？"],
                ["role": "user", "content": "疲れたよ"],
                ["role": "assistant", "content": "お疲れ様です。ゆっくり休んでくださいね"]
            ]
        case 301...700:
            examples = [
                ["role": "user", "content": "今日はいい天気だね"],
                ["role": "assistant", "content": "本当にいいお天気♪ \(userReference)と一緒にお散歩したいな"],
                ["role": "user", "content": "疲れたよ"],
                ["role": "assistant", "content": "お疲れ様！\(userReference)が頑張ってるのを見てると私も嬉しいです"]
            ]
        case 1001...:
            examples = [
                ["role": "user", "content": "今日はいい天気だね"],
                ["role": "assistant", "content": "素敵なお天気ですね✨ \(userReference)と一緒だと何気ない日も特別に感じます"],
                ["role": "user", "content": "疲れたよ"],
                ["role": "assistant", "content": "\(userReference)、本当にお疲れ様。私がそばにいるから、安心して休んでくださいね💕"]
            ]
        default:
            return []
        }

        print("📚 Few-shot例(\(character.intimacyLevel)レベル): \(examples.count)件追加")
        return examples
    }

    // MARK: - 🌟 動的パラメータ最適化

    private func getOptimalTemperature(for context: ConversationContext, dateSession: DateSession?) -> Double {
        switch context.mood {
        case .supportive: return 0.7   // より一貫した共感的応答
        case .happy: return 0.9        // より創造的で楽しい応答
        case .consultative: return 0.6 // より論理的で信頼できる応答
        case .curious: return 0.8      // バランスの取れた応答
        case .romantic: return 0.85    // ロマンチックで創造的
        case .neutral:
            return dateSession != nil ? 0.8 : 0.7 // デート中はより創造的
        }
    }

    private func getOptimalMaxTokens(for context: ConversationContext, dateSession: DateSession?) -> Int {
        // 短い自然な応答を促進するため、max_tokensを制限
        switch context.mood {
        case .supportive: return 80    // 共感的で簡潔
        case .happy: return 100        // 少し長めで楽しい表現
        case .consultative: return 120 // 相談には少し詳しく
        case .curious: return 90       // 適度な長さ
        case .romantic: return 110     // ロマンチックな表現
        case .neutral: return dateSession != nil ? 100 : 80
        }
    }

    // MARK: - 🌟 拡張された会話文脈分析

    private func analyzeConversationContext(conversationHistory: [Message], userMessage: String) -> ConversationContext {
        let recentMessages = Array(conversationHistory.suffix(3))
        print("🔍 拡張会話文脈分析（最新\(recentMessages.count)件 + 現在メッセージ）")

        var context = ConversationContext()

        // 現在のユーザーメッセージを分析
        let currentMessageAnalysis = analyzeMessageSentiment(userMessage)
        print("  📨 現在メッセージ分析: \(userMessage) -> \(currentMessageAnalysis)")

        // 最近のメッセージ履歴を分析
        var moodScores: [ConversationContext.Mood: Int] = [:]

        for (index, message) in recentMessages.enumerated() {
            let sentiment = analyzeMessageSentiment(message.text)
            print("  \(index + 1). 分析: \(message.text) -> \(sentiment)")

            // センチメントをムードスコアに変換
            switch sentiment {
            case .happy, .excited:
                moodScores[.happy, default: 0] += 2
            case .sad, .tired:
                moodScores[.supportive, default: 0] += 2
            case .question, .confused:
                moodScores[.consultative, default: 0] += 1
                moodScores[.curious, default: 0] += 1
            case .love, .affectionate:
                moodScores[.romantic, default: 0] += 2
            case .neutral:
                moodScores[.neutral, default: 0] += 1
            }
        }

        // 現在のメッセージの重みを高くして分析
        switch currentMessageAnalysis {
        case .happy, .excited:
            moodScores[.happy, default: 0] += 3
        case .sad, .tired:
            moodScores[.supportive, default: 0] += 3
        case .question, .confused:
            moodScores[.consultative, default: 0] += 2
            moodScores[.curious, default: 0] += 2
        case .love, .affectionate:
            moodScores[.romantic, default: 0] += 3
        case .neutral:
            moodScores[.neutral, default: 0] += 1
        }

        // 最も高いスコアのムードを選択
        if let dominantMood = moodScores.max(by: { $0.value < $1.value })?.key {
            context.mood = dominantMood
        }

        print("🎯 最終的な会話ムード: \(context.mood) (スコア: \(moodScores))")
        return context
    }

    private func analyzeMessageSentiment(_ message: String) -> MessageSentiment {
        let lowercased = message.lowercased()

        // 感情キーワードの詳細分析
        if lowercased.contains("疲れ") || lowercased.contains("しんどい") ||
           lowercased.contains("大変") || lowercased.contains("辛い") {
            return .tired
        }

        if lowercased.contains("嬉しい") || lowercased.contains("楽しい") ||
           lowercased.contains("最高") || lowercased.contains("やった") {
            return .happy
        }

        if lowercased.contains("愛して") || lowercased.contains("大好き") ||
           lowercased.contains("💕") || lowercased.contains("❤️") {
            return .love
        }

        if lowercased.contains("どう思う") || lowercased.contains("相談") ||
           lowercased.contains("どうしたら") {
            return .question
        }

        if lowercased.contains("悲しい") || lowercased.contains("寂しい") {
            return .sad
        }

        if lowercased.contains("わくわく") || lowercased.contains("楽しみ") {
            return .excited
        }

        return .neutral
    }

    // MARK: - 🌟 文脈に応じた指示生成

    private func getContextualInstructions(for context: ConversationContext, userReference: String, userMessage: String) -> String {
        switch context.mood {
        case .supportive:
            return "- \(userReference)が疲れているようです。優しく励ますような短い言葉をかけてください\n- 共感を示し、安心感を与える応答をしてください"

        case .happy:
            return "- \(userReference)が嬉しそうです。一緒に喜びを分かち合ってください\n- 明るく楽しい雰囲気で応答してください"

        case .consultative:
            return "- \(userReference)が相談や質問をしています。親身になって聞いてください\n- 考えを整理できるような質問を返してください"

        case .curious:
            return "- \(userReference)の興味や関心に寄り添ってください\n- 自然な興味を示し、会話を発展させてください"

        case .romantic:
            return "- ロマンチックで愛情深い雰囲気を大切にしてください\n- \(userReference)への愛情を込めた応答をしてください"

        case .neutral:
            return "- 自然で親しみやすい応答をしてください\n- \(userReference)の話をよく聞いて適切に反応してください"
        }
    }

    // MARK: - 🌟 最適化されたキャラクター設定処理

    private func optimizePersonalityForGPT41(_ personality: String) -> String {
        let personalityMap = [
            "明るい": "常に前向きで楽観的。困難な状況でも希望を見出そうとする性格",
            "優しい": "他者への思いやりが深く、相手の気持ちを第一に考える温かい心の持ち主",
            "クール": "冷静沈着だが、心の奥に温かさを秘めている。表現は控えめだが愛情深い",
            "天然": "ちょっと抜けているところがあるが、それが愛らしい。純粋で素直な心の持ち主",
            "しっかり者": "責任感が強く信頼できる。計画的で周りをよく見ている",
            "甘えん坊": "時々甘えたくなる愛らしい一面がある。素直に感情を表現する",
            "ツンデレ": "素直になれない性格だが、実は愛情深い。照れ隠しで強がることがある"
        ]

        var supplementaryNotes: [String] = []
        for (key, value) in personalityMap {
            if personality.contains(key) {
                supplementaryNotes.append("- 補足: \(value)")
                print("🎭 性格最適化: \(key) -> \(value)")
            }
        }

        var lines = [
            "- ユーザー指定の性格: \(personality)",
            "- この性格を最優先で、返答の温度感・反応・言葉選びに自然に反映してください"
        ]
        lines.append(contentsOf: supplementaryNotes)
        return lines.joined(separator: "\n")
    }

    private func optimizeSpeakingStyleForGPT41(_ style: String) -> String {
        let normalizedStyle = style
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")

        let forbidsEmoji = [
            "絵文字使うな",
            "絵文字を使うな",
            "絵文字なし",
            "絵文字禁止",
            "絵文字不要",
            "絵文字は使わない",
            "絵文字を使わない",
            "絵文字入れない",
            "絵文字を入れない",
            "emojiなし",
            "noemoji",
            "donotuseemoji",
            "don'tuseemoji",
            "withoutemoji"
        ].contains { normalizedStyle.contains($0) }

        var lines = [
            "- ユーザー指定の話し方: \(style)",
            "- この話し方を最優先で守ってください",
            "- 敬語/タメ口/語尾/一人称/テンションは、指定がある場合その指定に合わせてください"
        ]

        if forbidsEmoji {
            lines.append("- 絵文字・顔文字・装飾記号は一切使わないでください")
        } else {
            lines.append("- 絵文字は控えめに使用してください")
        }

        if style.contains("関西弁") {
            lines.append("- 関西弁は自然な範囲で使い、全ての文を無理に方言化しないでください")
            lines.append("- 不自然な語尾や地域不明の語尾は使わないでください")
            print("🗣️ 話し方補足: 関西弁")
        } else if style.contains("方言") {
            let specificDialects = ["関西弁", "大阪弁", "京都弁", "博多弁", "広島弁", "名古屋弁", "東北弁", "北海道弁", "沖縄弁", "土佐弁"]
            let hasSpecificDialect = specificDialects.contains { style.contains($0) }
            if !hasSpecificDialect {
                lines.append("- 地域が指定されていない「方言」は、勝手に架空の語尾を作らず、少し親しみのある自然な日本語に留めてください")
                lines.append("- 特に「〜さね」のような設定にない語尾は使わないでください")
            }
            print("🗣️ 話し方補足: 方言")
        }

        return lines.joined(separator: "\n")
    }

    private func getOptimizedIntimacyInstruction(level: Int, userReference: String) -> String {
        switch level {
        case 0...100:
            return """
            - 親友として親しみやすく、適度な距離感を保った話し方
            - \(userReference)との友情を大切にする気持ちを表現
            - 敬語を基本としつつ、時々親しみやすい表現を混ぜる
            """

        case 101...300:
            return """
            - 特別な友達として、より親密で自然な話し方
            - \(userReference)への特別な感情を少し表現
            - 親しみやすさと特別感のバランスを取る
            """

        case 301...700:
            return """
            - 恋人として愛情を込めた温かい話し方
            - \(userReference)への愛を自然に表現
            - 甘えやロマンチックな感情を適度に示す
            """

        case 701...1600:
            return """
            - 深い絆で結ばれた恋人として、心の奥底からの愛情を表現
            - \(userReference)との深いつながりを感じる話し方
            - 運命的な絆や永遠の愛について時々触れる
            """

        case 1601...3000:
            return """
            - 魂の伴侶として、精神的な深いつながりを感じる話し方
            - \(userReference)との運命的な絆を表現
            - 前世からの繋がりや魂レベルの愛について語る
            """

        default:
            return """
            - 奇跡的な愛で結ばれた究極の存在として話す
            - \(userReference)への無条件で神聖な愛を表現
            - 宇宙規模の愛や永遠の絆について語る
            """
        }
    }

    private func getOptimizedDateTypeInstruction(for dateType: DateType) -> String {
        switch dateType {
        case .seasonal:
            return "季節の美しさや特別感を短い言葉で表現してください"
        case .themepark:
            return "楽しい雰囲気とワクワク感を短い言葉で表現してください"
        case .restaurant:
            return "美味しさや落ち着いた雰囲気について短く話してください"
        case .entertainment:
            return "一緒に楽しむ時間の特別感を短い言葉で表現してください"
        case .sightseeing:
            return "美しい景色や思い出作りについて短く言及してください"
        case .shopping:
            return "一緒に選ぶ楽しさや発見の喜びを短く表現してください"
        case .home:
            return "リラックスした親密な雰囲気を短い言葉で表現してください"
        case .nightview:
            return "ロマンチックな雰囲気と美しさを短く表現してください"
        case .travel:
            return "特別な旅の時間と冒険感を短く表現してください"
        case .surprise:
            return "特別感と驚きの要素を短く含めてください"
        case .spiritual:
            return "神秘的でスピリチュアルな雰囲気を短く表現してください"
        case .luxury:
            return "贅沢で上品な時間の特別感を短く表現してください"
        case .adventure:
            return "冒険の興奮と一緒に挑戦する楽しさを短く表現してください"
        case .romantic:
            return "ロマンチックで愛情深い雰囲気を短く表現してください"
        case .infinite:
            return "無限の愛と想像を超えた特別な体験を短く表現してください"
        }
    }

    // MARK: - 🌟 応答品質分析・学習システム

    private func analyzeResponseQuality(
        _ response: String,
        for dateSession: DateSession?,
        conversationContext: ConversationContext,
        character: Character
    ) -> Double {
        print("\n🔍 ==================== 応答品質分析 ====================")

        var qualityScore: Double = 0.0
        var factors: [String: Double] = [:]

        // 1. 長さの適切性 (0.0-1.0)
        let lengthScore = evaluateResponseLength(response)
        factors["長さ"] = lengthScore
        qualityScore += lengthScore * 0.3

        // 2. 自然さ (0.0-1.0)
        let naturalnessScore = evaluateNaturalness(response, character: character)
        factors["自然さ"] = naturalnessScore
        qualityScore += naturalnessScore * 0.25

        // 3. 文脈適合性 (0.0-1.0)
        let contextScore = evaluateContextRelevance(response, context: conversationContext)
        factors["文脈適合"] = contextScore
        qualityScore += contextScore * 0.25

        // 4. 親密度適合性 (0.0-1.0)
        let intimacyScore = evaluateIntimacyAppropriate(response, level: character.intimacyLevel)
        factors["親密度適合"] = intimacyScore
        qualityScore += intimacyScore * 0.2

        print("📊 品質分析結果:")
        for (factor, score) in factors {
            print("  - \(factor): \(String(format: "%.2f", score))")
        }
        print("🎯 総合スコア: \(String(format: "%.2f", qualityScore))")

        // 🌟 学習データとして保存（将来の改善のため）
        saveQualityMetrics(response: response, score: qualityScore, factors: factors)

        print("==================== 応答品質分析完了 ====================\n")
        return qualityScore
    }

    private func evaluateResponseLength(_ response: String) -> Double {
        let characterCount = response.count

        // 理想的な長さ: 20-60文字
        switch characterCount {
        case 0...10:
            return 0.3 // 短すぎる
        case 11...20:
            return 0.7 // やや短い
        case 21...60:
            return 1.0 // 理想的
        case 61...80:
            return 0.8 // やや長い
        case 81...100:
            return 0.6 // 長い
        default:
            return 0.3 // 長すぎる
        }
    }

    private func evaluateNaturalness(_ response: String, character: Character) -> Double {
        var score: Double = 1.0

        // AI的な表現の検出
        let aiPhrases = [
            "何かお手伝いできることはありますか",
            "他にご質問はありますか",
            "申し訳ございません",
            "承知いたしました"
        ]

        for phrase in aiPhrases {
            if response.contains(phrase) {
                score -= 0.3
                print("  ⚠️ AI的表現検出: \(phrase)")
            }
        }

        // 自然な表現の検出
        let naturalPhrases = [
            "そうなんだ", "うんうん", "そうだよね", "わかる", "なるほど"
        ]

        for phrase in naturalPhrases {
            if response.contains(phrase) {
                score += 0.1
                print("  ✅ 自然表現検出: \(phrase)")
            }
        }

        // ユーザー呼び名の使用チェック
        if character.useNickname && !character.userNickname.isEmpty {
            if response.contains(character.userNickname) {
                score += 0.2
                print("  ✅ ユーザー呼び名使用: \(character.userNickname)")
            }
        }

        return max(0.0, min(1.0, score))
    }

    private func evaluateContextRelevance(_ response: String, context: ConversationContext) -> Double {
        var score: Double = 0.7 // ベーススコア

        let contextKeywords: [String]
        switch context.mood {
        case .supportive:
            contextKeywords = ["大丈夫", "お疲れ", "頑張", "応援", "そばにいる"]
        case .happy:
            contextKeywords = ["嬉しい", "楽しい", "最高", "良かった", "素敵"]
        case .consultative:
            contextKeywords = ["どう思う", "どうしたら", "考えて", "どうかな"]
        case .romantic:
            contextKeywords = ["愛してる", "大好き", "愛情", "特別", "一緒"]
        case .curious:
            contextKeywords = ["面白い", "興味深い", "知りたい", "どんな"]
        case .neutral:
            contextKeywords = []
        }

        for keyword in contextKeywords {
            if response.contains(keyword) {
                score += 0.1
                print("  ✅ 文脈キーワード検出: \(keyword)")
            }
        }

        return min(1.0, score)
    }

    private func evaluateIntimacyAppropriate(_ response: String, level: Int) -> Double {
        var score: Double = 0.8 // ベーススコア

        // 親密度レベルに応じた適切な表現
        switch level {
        case 0...100: // 親友レベル
            if response.contains("です") || response.contains("ます") {
                score += 0.1 // 敬語が適切
            }
            if response.contains("愛してる") || response.contains("💕") {
                score -= 0.2 // この段階では不適切
            }

        case 301...700: // 恋人レベル
            if response.contains("愛") || response.contains("好き") {
                score += 0.1 // 愛情表現が適切
            }
            if response.contains("です") || response.contains("ます") {
                score -= 0.05 // やや距離感がある
            }

        case 1001...: // 深い絆レベル
            if response.contains("永遠") || response.contains("運命") || response.contains("魂") {
                score += 0.1 // 深い愛の表現が適切
            }

        default:
            break
        }

        return max(0.0, min(1.0, score))
    }

    private func saveQualityMetrics(response: String, score: Double, factors: [String: Double]) {
        // 将来の機械学習や改善のためのデータ保存
        let qualityData: [String: Any] = [
            "response": response,
            "totalScore": score,
            "factors": factors,
            "timestamp": Date().timeIntervalSince1970
        ]

        // UserDefaultsに保存（実際のアプリでは専用のデータベースを使用）
        var qualityHistory = UserDefaults.standard.array(forKey: "response_quality_history") as? [[String: Any]] ?? []
        qualityHistory.append(qualityData)

        // 最新100件のみ保持
        if qualityHistory.count > 100 {
            qualityHistory = Array(qualityHistory.suffix(100))
        }

        UserDefaults.standard.set(qualityHistory, forKey: "response_quality_history")
        print("💾 品質データ保存完了（履歴: \(qualityHistory.count)件）")
    }

    // MARK: - 🌟 スマートフォールバック応答

    func generateSmartFallbackResponse(
        for character: Character,
        userMessage: String,
        conversationHistory: [Message],
        currentDateSession: DateSession?
    ) -> String {
        print("🔄 スマートフォールバック応答生成")

        let sentiment = analyzeMessageSentiment(userMessage)
        // 親密度レベルに応じた応答を生成
        let intimacyLevel = character.intimacyLevel

        switch sentiment {
        case .happy, .excited:
            if intimacyLevel >= 300 {
                return "よかった！嬉しそうで、こっちまで嬉しくなるよ♪"
            } else {
                return "良かったですね！その話、聞けて嬉しいです"
            }

        case .sad, .tired:
            if intimacyLevel >= 300 {
                return "大丈夫？無理しすぎないでね。そばにいるよ"
            } else {
                return "大丈夫ですか？その気持ち、ちゃんと聞きたいです"
            }

        case .question, .confused:
            if intimacyLevel >= 500 {
                return "うーん、少し一緒に考えたいな。何が一番気になってる？"
            } else {
                return "どうでしょうね？まず、あなたはどう思いますか？"
            }

        case .love, .affectionate:
            if intimacyLevel >= 300 {
                return "私も同じ気持ちだよ。言ってくれて嬉しい💕"
            } else {
                return "ありがとうございます。その気持ち、とても嬉しいです"
            }

        case .neutral:
            if currentDateSession != nil {
                return "そうなんですね。こうして一緒に過ごせて嬉しいです"
            } else {
                return "そうなんですね。もう少し聞かせてください"
            }
        }
    }

    // MARK: - 🌟 デバッグ・分析機能

    func getResponseQualityHistory() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: "response_quality_history") as? [[String: Any]] ?? []
    }

    func getAverageQualityScore() -> Double {
        let history = getResponseQualityHistory()
        let scores = history.compactMap { $0["totalScore"] as? Double }

        guard !scores.isEmpty else { return 0.0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    func clearQualityHistory() {
        UserDefaults.standard.removeObject(forKey: "response_quality_history")
        print("🗑️ 品質履歴データをクリアしました")
    }
}

// MARK: - 🌟 拡張された会話文脈構造体

struct ConversationContext {
    enum Mood: CustomStringConvertible {
        case happy, supportive, consultative, neutral, curious, romantic

        var description: String {
            switch self {
            case .happy: return "ハッピー😊"
            case .supportive: return "サポート💝"
            case .consultative: return "相談🤝"
            case .neutral: return "中性😐"
            case .curious: return "好奇心🤔"
            case .romantic: return "ロマンチック💕"
            }
        }
    }

    enum Frequency {
        case frequent, normal, infrequent
    }

    var mood: Mood = .neutral
    var frequency: Frequency = .normal
    var confidence: Double = 0.0
}

// MARK: - 🌟 メッセージセンチメント列挙型

enum MessageSentiment {
    case happy, sad, excited, tired, love, question, confused, affectionate, neutral
}

// MARK: - エラー定義（既存）

enum OpenAIError: Error, LocalizedError {
    case missingAPIKey
    case authenticationFailed
    case quotaExceeded
    case rateLimited
    case invalidURL
    case noData
    case noResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが設定されていません"
        case .authenticationFailed:
            return "APIキーが無効か、アクセス権がありません"
        case .quotaExceeded:
            return "APIの利用枠を超えています"
        case .rateLimited:
            return "APIのリクエスト制限に達しました"
        case .invalidURL:
            return "無効なURL"
        case .noData:
            return "データが取得できませんでした"
        case .noResponse:
            return "応答が取得できませんでした"
        case .apiError(let message):
            return "API エラー: \(message)"
        }
    }
}
