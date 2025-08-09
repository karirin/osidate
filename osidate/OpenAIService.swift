//
//  OpenAIService.swift
//  osidate
//
//  Modified for concise and natural responses like AIMessageGenerator
//
import SwiftUI
import Foundation

class OpenAIService: ObservableObject {
    @Published var hasValidAPIKey: Bool = false
    
    private let apiKey: String
    
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
    
//    private func loadAPIKey() {
//        // Info.plistからAPIキーを読み込み（元のプロジェクトと同じ方法）
//        if let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String, !key.isEmpty {
//            print("✅ Info.plistからAPIキーを読み込み成功")
//            apiKey = key
//        } else {
//            print("❌ Info.plistからOPENAI_API_KEYが見つかりません")
//
//            // 代替方法：UserDefaultsから読み込み（設定画面で保存されている場合）
//            if let userKey = UserDefaults.standard.string(forKey: "openai_api_key"), !userKey.isEmpty {
//                print("✅ UserDefaultsからAPIキーを読み込み成功")
//                apiKey = userKey
//            } else {
//                print("❌ UserDefaultsからもAPIキーが見つかりません")
//                // デバッグ用：Info.plistの内容を確認
//                print("📋 Info.plist内容:")
//                if let infoPlist = Bundle.main.infoDictionary {
//                    for (key, value) in infoPlist {
//                        if key.contains("API") || key.contains("KEY") {
//                            print("  \(key): \(value)")
//                        }
//                    }
//                }
//            }
//        }
//    }
    
    // APIキーを手動で設定する方法も追加
//    func setAPIKey(_ key: String) {
//        apiKey = key
//        UserDefaults.standard.set(key, forKey: "openai_api_key")
//        UserDefaults.standard.synchronize()
//        print("✅ APIキーが手動で設定されました")
//    }
    
    func generateResponse(
        for userMessage: String,
        character: Character,
        conversationHistory: [Message],
        currentDateSession: DateSession?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // AIMessageGeneratorスタイルのシステムプロンプトを作成
        let systemPrompt = createConciseSystemPrompt(
            character: character,
            userMessage: userMessage,
            conversationHistory: conversationHistory,
            currentDateSession: currentDateSession
        )
        
        var messages: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]
        
        // 最近の会話履歴を追加（最新5件のみ）
        for message in conversationHistory.suffix(5) {
            messages.append([
                "role": message.isFromUser ? "user" : "assistant",
                "content": message.text
            ])
        }
        
        messages.append(["role": "user", "content": userMessage])
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": messages,
            "temperature": 0.8,
            "max_tokens": 150 // 簡潔な応答のために制限
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(OpenAIError.noData))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let choices = json?["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    completion(.failure(OpenAIError.noResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - AIMessageGeneratorスタイルの簡潔なプロンプト作成
    private func createConciseSystemPrompt(
        character: Character,
        userMessage: String,
        conversationHistory: [Message],
        currentDateSession: DateSession?
    ) -> String {
        // 会話の文脈を分析
        let conversationContext = analyzeConversationContext(conversationHistory: conversationHistory)
        
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
        
        // 性格を簡潔に反映
        if !character.personality.isEmpty {
            let simplifiedPersonality = simplifyPersonality(character.personality)
            prompt += "\n• あなたの性格: \(simplifiedPersonality)"
        }
        
        // 話し方を簡潔に反映
        if !character.speakingStyle.isEmpty {
            let simplifiedStyle = simplifySpeakingStyle(character.speakingStyle)
            prompt += "\n• 話し方: \(simplifiedStyle)"
        }
        
        // デート中の特別な指示
        if let dateSession = currentDateSession {
            prompt += "\n\n【デート中の特別指示】"
            prompt += "\n• 現在\(dateSession.location.name)でデート中です"
            prompt += "\n• \(dateSession.location.prompt)"
            prompt += "\n• デートの雰囲気を大切にした短い返答をしてください"
        }
        
        // 会話の雰囲気に応じた追加指示
        switch conversationContext.mood {
        case .supportive:
            prompt += "\n\n【特別指示】相手が疲れているようなので、優しく励ましてあげてください。"
        case .happy:
            prompt += "\n\n【特別指示】相手が嬉しそうなので、一緒に喜んであげてください。"
        case .consultative:
            prompt += "\n\n【特別指示】相手が相談を持ちかけているようなので、親身になって聞いてあげてください。"
        case .neutral:
            break
        }
        
        // 親密度に応じた関係性の調整
        let intimacyLevel = character.intimacyLevel
        switch intimacyLevel {
        case 0...20:
            prompt += "\n• まだ知り合ったばかりなので、少し距離感のある親しみやすい話し方"
        case 21...50:
            prompt += "\n• 友達として親しくなってきたので、自然でフレンドリーな話し方"
        case 51...80:
            prompt += "\n• 親友のように親密になったので、気を遣わない自然な話し方"
        case 81...100:
            prompt += "\n• 恋人同士のような特別な関係なので、愛情を込めた温かい話し方"
        default:
            break
        }
        
        prompt += """
        
        【会話の心がけ】
        • 推しとファンのような親しみやすさを大切にする
        • 相手の気持ちに寄り添う短い返答をする
        • 長すぎる説明は避け、会話のキャッチボールを意識する
        • 自然で親しみやすい言葉遣いを心がける
        """
        
        return prompt
    }
    
    // MARK: - 会話文脈分析（AIMessageGeneratorから移植）
    private func analyzeConversationContext(conversationHistory: [Message]) -> ConversationContext {
        let recentMessages = Array(conversationHistory.suffix(3))
        
        var context = ConversationContext()
        
        // 会話の雰囲気を判定
        for message in recentMessages {
            let content = message.text.lowercased()
            
            if content.contains("疲れ") || content.contains("大変") || content.contains("しんどい") {
                context.mood = .supportive
            } else if content.contains("嬉しい") || content.contains("楽しい") || content.contains("最高") {
                context.mood = .happy
            } else if content.contains("どう思う") || content.contains("相談") {
                context.mood = .consultative
            }
        }
        
        return context
    }
    
    // MARK: - 性格・話し方の簡略化
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
                return value
            }
        }
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
            processedStyle = processedStyle.replacingOccurrences(of: key, with: value)
        }
        return processedStyle
    }
    
    // MARK: - フォールバック応答生成
    func generateSimpleFallbackResponse(
        for character: Character,
        userMessage: String,
        currentDateSession: DateSession?
    ) -> String {
        // デート中の場合
        if let dateSession = currentDateSession {
            let responses = [
                "そうなんだ〜",
                "うんうん！",
                "なるほどね",
                "そうだよね",
                "わかる！"
            ]
            return responses.randomElement() ?? "そうなんだ〜"
        }
        
        // 通常の会話
        let responses = [
            "どうしたの？",
            "そうなんだ！",
            "うんうん",
            "そうだよね〜",
            "なるほど！"
        ]
        return responses.randomElement() ?? "どうしたの？"
    }
}

// MARK: - 会話文脈構造体（AIMessageGeneratorから移植）
struct ConversationContext {
    enum Mood {
        case happy, supportive, consultative, neutral
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

//struct TestView_Previews: PreviewProvider {
//
//    static var previews: some View {
////        ContentView()
//        TopView()
//    }
//}
