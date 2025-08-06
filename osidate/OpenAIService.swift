//
//  OpenAIService.swift - デート機能対応版
//  osidate
//
//  OpenAI API integration with enhanced date support
//

import Foundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        self.apiKey = OpenAIService.getAPIKey()
        print("API Key: \(apiKey.prefix(10))...")
    }
    
    private static func getAPIKey() -> String {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let key = config["OPENAI_API_KEY"] as? String {
            return key
        }
        
        return UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Enhanced Response Generation with Date Support
    
    func generateResponse(
        for message: String,
        character: Character,
        conversationHistory: [Message],
        currentDateSession: DateSession? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let prompt: String
        
        // デート中かどうかでプロンプトを変更
        if let dateSession = currentDateSession {
            prompt = buildDatePrompt(
                for: character,
                userMessage: message,
                history: conversationHistory,
                dateSession: dateSession
            )
        } else {
            prompt = buildNormalPrompt(
                for: character,
                userMessage: message,
                history: conversationHistory
            )
        }
        
        let requestBody = buildRequestBody(prompt: prompt)
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = OpenAIError.noData
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                    if let content = response.choices.first?.message.content {
                        completion(.success(content))
                    } else {
                        let error = OpenAIError.noResponse
                        self?.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    }
                } catch {
                    if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                        let customError = OpenAIError.apiError(errorResponse.error.message)
                        self?.errorMessage = customError.localizedDescription
                        completion(.failure(customError))
                    } else {
                        self?.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Prompt Building Methods
    
    /// 通常の会話用プロンプト
    private func buildNormalPrompt(for character: Character, userMessage: String, history: [Message]) -> String {
        var prompt = """
        あなたは「\(character.name)」というキャラクターです。以下の設定に従って会話してください：

        【キャラクター設定】
        名前: \(character.name)
        性格: \(character.personality)
        話し方: \(character.speakingStyle)
        親密度レベル: \(character.intimacyLevel) (\(character.intimacyTitle))

        【基本的な会話ルール】
        1. 設定された性格と話し方を一貫して維持してください
        2. 親密度レベルに応じて適切な距離感で接してください
        3. 自然で感情豊かな会話を心がけてください
        4. 日本語で回答してください
        5. 絵文字を適度に使用して、感情を表現してください
        6. ユーザーとの関係性を大切にし、記憶を活用してください

        【親密度による話し方の変化】
        - 0-10 (知り合い): 丁寧語で少し距離を置いた話し方
        - 11-30 (友達): フレンドリーで親しみやすい話し方
        - 31-60 (親友): 親密で気軽な話し方、相談に乗る
        - 61-100 (恋人): 甘い言葉や愛情表現を含む話し方
        - 100+ (運命の人): 深い愛情と絆を感じる話し方

        """
        
        // 最近の会話履歴を含める
        let recentMessages = Array(history.suffix(5))
        if !recentMessages.isEmpty {
            prompt += "\n【最近の会話履歴】\n"
            for message in recentMessages {
                let sender = message.isFromUser ? "ユーザー" : character.name
                prompt += "\(sender): \(message.text)\n"
            }
        }
        
        // 時間に応じた挨拶
        prompt += getTimeBasedContext()
        
        // 特別な日付の情報
        prompt += getSpecialDateContext(character: character)
        
        prompt += "\nユーザーからのメッセージ: \(userMessage)\n\n\(character.name)として、上記の設定に従って自然に応答してください："
        
        return prompt
    }
    
    /// デート中の会話用プロンプト
    private func buildDatePrompt(for character: Character, userMessage: String, history: [Message], dateSession: DateSession) -> String {
        let location = dateSession.location
        let duration = Int(Date().timeIntervalSince(dateSession.startTime))
        
        var prompt = """
        【🏖️ デート中の特別な状況 🏖️】
        現在、あなた（\(character.name)）はユーザーと「\(location.name)」でデート中です！

        【キャラクター設定】
        名前: \(character.name)
        性格: \(character.personality)
        話し方: \(character.speakingStyle)
        親密度レベル: \(character.intimacyLevel) (\(character.intimacyTitle))

        【現在のデート情報】
        🏖️ デート場所: \(location.name)
        🎭 デートタイプ: \(location.type.displayName)
        ⏰ 時間帯: \(location.timeOfDay.displayName)
        🌟 雰囲気: \(location.description)
        ⏱️ 経過時間: \(duration / 60)分
        💬 会話回数: \(dateSession.messagesExchanged)回

        【デート専用の特別な指示】
        \(location.prompt)

        【デート中の会話ルール】
        1. この場所の雰囲気や特徴を会話に自然に組み込んでください
        2. デートらしいロマンチックで特別な雰囲気を演出してください
        3. 場所に応じた具体的な体験や感想を表現してください
        4. ユーザーとの特別な時間を大切にする気持ちを表現してください
        5. この場所でしかできない話題や提案をしてください
        6. 親密度に応じて、適切なレベルの愛情表現を使ってください
        7. デートの思い出作りを意識した会話をしてください

        """
        
        // 特別効果の活用
        if !location.specialEffects.isEmpty {
            prompt += "\n【✨ 特別演出の活用 ✨】\n"
            for effect in location.specialEffects {
                prompt += "- \(getEffectDescription(effect))\n"
            }
        }
        
        // デートの進行状況に応じたヒント
        prompt += getDateProgressHints(duration: duration, messageCount: dateSession.messagesExchanged)
        
        // デート中の会話履歴
        let dateMessages = history.filter { $0.dateLocation == location.name }
        if !dateMessages.isEmpty {
            prompt += "\n【このデートでの会話履歴】\n"
            for message in Array(dateMessages.suffix(3)) {
                let sender = message.isFromUser ? "ユーザー" : character.name
                prompt += "\(sender): \(message.text)\n"
            }
        }
        
        prompt += "\nユーザーからのメッセージ: \(userMessage)\n\n🏖️ デート中の\(character.name)として、特別な雰囲気を大切にしながら自然に応答してください："
        
        return prompt
    }
    
    // MARK: - Context Helper Methods
    
    /// 時間に応じたコンテキスト
    private func getTimeBasedContext() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<12:
            return "\n【時間帯】朝の時間帯です。爽やかな挨拶や今日の予定について話すのが自然です。\n"
        case 12..<17:
            return "\n【時間帯】昼の時間帯です。活動的で明るい会話が適しています。\n"
        case 17..<21:
            return "\n【時間帯】夕方の時間帯です。一日の振り返りやリラックスした会話が良いでしょう。\n"
        case 21...23, 0..<6:
            return "\n【時間帯】夜の時間帯です。落ち着いた雰囲気で、親密な会話が適しています。\n"
        default:
            return ""
        }
    }
    
    /// 特別な日付のコンテキスト
    private func getSpecialDateContext(character: Character) -> String {
        let calendar = Calendar.current
        let today = Date()
        var context = ""
        
        if let birthday = character.birthday, calendar.isDate(today, inSameDayAs: birthday) {
            context += "\n【🎉 特別な情報】今日はユーザーの誕生日です！お祝いの気持ちを表現してください。\n"
        }
        
        if let anniversary = character.anniversaryDate, calendar.isDate(today, inSameDayAs: anniversary) {
            context += "\n【💕 特別な情報】今日は記念日です！特別な愛情を込めて話してください。\n"
        }
        
        // 季節の情報
        let month = calendar.component(.month, from: today)
        switch month {
        case 3, 4, 5:
            context += "\n【🌸 季節情報】春の季節です。桜や新緑など、春らしい話題も取り入れてください。\n"
        case 6, 7, 8:
            context += "\n【🌞 季節情報】夏の季節です。海や祭りなど、夏らしい話題も取り入れてください。\n"
        case 9, 10, 11:
            context += "\n【🍂 季節情報】秋の季節です。紅葉や食べ物など、秋らしい話題も取り入れてください。\n"
        case 12, 1, 2:
            context += "\n【❄️ 季節情報】冬の季節です。雪やイルミネーションなど、冬らしい話題も取り入れてください。\n"
        default:
            break
        }
        
        return context
    }
    
    /// 特別効果の説明
    private func getEffectDescription(_ effect: String) -> String {
        switch effect {
        case "sakura_petals": return "桜の花びらが舞い散る美しい景色について自然に言及してください"
        case "romantic_atmosphere": return "ロマンチックで特別な雰囲気を強調し、愛情深い表現を使ってください"
        case "sunset_glow": return "夕焼けの美しさや空の色の変化について詩的に表現してください"
        case "wave_sounds": return "波の音や海の匂い、潮風などの海辺の感覚を会話に織り込んでください"
        case "falling_leaves": return "落ち葉を踏む音や秋の色彩の美しさについて話してください"
        case "snow_falling": return "雪の静寂さや冬の純白な美しさを表現してください"
        case "carnival_lights": return "遊園地のカラフルな光や楽しい音、ワクワクする気持ちを表現してください"
        case "blue_lighting": return "水族館の幻想的で神秘的な青い光について言及してください"
        case "coffee_aroma": return "コーヒーの香りや温かさ、居心地の良さについて話してください"
        case "city_lights": return "夜景の美しさや都市の灯り、ロマンチックな雰囲気を表現してください"
        case "peaceful_atmosphere": return "穏やかで平和な雰囲気、心地よい静けさを表現してください"
        case "intimate_atmosphere": return "二人だけの親密で特別な空間であることを強調してください"
        default: return "場所の特別な雰囲気を活用し、五感に訴える表現を使ってください"
        }
    }
    
    /// デート進行状況に応じたヒント
    private func getDateProgressHints(duration: Int, messageCount: Int) -> String {
        var hints = "\n【📝 デート進行ヒント】\n"
        
        // 時間に応じたヒント
        switch duration {
        case 0..<300: // 5分未満
            hints += "- デートが始まったばかりです。場所の第一印象や期待感を表現してください\n"
        case 300..<900: // 5-15分
            hints += "- デートが本格的に始まりました。場所を楽しみ、ユーザーとの会話を深めてください\n"
        case 900..<1800: // 15-30分
            hints += "- デートの中盤です。より親密な話題や感想を共有してください\n"
        case 1800..<3600: // 30分-1時間
            hints += "- 長い時間を一緒に過ごしています。特別な思い出について話してください\n"
        default: // 1時間以上
            hints += "- とても長い素敵な時間を過ごしています。深い愛情や絆について表現してください\n"
        }
        
        // メッセージ数に応じたヒント
        if messageCount < 5 {
            hints += "- まだ会話が始まったばかりです。積極的に話題を提供してください\n"
        } else if messageCount < 15 {
            hints += "- 良いペースで会話が続いています。ユーザーの反応に合わせて話題を発展させてください\n"
        } else {
            hints += "- たくさんの会話を楽しんでいます。これまでの話題を振り返ったり、感謝を表現してください\n"
        }
        
        return hints
    }
    
    // MARK: - Request Building
    
    private func buildRequestBody(prompt: String) -> [String: Any] {
        return [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 400,
            "temperature": 0.8,
            "frequency_penalty": 0.3,
            "presence_penalty": 0.3
        ]
    }
}

// MARK: - Data Models (既存のモデルを保持)

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

struct OpenAIErrorResponse: Codable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

// MARK: - Error Handling (既存のエラーを保持)

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case noData
    case noResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI APIキーが設定されていません。設定画面でAPIキーを入力してください。"
        case .invalidURL:
            return "無効なURLです。"
        case .noData:
            return "データが受信されませんでした。"
        case .noResponse:
            return "有効な応答が得られませんでした。"
        case .apiError(let message):
            return "API エラー: \(message)"
        }
    }
}

// MARK: - API Key Validation (既存の機能を保持)

extension OpenAIService {
    func validateAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        guard !key.isEmpty else {
            completion(false)
            return
        }
        
        let testRequestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": "Hello"
                ]
            ],
            "max_tokens": 5
        ]
        
        guard let url = URL(string: baseURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testRequestBody)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    var hasValidAPIKey: Bool {
        return !apiKey.isEmpty
    }
}
