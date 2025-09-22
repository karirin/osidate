//
//  AdMobManager.swift - 最適化版
//  osidate
//

import SwiftUI
import FirebaseAuth
import GoogleMobileAds

class AdMobManager: NSObject, ObservableObject {
    @Published var isAdLoaded = false
    @Published var isShowingAd = false
    @Published var isLoading = false
    @Published var adLoadError: Error?
    
    private var rewardedAd: RewardedAd?
    private var adCompletionHandler: ((Bool) -> Void)?
    private var hasInitializedAds = false
    
    private let adUnitID = "ca-app-pub-4898800212808837/2039052898"
    
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
            print("🎯 広告スキップ対象ユーザー")
            return
        }
        
        // 初回起動時は長めの遅延（5秒）
        // 2回目以降は短めの遅延（2秒）
        let delay = isFirstAppLaunch() ? 5.0 : 2.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.performInitialAdLoad()
        }
    }
    
    /// 実際の広告読み込みを実行
    private func performInitialAdLoad() {
        guard !hasInitializedAds else { return }
        hasInitializedAds = true
        
        print("📱 遅延読み込み: 広告読み込み開始")
        loadRewardedAd()
    }
    
    // MARK: - 条件判定メソッド
    
    /// 広告をスキップすべきかチェック
    private func shouldSkipAds() -> Bool {
        // 特定ユーザーチェック
        if let userID = Auth.auth().currentUser?.uid,
           ["vVceNdjseGTBMYP7rMV9NKZuBaz1", "ol3GjtaeiMhZwprk7E3zrFOh2VJ2"].contains(userID) {
            return true
        }
        
        // サブスクリプション会員チェック（今後の拡張用）
        // if SubscriptionManager.shared.isSubscribed {
        //     return true
        // }
        
        return false
    }
    
    /// 初回起動かチェック
    private func isFirstAppLaunch() -> Bool {
        let key = "hasLaunchedBefore"
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
        } else if !isAdLoaded && !isLoading {
            // 既に初期化済みだが広告が利用できない場合は再読み込み
            loadRewardedAd()
        }
    }
    
    // MARK: - 既存のメソッド（最適化）
    
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        // 広告をスキップすべきユーザーの場合
        if shouldSkipAds() {
            print("🎯 広告スキップ - 直接成功を返す")
            completion(true)
            return
        }
        
        // オンデマンドで広告を準備
        ensureAdIsReady()
        
        guard let rewardedAd = rewardedAd, isAdLoaded else {
            print("❌ 広告が読み込まれていません - 再読み込み後にリトライ")
            loadRewardedAd()
            
            // 2秒後にリトライ
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.isAdLoaded {
                    self.showRewardedAd(completion: completion)
                } else {
                    completion(false)
                }
            }
            return
        }
        
        guard !isShowingAd else {
            print("⚠️ すでに広告表示処理中")
            completion(false)
            return
        }

        adCompletionHandler = completion
        isShowingAd = true

        DispatchQueue.main.async {
            guard let presentVC = self.topPresentableViewController() else {
                print("❌ 表示用のViewControllerが取得できません")
                self.isShowingAd = false
                self.adCompletionHandler?(false)
                self.adCompletionHandler = nil
                return
            }

            print("🎬 リワード広告表示開始")
            rewardedAd.present(from: presentVC) { [weak self] in
                print("🎁 リワード獲得!")
                DispatchQueue.main.async {
                    self?.adCompletionHandler?(true)
                    self?.adCompletionHandler = nil
                }
            }
        }
    }
    
    // MARK: - 広告読み込み（既存のロジックを保持）
    
    func loadRewardedAd() {
        // 広告をスキップすべきユーザーは読み込みしない
        if shouldSkipAds() {
            return
        }
        
        print("🎬 リワード広告読み込み開始")
        
        let request = Request()
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 広告読み込み失敗: \(error.localizedDescription)")
                    self?.adLoadError = error
                    self?.isAdLoaded = false
                } else {
                    print("✅ 広告読み込み成功")
                    self?.rewardedAd = ad
                    self?.isAdLoaded = true
                    self?.adLoadError = nil
                    self?.rewardedAd?.fullScreenContentDelegate = self
                }
            }
        }
    }
    
    // MARK: - ViewController取得（既存）
    
    private func topViewController(base: UIViewController? = UIApplication.shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first(where: { $0.activationState == .foregroundActive })?
        .windows.first(where: { $0.isKeyWindow })?
        .rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController { return topViewController(base: selected) }
        if let presented = base?.presentedViewController { return topViewController(base: presented) }
        return base
    }
    
    private func topPresentableViewController() -> UIViewController? {
        guard let top = topViewController() else { return nil }
        if let alert = top as? UIAlertController {
            return alert.presentingViewController ?? top
        }
        return top
    }
    
    // MARK: - 広告が利用可能かチェック
    
    var canShowAd: Bool {
        // 広告をスキップすべきユーザーは常にtrueを返す
        if shouldSkipAds() {
            return true
        }
        return isAdLoaded && rewardedAd != nil
    }
}

// MARK: - GADFullScreenContentDelegate（既存のデリゲートメソッド）

extension AdMobManager: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ 広告表示失敗: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isShowingAd = false
            self.adCompletionHandler?(false)
            self.adCompletionHandler = nil
            self.rewardedAd = nil
            self.loadRewardedAd()
        }
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎬 広告表示開始(Delegate)")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎬 広告表示終了")
        DispatchQueue.main.async {
            self.isShowingAd = false
            if self.adCompletionHandler != nil {
                self.adCompletionHandler?(false)
                self.adCompletionHandler = nil
            }
            self.rewardedAd = nil
            self.loadRewardedAd()
        }
    }
}
