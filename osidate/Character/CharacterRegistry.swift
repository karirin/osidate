//
//  MultipleOshiSystem.swift
//  osidate
//
//  複数の推しを管理するためのシステム
//

import SwiftUI
import Foundation
import FirebaseDatabase
import FirebaseAuth

// MARK: - Character Registry（複数キャラクター管理）
class CharacterRegistry: ObservableObject {
    @Published var characters: [Character] = []
    @Published var activeCharacterId: String = ""
    @Published var isLoading: Bool = false
    
    private let database = Database.database().reference()
    private var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    init() {
        loadCharacters()
    }
    
    // MARK: - Character Management
    
    /// 新しいキャラクターを作成
    func createNewCharacter(name: String, personality: String, speakingStyle: String) -> Character {
        let character = Character(
            name: name,
            personality: personality,
            speakingStyle: speakingStyle,
            iconName: "person.circle.fill",
            backgroundName: "defaultBG"
        )
        
        characters.append(character)
        saveCharacter(character)
        
        return character
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
    
    // MARK: - Firebase Operations
    
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
