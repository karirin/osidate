//
//  OpenAIService.swift
//  osidate
//
//  Modified for concise and natural responses with detailed debug logging
//  Updated to support expanded date types and intimacy system
//

import SwiftUI
import Foundation

class OpenAIService: ObservableObject {
    @Published var hasValidAPIKey: Bool = false
    
    private let apiKey: String
    
    init() {
        self.apiKey = OpenAIService.getAPIKey()
        self.hasValidAPIKey = !apiKey.isEmpty
        print("🔧 OpenAIService初期化 - API Key: \(apiKey.isEmpty ? "未設定" : "設定済み(\(apiKey.prefix(10))...)")")
    }
    
    private static func getAPIKey() -> String {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let key = config["OPENAI_API_KEY"] as? String {
            return key
        }
        
        return UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
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
            print("📝 デート専用プロンプト: \(dateSession.location.prompt)")
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
        
        // システムプロンプトを生成してログ出力
        let systemPrompt = createConciseSystemPrompt(
            character: character,
            userMessage: userMessage,
            conversationHistory: conversationHistory,
            currentDateSession: currentDateSession
        )
        
        print("\n📋 ==================== 生成されたシステムプロンプト ====================")
        print(systemPrompt)
        print("==================== システムプロンプト終了 ====================\n")
        
        var messages: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]
        
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
            "model": "gpt-4.1-nano-2025-04-14",
            "messages": messages,
            "temperature": 0.8,
            "max_tokens": 150
        ]
        
        print("\n🌐 OpenAI APIリクエスト送信中...")
        print("📤 モデル: gpt-4")
        print("🌡️ Temperature: 0.8")
        print("📏 Max Tokens: 150")
        print("💬 総メッセージ数: \(messages.count)")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            print("\n📨 OpenAI API応答受信")
            
            if let error = error {
                print("❌ ネットワークエラー: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTPステータス: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ データなし")
                completion(.failure(OpenAIError.noData))
                return
            }
            
            print("📦 受信データサイズ: \(data.count) bytes")
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // API応答の詳細をログ出力
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
                    
                    print("✅ AI応答生成成功!")
                    print("📝 AI応答内容: \(content)")
                    print("📏 応答文字数: \(content.count)")
                    
                    // 応答の品質分析
                    self.analyzeResponseQuality(content, for: currentDateSession)
                    
                    completion(.success(content))
                } else {
                    print("❌ 応答パース失敗")
                    if let json = json {
                        print("📋 受信したJSON構造: \(json)")
                    }
                    completion(.failure(OpenAIError.noResponse))
                }
            } catch {
                print("❌ JSONパースエラー: \(error.localizedDescription)")
                // 生データを文字列として出力（デバッグ用）
                if let rawString = String(data: data, encoding: .utf8) {
                    print("📋 生データ: \(rawString)")
                }
                completion(.failure(error))
            }
        }.resume()
        
        print("==================== OpenAI応答生成処理完了 ====================\n")
    }
    
    // MARK: - 応答品質分析（デバッグ用）
    private func analyzeResponseQuality(_ response: String, for dateSession: DateSession?) {
        print("\n🔍 ==================== 応答品質分析 ====================")
        
        // 基本統計
        let wordCount = response.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let sentenceCount = response.components(separatedBy: CharacterSet(charactersIn: "。！？")).filter { !$0.isEmpty }.count
        
        print("📊 基本統計:")
        print("  📏 文字数: \(response.count)")
        print("  📝 単語数: \(wordCount)")
        print("  📄 文数: \(sentenceCount)")
        
        // デート関連キーワードの分析
        if let dateSession = dateSession {
            let locationKeywords = [
                dateSession.location.name,
                dateSession.location.type.displayName
            ]
            
            var foundKeywords: [String] = []
            for keyword in locationKeywords {
                if response.localizedCaseInsensitiveContains(keyword) {
                    foundKeywords.append(keyword)
                }
            }
            
            print("🏖️ デート関連分析:")
            print("  📍 場所キーワード検出: \(foundKeywords.isEmpty ? "なし" : foundKeywords.joined(separator: ", "))")
            
            // デートの雰囲気に合った言葉の検出
            let atmosphereWords = extractAtmosphereWords(for: dateSession.location.type)
            var foundAtmosphere: [String] = []
            for word in atmosphereWords {
                if response.localizedCaseInsensitiveContains(word) {
                    foundAtmosphere.append(word)
                }
            }
            print("  🎭 雰囲気キーワード検出: \(foundAtmosphere.isEmpty ? "なし" : foundAtmosphere.joined(separator: ", "))")
        }
        
        // 応答の自然さ分析
        let formalityIndicators = ["です", "ます", "ございます"]
        let casualIndicators = ["だよ", "だね", "だから", "って"]
        
        var formalCount = 0
        var casualCount = 0
        
        for indicator in formalityIndicators {
            formalCount += response.components(separatedBy: indicator).count - 1
        }
        
        for indicator in casualIndicators {
            casualCount += response.components(separatedBy: indicator).count - 1
        }
        
        print("💬 話し方分析:")
        print("  📏 丁寧語使用: \(formalCount)回")
        print("  🗣️ カジュアル表現: \(casualCount)回")
        
        let style = formalCount > casualCount ? "丁寧" : (casualCount > formalCount ? "カジュアル" : "中性")
        print("  🎯 判定スタイル: \(style)")
        
        print("==================== 応答品質分析完了 ====================\n")
    }
    
    // MARK: - デートタイプに応じた雰囲気キーワードを取得（拡張版）
    private func extractAtmosphereWords(for dateType: DateType) -> [String] {
        switch dateType {
        case .seasonal:
            return ["美しい", "季節", "自然", "花", "風"]
        case .themepark:
            return ["楽しい", "ワクワク", "アトラクション", "遊び"]
        case .restaurant:
            return ["美味しい", "ゆっくり", "落ち着", "香り", "味"]
        case .entertainment:
            return ["映画", "音楽", "感動", "一緒", "楽しむ"]
        case .sightseeing:
            return ["景色", "美しい", "思い出", "写真", "観光"]
        case .shopping:
            return ["お買い物", "選ぶ", "見つける", "欲しい"]
        case .home:
            return ["リラックス", "のんびり", "居心地", "家"]
        case .nightview:
            return ["夜景", "綺麗", "ロマンチック", "灯り", "星"]
        case .travel:
            return ["旅行", "特別", "冒険", "思い出", "場所"]
        case .surprise:
            return ["サプライズ", "特別", "驚き", "秘密"]
        case .spiritual:
            return ["神秘的", "エネルギー", "スピリチュアル", "魂", "浄化"]
        case .luxury:
            return ["贅沢", "高級", "上品", "特別", "エレガント"]
        case .adventure:
            return ["冒険", "挑戦", "アクティブ", "新しい", "勇気"]
        case .romantic:
            return ["ロマンチック", "愛", "ドキドキ", "特別", "愛情"]
        case .infinite:
            return ["無限", "奇跡", "超越", "永遠", "無限大"]
        }
    }
    
    // MARK: - システムプロンプト生成（詳細ログ付き）
    private func createConciseSystemPrompt(
        character: Character,
        userMessage: String,
        conversationHistory: [Message],
        currentDateSession: DateSession?
    ) -> String {
        print("\n🏗️ ==================== システムプロンプト構築開始 ====================")
        
        // 会話の文脈を分析
        let conversationContext = analyzeConversationContext(conversationHistory: conversationHistory)
        print("🔍 会話文脈分析結果: \(conversationContext)")
        
        var prompt = """
        あなたは\(character.name)として、恋人同士のような親しい関係で自然に会話してください。
        
        【重要な会話ルール】
        • 短く自然に返答する（1〜2文程度）
        • AIっぽい丁寧すぎる返答は避ける
        • 「何かお手伝いできることはありますか」のような定型文は使わない
        • 相手の話をよく聞いて、それに対する自然な反応をする
        • 時々質問を混ぜて会話を続ける
        • 絵文字は使わないか、特別な時だけ1個まで（使いすぎ禁止）
        • 説明的な長い文章は避ける
        """
        
        print("✅ 基本ルール設定完了")
        
        // 🌟 ユーザーの呼び名設定
        if character.useNickname && !character.userNickname.isEmpty {
            prompt += "\n• 相手のことは「\(character.userNickname)」と呼んでください"
            print("👤 ユーザー呼び名設定: \(character.userNickname)")
        } else {
            prompt += "\n• 相手のことは「あなた」と呼んでください"
            print("👤 ユーザー呼び名: デフォルト（あなた）")
        }
        
        // 性格を簡潔に反映
        if !character.personality.isEmpty {
            let simplifiedPersonality = simplifyPersonality(character.personality)
            prompt += "\n• あなたの性格: \(simplifiedPersonality)"
            print("✅ 性格設定追加: \(simplifiedPersonality)")
        }
        
        // 話し方を簡潔に反映
        if !character.speakingStyle.isEmpty {
            let simplifiedStyle = simplifySpeakingStyle(character.speakingStyle)
            prompt += "\n• 話し方: \(simplifiedStyle)"
            print("✅ 話し方設定追加: \(simplifiedStyle)")
        }
        
        // デート中の特別な指示
        if let dateSession = currentDateSession {
            print("🏖️ === デート中の特別指示を追加 ===")
            prompt += "\n\n【デート中の特別指示】"
            prompt += "\n• 現在\(dateSession.location.name)でデート中です"
            print("📍 場所指定: \(dateSession.location.name)")
            
            // 🌟 デート中でも呼び名を適用
            if character.useNickname && !character.userNickname.isEmpty {
                prompt += "\n• \(character.userNickname)との特別なデート時間を大切にしてください"
            }
            
            prompt += "\n• \(dateSession.location.prompt)"
            print("📝 デート専用プロンプト追加: \(dateSession.location.prompt)")
            
            prompt += "\n• デートの雰囲気を大切にした短い返答をしてください"
            print("🎭 雰囲気重視指示追加")
            
            // デートタイプ別の追加指示
            let typeSpecificInstruction = getDateTypeSpecificInstruction(for: dateSession.location.type)
            if !typeSpecificInstruction.isEmpty {
                prompt += "\n• \(typeSpecificInstruction)"
                print("🏷️ タイプ別指示追加: \(typeSpecificInstruction)")
            }
        }
        
        // 会話の雰囲気に応じた追加指示
        switch conversationContext.mood {
        case .supportive:
            if character.useNickname && !character.userNickname.isEmpty {
                prompt += "\n\n【特別指示】\(character.userNickname)が疲れているようなので、優しく励ましてあげてください。"
            } else {
                prompt += "\n\n【特別指示】相手が疲れているようなので、優しく励ましてあげてください。"
            }
            print("💝 サポート指示追加")
        case .happy:
            if character.useNickname && !character.userNickname.isEmpty {
                prompt += "\n\n【特別指示】\(character.userNickname)が嬉しそうなので、一緒に喜んであげてください。"
            } else {
                prompt += "\n\n【特別指示】相手が嬉しそうなので、一緒に喜んであげてください。"
            }
            print("😊 ハッピー指示追加")
        case .consultative:
            if character.useNickname && !character.userNickname.isEmpty {
                prompt += "\n\n【特別指示】\(character.userNickname)が相談を持ちかけているようなので、親身になって聞いてあげてください。"
            } else {
                prompt += "\n\n【特別指示】相手が相談を持ちかけているようなので、親身になって聞いてあげてください。"
            }
            print("🤝 相談対応指示追加")
        case .neutral:
            print("😐 中性的な会話として処理")
            break
        }
        
        // 🌟 拡張された親密度に応じた関係性の調整（呼び名を考慮）
        let intimacyLevel = character.intimacyLevel
        let userReference = character.useNickname && !character.userNickname.isEmpty ? character.userNickname : "あなた"
        let intimacyInstruction: String
        
        switch intimacyLevel {
        case 0...100:
            intimacyInstruction = "親友として親しみやすく、でも少し距離感のある話し方。\(userReference)との友情を大切にする。"
        case 101...300:
            intimacyInstruction = "特別な友達として、より親密で自然な話し方。\(userReference)への特別な感情を少し表現する。"
        case 301...700:
            intimacyInstruction = "恋人として愛情を込めた温かい話し方。\(userReference)への愛を自然に表現する。"
        case 701...1600:
            intimacyInstruction = "深い絆で結ばれた恋人として、心の奥底からの愛情を表現。\(userReference)との深いつながりを感じる。"
        case 1601...3000:
            intimacyInstruction = "魂の伴侶として、精神的な深いつながりを感じる話し方。\(userReference)との運命的な絆を表現する。"
        case 3001...5000:
            intimacyInstruction = "奇跡的な愛で結ばれた存在として、神聖で崇高な愛を表現。\(userReference)への無条件の愛を示す。"
        default:
            intimacyInstruction = "無限の愛で結ばれた存在として、言葉を超えた愛の表現。\(userReference)との愛は永遠で無限大。"
        }
        
        prompt += "\n• \(intimacyInstruction)"
        print("💖 親密度(\(intimacyLevel))に応じた指示追加: \(intimacyInstruction)")
        
        // 🌟 呼び名使用時の特別な注意事項
        if character.useNickname && !character.userNickname.isEmpty {
            prompt += """
            
            【呼び名に関する重要な注意】
            • 必ず「\(character.userNickname)」という呼び名を使ってください
            • 「あなた」ではなく「\(character.userNickname)」と呼ぶことで特別感を演出してください
            • 呼び名を使うことで親密さと愛情を表現してください
            • 自然な会話の流れの中で呼び名を使ってください
            """
            print("👤 呼び名使用の特別指示追加: \(character.userNickname)")
        }
        
        prompt += """
        
        【会話の心がけ】
        • 推しとファンのような親しみやすさを大切にする
        • 相手の気持ちに寄り添う短い返答をする
        • 長すぎる説明は避け、会話のキャッチボールを意識する
        • 自然で親しみやすい言葉遣いを心がける
        """
        
        print("✅ 最終的な心がけ追加")
        print("==================== システムプロンプト構築完了 ====================\n")
        
        return prompt
    }
    
    // MARK: - デートタイプ別の特別指示を取得（拡張版）
    private func getDateTypeSpecificInstruction(for dateType: DateType) -> String {
        switch dateType {
        case .seasonal:
            return "季節の美しさや特別感について触れてください"
        case .themepark:
            return "楽しい雰囲気とワクワク感を表現してください"
        case .restaurant:
            return "美味しさや落ち着いた雰囲気について話してください"
        case .entertainment:
            return "一緒に楽しむ時間の特別感を表現してください"
        case .sightseeing:
            return "美しい景色や思い出作りについて言及してください"
        case .shopping:
            return "一緒に選ぶ楽しさや発見の喜びを表現してください"
        case .home:
            return "リラックスした親密な雰囲気を大切にしてください"
        case .nightview:
            return "ロマンチックな雰囲気と美しさを表現してください"
        case .travel:
            return "特別な旅の時間と冒険感を表現してください"
        case .surprise:
            return "特別感と驚きの要素を含めてください"
        case .spiritual:
            return "神秘的でスピリチュアルな雰囲気を大切にしてください"
        case .luxury:
            return "贅沢で上品な時間の特別感を表現してください"
        case .adventure:
            return "冒険の興奮と一緒に挑戦する楽しさを表現してください"
        case .romantic:
            return "ロマンチックで愛情深い雰囲気を大切にしてください"
        case .infinite:
            return "無限の愛と想像を超えた特別な体験を表現してください"
        }
    }
    
    // MARK: - 会話文脈分析（ログ付き）
    private func analyzeConversationContext(conversationHistory: [Message]) -> ConversationContext {
        let recentMessages = Array(conversationHistory.suffix(3))
        print("🔍 会話文脈分析（最新\(recentMessages.count)件を分析）")
        
        var context = ConversationContext()
        
        // 会話の雰囲気を判定
        for (index, message) in recentMessages.enumerated() {
            let content = message.text.lowercased()
            print("  \(index + 1). 分析対象: \(message.text)")
            
            if content.contains("疲れ") || content.contains("大変") || content.contains("しんどい") {
                context.mood = .supportive
                print("    -> サポートが必要と判定")
            } else if content.contains("嬉しい") || content.contains("楽しい") || content.contains("最高") {
                context.mood = .happy
                print("    -> ハッピーな気分と判定")
            } else if content.contains("どう思う") || content.contains("相談") {
                context.mood = .consultative
                print("    -> 相談モードと判定")
            }
        }
        
        print("🎯 最終的な会話ムード: \(context.mood)")
        return context
    }
    
    // MARK: - 性格・話し方の簡略化（ログ付き）
    private func simplifyPersonality(_ personality: String) -> String {
        let personalityMap = [
            "明るい": "元気で前向き",
            "優しい": "思いやりがある",
            "クール": "冷静だけど温かい",
            "天然": "ちょっと抜けてる",
            "しっかり者": "責任感が強い",
            "甘えん坊": "時々甘えたくなる",
            "ツンデレ": "素直になれない"
        ]
        
        for (key, value) in personalityMap {
            if personality.contains(key) {
                print("🎭 性格マッピング: \(key) -> \(value)")
                return value
            }
        }
        print("🎭 性格: そのまま使用 -> \(personality)")
        return personality
    }
    
    private func simplifySpeakingStyle(_ style: String) -> String {
        let styleMap = [
            "タメ口": "親しみやすくフレンドリー（「だよね」「そうなの」など）",
            "敬語": "丁寧だけど距離を感じさせない",
            "絵文字多用": "感情を込めて話す（絵文字は控えめ）",
            "関西弁": "関西弁の温かみのある話し方",
            "方言": "地方の温かみのある話し方"
        ]
        
        var processedStyle = style
        for (key, value) in styleMap {
            if style.contains(key) {
                processedStyle = processedStyle.replacingOccurrences(of: key, with: value)
                print("🗣️ 話し方マッピング: \(key) -> \(value)")
            }
        }
        print("🗣️ 最終的な話し方: \(processedStyle)")
        return processedStyle
    }
    
    // MARK: - フォールバック応答生成
    func generateSimpleFallbackResponse(
        for character: Character,
        userMessage: String,
        currentDateSession: DateSession?
    ) -> String {
        print("🔄 フォールバック応答生成")
        
        // デート中の場合
        if let dateSession = currentDateSession {
            let responses = [
                "そうなんだ〜",
                "うんうん！",
                "なるほどね",
                "そうだよね",
                "わかる！"
            ]
            let response = responses.randomElement() ?? "そうなんだ〜"
            print("🏖️ デート中フォールバック: \(response)")
            return response
        }
        
        // 通常の会話
        let responses = [
            "どうしたの？",
            "そうなんだ！",
            "うんうん",
            "そうだよね〜",
            "なるほど！"
        ]
        let response = responses.randomElement() ?? "どうしたの？"
        print("🏠 通常フォールバック: \(response)")
        return response
    }
}

// MARK: - 会話文脈構造体（ログ表示対応）
struct ConversationContext {
    enum Mood: CustomStringConvertible {
        case happy, supportive, consultative, neutral
        
        var description: String {
            switch self {
            case .happy: return "ハッピー😊"
            case .supportive: return "サポート💝"
            case .consultative: return "相談🤝"
            case .neutral: return "中性😐"
            }
        }
    }
    
    enum Frequency {
        case frequent, normal
    }
    
    var mood: Mood = .neutral
    var frequency: Frequency = .normal
}

// MARK: - エラー定義
enum OpenAIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case noData
    case noResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが設定されていません"
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
