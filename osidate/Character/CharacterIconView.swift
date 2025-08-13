//
//  CharacterIconView.swift - アニメーション安定化修正版
//  osidate
//

import SwiftUI

struct CharacterIconView: View {
    let character: Character
    let size: CGFloat
    let enableFloating: Bool

    @State private var isFloating = false
    @State private var iconImage: UIImage? = nil
    @State private var isLoading = false
    @State private var animationTimer: Timer? = nil
    
    // デフォルトでアニメーションを有効にするイニシャライザ
    init(character: Character, size: CGFloat, enableFloating: Bool = true) {
        self.character = character
        self.size = size
        self.enableFloating = enableFloating
    }
    
    var body: some View {
        content
            .frame(width: size, height: size)
            .clipped()
            .clipShape(Circle())
            .offset(y: enableFloating ? (isFloating ? -8 : 8) : 0)
            .animation(
                enableFloating ?
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true) :
                .default,
                value: isFloating
            )
            .onAppear {
                startFloatingAnimation()
                loadIconIfNeeded()
            }
            .onDisappear {
                stopFloatingAnimation()
            }
            .onChange(of: character.iconURL) { newIconURL in
                loadIconIfNeeded()
            }
            .onChange(of: character.id) { newCharacterId in
                iconImage = nil
                loadIconIfNeeded()
                // キャラクター変更時にアニメーションをリスタート
                restartFloatingAnimation()
            }
            .onChange(of: enableFloating) { newValue in
                if newValue {
                    startFloatingAnimation()
                } else {
                    stopFloatingAnimation()
                }
            }
            .id("\(character.id)_\(character.iconURL ?? "default")_\(enableFloating)")
    }
    
    @ViewBuilder
    private var content: some View {
        if let iconImage = iconImage {
            Image(uiImage: iconImage)
                .resizable()
                .scaledToFill()
        } else if isLoading {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .overlay(ProgressView().scaleEffect(0.8))
        } else {
            defaultIcon
        }
    }

    private var defaultIcon: some View {
        Circle()
            .fill(Color.brown)
            .overlay(
                Image(systemName: character.iconName)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - アニメーション管理メソッド（新規追加）
    
    private func startFloatingAnimation() {
        guard enableFloating else { return }
        
        // 既存のタイマーを停止
        stopFloatingAnimation()
        
        // 少し遅延してからアニメーション開始（View描画完了を待つ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                self.isFloating = true
            }
        }
        
        // フォールバック用のタイマー（アニメーションが止まった場合の再起動）
        animationTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            DispatchQueue.main.async {
                guard self.enableFloating else { return }
                
                // アニメーションが停止している場合は再起動
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    self.isFloating.toggle()
                }
            }
        }
    }
    
    private func stopFloatingAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isFloating = false
        }
    }
    
    private func restartFloatingAnimation() {
        guard enableFloating else { return }
        
        stopFloatingAnimation()
        
        // キャラクター変更時は少し長めの遅延を設ける
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startFloatingAnimation()
        }
    }
    
    private func loadIconIfNeeded() {
        // アイコンURLがない、または空の場合はデフォルトアイコンを使用
        guard let iconURL = character.iconURL,
              !iconURL.isEmpty,
              let url = URL(string: iconURL) else {
            print("CharacterIconView: アイコンURLが空またはキャラクターが無効 - デフォルトアイコンを表示")
            iconImage = nil
            return
        }
        
        // 既に同じURLの画像を読み込み済みの場合はスキップ
        if iconImage != nil && character.iconURL == iconURL {
            return
        }
        
        print("CharacterIconView: アイコン画像を読み込み中 - \(iconURL)")
        isLoading = true
        
        // 非同期でアイコンを読み込み
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    if let loadedImage = UIImage(data: data) {
                        self.iconImage = loadedImage
                        print("CharacterIconView: アイコン読み込み成功")
                    } else {
                        print("CharacterIconView: アイコンデータの変換に失敗")
                        self.iconImage = nil
                    }
                    self.isLoading = false
                }
            } catch {
                print("CharacterIconView: アイコン読み込みエラー - \(error.localizedDescription)")
                await MainActor.run {
                    self.iconImage = nil
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        CharacterIconView(
            character: Character(
                name: "テスト",
                personality: "優しい",
                speakingStyle: "丁寧",
                iconName: "person.circle.fill"
            ),
            size: 150,
            enableFloating: true
        )
        
        CharacterIconView(
            character: Character(
                name: "テスト2",
                personality: "クール",
                speakingStyle: "カジュアル",
                iconName: "heart.circle.fill"
            ),
            size: 100,
            enableFloating: false
        )
    }
    .padding()
}
