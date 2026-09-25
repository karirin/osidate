//
//  InterstitialAdManager.swift - 最適化版
//  osidate
//

import GoogleMobileAds
import SwiftUI
import FirebaseAuth

class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var isLoading = false
    @Published var isPresenting = false
    /// 広告が閉じられた後に一度だけ呼ばれる
    var onAdDismissed: (() -> Void)?
    
    private var interstitialAd: InterstitialAd?
    private var hasInitializedAds = false
    private let adUnitID = "ca-app-pub-4898800212808837/6818389246"
    
    override init() {
        super.init()
        // 初期化時は重い処理を行わない
        scheduleInitialAdLoad()
    }
    
    // MARK: - 初期化の最適化
    
    /// アプリ起動への影響を最小限にするため、遅延読み込みをスケジュール
    private func scheduleInitialAdLoad() {
        // 特定ユーザーは広告不要
        if shouldSkipAds() {
            print("🎯 インタースティシャル広告スキップ対象ユーザー")
            return
        }
        
        // チャット頻度を考慮してより長い遅延を設定
        // 初回起動時は10秒、2回目以降は5秒後に読み込み
        let delay = isFirstAppLaunch() ? 10.0 : 5.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.performInitialAdLoad()
        }
    }
    
    /// 実際の広告読み込みを実行
    private func performInitialAdLoad() {
        guard !hasInitializedAds else { return }
        hasInitializedAds = true
        
        print("📱 遅延読み込み: インタースティシャル広告読み込み開始")
        loadInterstitialAd()
    }
    
    // MARK: - 条件判定メソッド
    
    /// 広告をスキップすべきかチェック
    private func shouldSkipAds() -> Bool {
        // 特定ユーザーチェック
        if let userID = Auth.auth().currentUser?.uid,
           ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"].contains(userID) {
            return true
        }
        
        // サブスクリプション会員は広告なし
        if SubscriptionManager.cachedIsSubscribed {
            return true
        }
        
        return false
    }
    
    /// 初回起動かチェック
    private func isFirstAppLaunch() -> Bool {
        let key = "hasLaunchedInterstitialBefore"
        let hasLaunched = UserDefaults.standard.bool(forKey: key)
        
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: key)
            return true
        }
        
        return false
    }
    
    // MARK: - オンデマンド読み込み
    
    /// 広告が必要になった時点で確実に読み込み
    private func ensureAdIsReady() {
        if !hasInitializedAds {
            performInitialAdLoad()
        } else if interstitialAd == nil && !isLoading {
            // 既に初期化済みだが広告が利用できない場合は再読み込み
            loadInterstitialAd()
        }
    }
    
    // MARK: - 広告読み込み（最適化）
    
    func loadInterstitialAd() {
        // 広告をスキップすべきユーザーは読み込みしない
        if shouldSkipAds() {
            return
        }
        
        isLoading = true
        let request = Request()
        
        InterstitialAd.load(
            with: adUnitID,
            request: request
        ) { [weak self] ad, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("🚫 インタースティシャル広告読み込み失敗: \(error.localizedDescription)")
                    return
                }
                
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                print("✅ インタースティシャル広告読み込み完了")
            }
        }
    }
    
    // MARK: - 広告表示（最適化）
    
    func showInterstitialAd() {
        // 広告をスキップすべきユーザーの場合は何もしない
        if shouldSkipAds() {
            print("🎯 インタースティシャル広告スキップ")
            return
        }
        
        // オンデマンドで広告を準備
        ensureAdIsReady()
        
        guard let interstitialAd = interstitialAd else {
            print("⚠️ インタースティシャル広告が準備できていません")
            // 広告が準備できていない場合は再読み込み
            loadInterstitialAd()
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("⚠️ RootViewControllerが見つかりません")
            return
        }
        
        print("🎬 インタースティシャル広告を表示")
        isPresenting = true
        interstitialAd.present(from: rootViewController)
    }
    
    // MARK: - GADFullScreenContentDelegate（既存）
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("📱 インタースティシャル広告が閉じられました")
        isPresenting = false
        interstitialAd = nil
        
        let onAdDismissed = self.onAdDismissed
        self.onAdDismissed = nil
        onAdDismissed?()
        
        // 次の広告を事前読み込み（少し遅延させる）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.loadInterstitialAd()
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("🚫 インタースティシャル広告表示失敗: \(error.localizedDescription)")
        isPresenting = false
        interstitialAd = nil
        
        // 失敗時も少し遅延してから再読み込み
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.loadInterstitialAd()
        }
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎬 インタースティシャル広告表示開始")
    }
}
