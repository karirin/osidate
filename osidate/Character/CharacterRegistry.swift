//
//  CharacterRegistry.swift - より安全な同期版
//  Thread-safe なサブスクリプション状態管理
//

import SwiftUI
import Foundation
import FirebaseDatabase
import FirebaseAuth
import Combine

// MARK: - Character Registry（複数キャラクター管理）
@MainActor
class CharacterRegistry: ObservableObject {
    @Published var characters: [Character] = []
    @Published var activeCharacterId: String = ""
    @Published var isLoading: Bool = false
    
    // 🌟 サブスクリプション制限関連
    @Published var showingSubscriptionRequired = false
    @Published var showingCharacterLimitAlert = false
    
    // 🌟 サブスクリプション状態をローカルで管理
    @Published private var isSubscribed: Bool = false
    
    private let database = Database.database().reference()
    private var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // 🌟 制限設定
    private let freeMaxCharacters = 3  // 無料版では3人まで
    
    // Combine用
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCharacters()
        setupSubscriptionObserver()
    }
    
    // MARK: - 🌟 サブスクリプション状態監視
    private func setupSubscriptionObserver() {
        // SubscriptionManagerの状態変化を監視
        SubscriptionManager.shared.$isSubscribed
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSubscribed)
        
        // 初期状態を設定
        Task {
            await MainActor.run {
                self.isSubscribed = SubscriptionManager.shared.isSubscribed
            }
        }
    }
    
    // MARK: - Character Management
    
    /// 🌟 新しいキャラクターを作成（サブスク制限チェック付き）
    func createNewCharacter(name: String, personality: String, speakingStyle: String) -> Character? {
        print("🎭 新キャラクター作成要求: \(name)")
        print("   - 現在のキャラクター数: \(characters.count)")
        print("   - 制限数: \(freeMaxCharacters)")
        print("   - サブスク状態: \(isSubscribed)")
        
        // 🌟 サブスクリプション制限チェック
        if !isSubscribed && characters.count >= freeMaxCharacters {
            print("❌ キャラクター数制限に達しました")
            showingCharacterLimitAlert = true
            return nil
        }
        
        let character = Character(
            name: name,
            personality: personality,
            speakingStyle: speakingStyle,
            iconName: "person.circle.fill",
            backgroundName: "defaultBG"
        )
        
        if let userID = Auth.auth().currentUser?.uid,
           ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"].contains(userID) {
            character.intimacyLevel = 3000
            print("🎯 特別ユーザー検出: キャラクター作成時に親密度を3000に設定")
        }
        
        characters.append(character)
        saveCharacter(character)
        
        print("✅ キャラクター作成成功: \(name) (総数: \(characters.count))")
        return character
    }
    
    /// 🌟 キャラクター作成可否をチェック
    func canCreateNewCharacter() -> Bool {
        return isSubscribed || characters.count < freeMaxCharacters
    }
    
    /// 🌟 残り作成可能キャラクター数を取得
    func remainingCharacterSlots() -> Int {
        if isSubscribed {
            return Int.max // サブスク加入者は無制限
        } else {
            return max(0, freeMaxCharacters - characters.count)
        }
    }
    
    /// 🌟 制限情報を取得
    func getCharacterLimitInfo() -> CharacterLimitInfo {
        return CharacterLimitInfo(
            currentCount: characters.count,
            maxCount: isSubscribed ? nil : freeMaxCharacters,
            canCreateMore: canCreateNewCharacter(),
            isSubscribed: isSubscribed
        )
    }
    
    /// 🌟 サブスクリプション状態を強制更新
    func refreshSubscriptionStatus() {
        Task {
            await SubscriptionManager.shared.refreshSubscriptionStatus()
            await MainActor.run {
                self.isSubscribed = SubscriptionManager.shared.isSubscribed
            }
        }
    }
    
    func updateCharacter(_ character: Character) {
        guard let userId = userId else { return }
        
        let characterData: [String: Any] = [
            "id": character.id,
            "name": character.name,
            "personality": character.personality,
            "speakingStyle": character.speakingStyle,
            "iconName": character.iconName,
            "iconURL": character.iconURL as Any,
            "backgroundName": character.backgroundName,
            "backgroundURL": character.backgroundURL as Any,
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        database.child("characters").child(character.id).updateChildValues(characterData)
    }
    
    /// キャラクターを削除
    func deleteCharacter(_ character: Character) {
        guard let userId = userId else { return }
        
        // Firebase から削除
        database.child("characters").child(character.id).removeValue()
        database.child("users").child(userId).child("characters").child(character.id).removeValue()
        
        // ローカルから削除
        characters.removeAll { $0.id == character.id }
        
        // アクティブキャラクターが削除された場合は最初のキャラクターを選択
        if activeCharacterId == character.id && !characters.isEmpty {
            activeCharacterId = characters.first!.id
            saveActiveCharacterId()
        }
        
        print("🗑️ キャラクター削除完了: \(character.name) (残り: \(characters.count))")
    }
    
    /// アクティブキャラクターを設定
    func setActiveCharacter(_ characterId: String) {
        activeCharacterId = characterId
        saveActiveCharacterId()
    }
    
    /// アクティブキャラクターを取得
    func getActiveCharacter() -> Character? {
        return characters.first { $0.id == activeCharacterId }
    }
    
    // MARK: - Firebase Operations (既存のメソッドはそのまま維持)
    
    private func loadCharacters() {
        guard let userId = userId else { return }
        
        isLoading = true
        
        database.child("users").child(userId).child("characters").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var characterIds: [String] = []
            
            if let charactersData = snapshot.value as? [String: Bool] {
                characterIds = Array(charactersData.keys)
            }
            
            // 各キャラクターの詳細データを読み込み
            self.loadCharacterDetails(characterIds: characterIds)
        }
    }
    
    private func loadCharacterDetails(characterIds: [String]) {
        let group = DispatchGroup()
        var loadedCharacters: [Character] = []
        
        for characterId in characterIds {
            group.enter()
            database.child("characters").child(characterId).observeSingleEvent(of: .value) { snapshot in
                if let characterData = snapshot.value as? [String: Any],
                   let character = self.characterFromFirebaseData(characterData, id: characterId) {
                    loadedCharacters.append(character)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.characters = loadedCharacters.sorted { $0.name < $1.name }
            self.loadActiveCharacterId()
            self.isLoading = false
            
            print("📥 キャラクター読み込み完了: \(self.characters.count)人")
        }
    }
    
    private func saveCharacter(_ character: Character) {
        guard let userId = userId else { return }
        
        let characterData: [String: Any] = [
            "id": character.id,
            "name": character.name,
            "personality": character.personality,
            "speakingStyle": character.speakingStyle,
            "iconName": character.iconName,
            "iconURL": character.iconURL as Any,
            "backgroundName": character.backgroundName,
            "backgroundURL": character.backgroundURL as Any,
            "createdAt": Date().timeIntervalSince1970,
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        // キャラクター詳細を保存
        database.child("characters").child(character.id).setValue(characterData)
        
        // ユーザーのキャラクターリストに追加
        database.child("users").child(userId).child("characters").child(character.id).setValue(true)
    }
    
    private func loadActiveCharacterId() {
        guard let userId = userId else { return }
        
        database.child("users").child(userId).child("activeCharacterId").observeSingleEvent(of: .value) { [weak self] snapshot in
            if let characterId = snapshot.value as? String,
               let self = self,
               self.characters.contains(where: { $0.id == characterId }) {
                self.activeCharacterId = characterId
            } else if let firstCharacter = self?.characters.first {
                self?.activeCharacterId = firstCharacter.id
                self?.saveActiveCharacterId()
            }
        }
    }
    
    private func saveActiveCharacterId() {
        guard let userId = userId else { return }
        database.child("users").child(userId).child("activeCharacterId").setValue(activeCharacterId)
    }
    
    private func characterFromFirebaseData(_ data: [String: Any], id: String) -> Character? {
        guard let name = data["name"] as? String,
              let personality = data["personality"] as? String,
              let speakingStyle = data["speakingStyle"] as? String,
              let iconName = data["iconName"] as? String,
              let backgroundName = data["backgroundName"] as? String else {
            return nil
        }
        
        let character = Character()
        character.id = id
        character.name = name
        character.personality = personality
        character.speakingStyle = speakingStyle
        character.iconName = iconName
        character.backgroundName = backgroundName
        character.iconURL = data["iconURL"] as? String
        character.backgroundURL = data["backgroundURL"] as? String
        
        return character
    }
}

// MARK: - 🌟 サポート構造体（既存と同じ）

struct CharacterLimitInfo {
    let currentCount: Int
    let maxCount: Int?  // nilの場合は無制限
    let canCreateMore: Bool
    let isSubscribed: Bool
    
    var displayText: String {
        if isSubscribed {
            return "プレミアムプラン: 無制限"
        } else {
            return "\(currentCount)/\(maxCount ?? 0)人"
        }
    }
    
    var warningText: String? {
        guard !isSubscribed else { return nil }
        
        if currentCount >= (maxCount ?? 0) {
            return "無料版では\(maxCount ?? 0)人までしか登録できません"
        } else if currentCount == (maxCount ?? 0) - 1 {
            return "あと1人で制限に達します"
        }
        
        return nil
    }
}
