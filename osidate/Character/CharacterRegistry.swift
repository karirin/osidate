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
    
    // 🌟 特別ユーザーID（無制限作成可能）
    private let specialUserIDs = ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"]
    
    // Combine用
    private var cancellables = Set<AnyCancellable>()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var characterListHandle: DatabaseHandle?
    private var activeCharacterHandle: DatabaseHandle?
    private var characterDetailHandles: [String: DatabaseHandle] = [:]
    private var observedUserId: String?
    
    init() {
        setupSubscriptionObserver()
        setupAuthStateListener()
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
    
    // MARK: - 🌟 特別ユーザーかどうかをチェック
    private func isSpecialUser() -> Bool {
        guard let userID = Auth.auth().currentUser?.uid else { return false }
        return specialUserIDs.contains(userID)
    }
    
    // MARK: - Character Management
    
    /// 🌟 新しいキャラクターを作成（サブスク制限チェック付き + 特別ユーザー対応）
    func createNewCharacter(name: String, personality: String, speakingStyle: String) -> Character? {
        print("🎭 新キャラクター作成要求: \(name)")
        print("   - 現在のキャラクター数: \(characters.count)")
        print("   - 制限数: \(freeMaxCharacters)")
        print("   - サブスク状態: \(isSubscribed)")
        print("   - 特別ユーザー: \(isSpecialUser())")
        
        // 🌟 特別ユーザーまたはサブスク加入者は無制限
        let hasUnlimitedAccess = isSpecialUser() || isSubscribed
        
        // 🌟 サブスクリプション制限チェック（特別ユーザーは除外）
        if !hasUnlimitedAccess && characters.count >= freeMaxCharacters {
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
        
        // 🌟 特別ユーザーの場合は親密度を3000に設定
        if isSpecialUser() {
            character.intimacyLevel = 3000
            print("🎯 特別ユーザー検出: キャラクター作成時に親密度を3000に設定")
        }
        
        characters.append(character)
        saveCharacter(character)
        
        print("✅ キャラクター作成成功: \(name) (総数: \(characters.count))")
        return character
    }
    
    /// 🌟 キャラクター作成可否をチェック（特別ユーザー対応）
    func canCreateNewCharacter() -> Bool {
        let hasUnlimitedAccess = isSpecialUser() || isSubscribed
        return hasUnlimitedAccess || characters.count < freeMaxCharacters
    }
    
    /// 🌟 残り作成可能キャラクター数を取得（特別ユーザー対応）
    func remainingCharacterSlots() -> Int {
        let hasUnlimitedAccess = isSpecialUser() || isSubscribed
        if hasUnlimitedAccess {
            return Int.max // 特別ユーザーまたはサブスク加入者は無制限
        } else {
            return max(0, freeMaxCharacters - characters.count)
        }
    }
    
    /// 🌟 制限情報を取得（特別ユーザー対応）
    func getCharacterLimitInfo() -> CharacterLimitInfo {
        let hasUnlimitedAccess = isSpecialUser() || isSubscribed
        return CharacterLimitInfo(
            currentCount: characters.count,
            maxCount: hasUnlimitedAccess ? nil : freeMaxCharacters,
            canCreateMore: canCreateNewCharacter(),
            isSubscribed: hasUnlimitedAccess, // 特別ユーザーもサブスク扱いにする
            isSpecialUser: isSpecialUser()
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
        guard userId != nil else { return }
        database.child("characters").child(character.id).updateChildValues(serializeCharacter(character))
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
        guard characters.contains(where: { $0.id == characterId }) else { return }
        activeCharacterId = characterId
        saveActiveCharacterId()
    }
    
    /// アクティブキャラクターを取得
    func getActiveCharacter() -> Character? {
        return characters.first { $0.id == activeCharacterId }
    }
    
    // MARK: - Firebase Operations (既存のメソッドはそのまま維持)
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.handleAuthStateChanged(user: user)
            }
        }
    }
    
    private func handleAuthStateChanged(user: User?) {
        removeAllObservers()
        
        guard let user else {
            characters = []
            activeCharacterId = ""
            isLoading = false
            return
        }
        
        startCharacterObservers(for: user.uid)
    }
    
    private func startCharacterObservers(for userId: String) {
        observedUserId = userId
        isLoading = true
        
        characterListHandle = database.child("users").child(userId).child("characters").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            
            let rawIds = (snapshot.value as? [String: Bool])?
                .filter { $0.value }
                .map(\.key) ?? []
            let characterIds = Array(Set(rawIds)).sorted()
            
            self.syncCharacterDetailObservers(characterIds: characterIds)
            self.startActiveCharacterObserver(for: userId)
            
            if characterIds.isEmpty {
                DispatchQueue.main.async {
                    self.characters = []
                    self.activeCharacterId = ""
                    self.isLoading = false
                }
            }
        }
    }
    
    private func startActiveCharacterObserver(for userId: String) {
        guard activeCharacterHandle == nil else { return }
        
        activeCharacterHandle = database.child("users").child(userId).child("activeCharacterId").observe(.value) { [weak self] snapshot in
            guard let self else { return }
            
            let remoteActiveId = snapshot.value as? String
            DispatchQueue.main.async {
                if let remoteActiveId, self.characters.contains(where: { $0.id == remoteActiveId }) {
                    self.activeCharacterId = remoteActiveId
                } else if let firstCharacter = self.characters.first {
                    self.activeCharacterId = firstCharacter.id
                    self.saveActiveCharacterId()
                } else {
                    self.activeCharacterId = ""
                }
            }
        }
    }
    
    private func syncCharacterDetailObservers(characterIds: [String]) {
        let incomingIds = Set(characterIds)
        let existingIds = Set(characterDetailHandles.keys)
        
        for removedId in existingIds.subtracting(incomingIds) {
            if let handle = characterDetailHandles.removeValue(forKey: removedId) {
                database.child("characters").child(removedId).removeObserver(withHandle: handle)
            }
        }
        
        for characterId in incomingIds.subtracting(existingIds) {
            let handle = database.child("characters").child(characterId).observe(.value) { [weak self] snapshot in
                guard let self else { return }
                
                DispatchQueue.main.async {
                    self.mergeCharacterSnapshot(snapshot, characterId: characterId)
                    self.isLoading = false
                }
            }
            characterDetailHandles[characterId] = handle
        }
        
        if incomingIds.isEmpty {
            isLoading = false
        }
    }
    
    private func mergeCharacterSnapshot(_ snapshot: DataSnapshot, characterId: String) {
        if let characterData = snapshot.value as? [String: Any],
           let character = characterFromFirebaseData(characterData, id: characterId) {
            if let index = characters.firstIndex(where: { $0.id == characterId }) {
                characters[index] = character
            } else {
                characters.append(character)
            }
        } else {
            characters.removeAll { $0.id == characterId }
        }
        
        characters = deduplicatedCharacters(characters).sorted {
            if $0.name == $1.name {
                return $0.id < $1.id
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        
        if !activeCharacterId.isEmpty, !characters.contains(where: { $0.id == activeCharacterId }) {
            activeCharacterId = characters.first?.id ?? ""
            if !activeCharacterId.isEmpty {
                saveActiveCharacterId()
            }
        } else if activeCharacterId.isEmpty, let firstCharacter = characters.first {
            activeCharacterId = firstCharacter.id
            saveActiveCharacterId()
        }
        
        print("📥 キャラクター同期完了: \(characters.count)人")
    }
    
    private func saveCharacter(_ character: Character) {
        guard let userId = userId else { return }
        var characterData = serializeCharacter(character, includeNullDeletions: false)
        characterData["createdAt"] = Date().timeIntervalSince1970
        
        database.child("characters").child(character.id).setValue(characterData)
        
        // ユーザーのキャラクターリストに追加
        database.child("users").child(userId).child("characters").child(character.id).setValue(true)
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
        character.intimacyLevel = data["intimacyLevel"] as? Int ?? 0
        character.totalDateCount = data["totalDateCount"] as? Int ?? 0
        character.unlockedInfiniteMode = data["unlockedInfiniteMode"] as? Bool ?? false
        character.userNickname = data["userNickname"] as? String ?? ""
        character.useNickname = data["useNickname"] as? Bool ?? false
        character.favoriteTopics = data["favoriteTopics"] as? [String] ?? []
        character.sharedMemories = data["sharedMemories"] as? [String] ?? []
        if let birthday = data["birthday"] as? TimeInterval {
            character.birthday = Date(timeIntervalSince1970: birthday)
        }
        if let anniversaryDate = data["anniversaryDate"] as? TimeInterval {
            character.anniversaryDate = Date(timeIntervalSince1970: anniversaryDate)
        }
        
        return character
    }
    
    private func serializeCharacter(_ character: Character, includeNullDeletions: Bool = true) -> [String: Any] {
        var characterData: [String: Any] = [
            "id": character.id,
            "name": character.name,
            "personality": character.personality,
            "speakingStyle": character.speakingStyle,
            "iconName": character.iconName,
            "backgroundName": character.backgroundName,
            "intimacyLevel": character.intimacyLevel,
            "totalDateCount": character.totalDateCount,
            "unlockedInfiniteMode": character.unlockedInfiniteMode,
            "userNickname": character.userNickname,
            "useNickname": character.useNickname,
            "favoriteTopics": character.favoriteTopics,
            "sharedMemories": character.sharedMemories,
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        if let iconURL = character.iconURL, !iconURL.isEmpty {
            characterData["iconURL"] = iconURL
        } else if includeNullDeletions {
            characterData["iconURL"] = NSNull()
        }

        if let backgroundURL = character.backgroundURL, !backgroundURL.isEmpty {
            characterData["backgroundURL"] = backgroundURL
        } else if includeNullDeletions {
            characterData["backgroundURL"] = NSNull()
        }

        if let birthday = character.birthday {
            characterData["birthday"] = birthday.timeIntervalSince1970
        } else if includeNullDeletions {
            characterData["birthday"] = NSNull()
        }

        if let anniversaryDate = character.anniversaryDate {
            characterData["anniversaryDate"] = anniversaryDate.timeIntervalSince1970
        } else if includeNullDeletions {
            characterData["anniversaryDate"] = NSNull()
        }
        
        return characterData
    }
    
    private func deduplicatedCharacters(_ characters: [Character]) -> [Character] {
        var seenIds = Set<String>()
        return characters.filter { character in
            seenIds.insert(character.id).inserted
        }
    }
    
    private func removeAllObservers() {
        if let observedUserId, let characterListHandle {
            database.child("users").child(observedUserId).child("characters").removeObserver(withHandle: characterListHandle)
        }
        if let observedUserId, let activeCharacterHandle {
            database.child("users").child(observedUserId).child("activeCharacterId").removeObserver(withHandle: activeCharacterHandle)
        }
        for (characterId, handle) in characterDetailHandles {
            database.child("characters").child(characterId).removeObserver(withHandle: handle)
        }
        characterListHandle = nil
        activeCharacterHandle = nil
        characterDetailHandles.removeAll()
        observedUserId = nil
    }
}

// MARK: - 🌟 サポート構造体（特別ユーザー対応）

struct CharacterLimitInfo {
    let currentCount: Int
    let maxCount: Int?  // nilの場合は無制限
    let canCreateMore: Bool
    let isSubscribed: Bool
    let isSpecialUser: Bool // 🌟 特別ユーザーフラグを追加
    
    var displayText: String {
        if isSpecialUser {
            return "特別アカウント: 無制限" // 🌟 特別ユーザー向けメッセージ
        } else if isSubscribed {
            return "プレミアムプラン: 無制限"
        } else {
            return "\(currentCount)/\(maxCount ?? 0)人"
        }
    }
    
    var warningText: String? {
        // 🌟 特別ユーザーの場合は警告を表示しない
        guard !isSpecialUser && !isSubscribed else { return nil }
        
        if currentCount >= (maxCount ?? 0) {
            return "無料版では\(maxCount ?? 0)人までしか登録できません"
        } else if currentCount == (maxCount ?? 0) - 1 {
            return "あと1人で制限に達します"
        }
        
        return nil
    }
}
