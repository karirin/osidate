//
//  OpenAIService.swift
//  osidate
//
//  OpenAI API integration for character-based chat responses
//

import Foundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        // APIキーを取得（環境変数または設定から）
        self.apiKey = OpenAIService.getAPIKey()
        print("API Key: \(apiKey.prefix(10))...")
    }
    
    private static func getAPIKey() -> String {
        // 本番環境では、Info.plistまたは環境変数から取得することを推奨
        // 現在はデバッグ用の空文字列を返す
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let key = config["OPENAI_API_KEY"] as? String {
            return key
        }
        
        // フォールバック: UserDefaultsから取得（設定画面で入力可能にする）
        return UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
        UserDefaults.standard.synchronize()
    }
    
    func generateResponse(
        for message: String,
        character: Character,
        conversationHistory: [Message],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let prompt = buildPrompt(for: character, userMessage: message, history: conversationHistory)
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
                    // エラーレスポンスの場合の処理
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
    
    private func buildPrompt(for character: Character, userMessage: String, history: [Message]) -> String {
        var prompt = """
        あなたは「\(character.name)」というキャラクターです。以下の設定に従って会話してください：

        【キャラクター設定】
        名前: \(character.name)
        性格: \(character.personality)
        話し方: \(character.speakingStyle)
        親密度レベル: \(character.intimacyLevel) (\(character.intimacyTitle))

        【会話のルール】
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
        
        // 最近の会話履歴を含める（最大5件）
        let recentMessages = Array(history.suffix(5))
        if !recentMessages.isEmpty {
            prompt += "\n【最近の会話履歴】\n"
            for message in recentMessages {
                let sender = message.isFromUser ? "ユーザー" : character.name
                prompt += "\(sender): \(message.text)\n"
            }
        }
        
        // 特別な日付の情報
        let calendar = Calendar.current
        let today = Date()
        
        if let birthday = character.birthday, calendar.isDate(today, inSameDayAs: birthday) {
            prompt += "\n【特別な情報】今日はユーザーの誕生日です！🎉\n"
        }
        
        if let anniversary = character.anniversaryDate, calendar.isDate(today, inSameDayAs: anniversary) {
            prompt += "\n【特別な情報】今日は記念日です！💕\n"
        }
        
        prompt += "\nユーザーからのメッセージ: \(userMessage)\n\n\(character.name)として、上記の設定に従って自然に応答してください："
        
        return prompt
    }
    
    private func buildRequestBody(prompt: String) -> [String: Any] {
        return [
            "model": "gpt-4.1-nano-2025-04-14",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.8,
            "frequency_penalty": 0.3,
            "presence_penalty": 0.3
        ]
    }
}

// MARK: - Data Models

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

// MARK: - Error Handling

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

// MARK: - API Key Validation

extension OpenAIService {
    func validateAPIKey(_ key: String, completion: @escaping (Bool) -> Void) {
        guard !key.isEmpty else {
            completion(false)
            return
        }
        
        // 簡単なテストリクエストでAPIキーを検証
        let testRequestBody: [String: Any] = [
            "model": "gpt-4.1-nano-2025-04-14",
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
