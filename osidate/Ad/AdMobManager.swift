//
//  AdMobManager.swift
//  osidate
//
//  Created by Apple on 2025/08/17.
//

import SwiftUI
import GoogleMobileAds

class AdMobManager: NSObject, ObservableObject {
    @Published var isAdLoaded = false
    @Published var isShowingAd = false
    @Published var isLoading = false
    @Published var adLoadError: Error?
    
    private var rewardedAd: RewardedAd?
    private var adCompletionHandler: ((Bool) -> Void)?
    
    // テスト用ID（本番では実際のIDに変更）
    private let adUnitID = "ca-app-pub-4898800212808837/2039052898" // テスト用ID
    
    override init() {
        super.init()
        loadRewardedAd()
    }
    
    // 追加（AdMobManager 内）
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
        // アラートが最前面なら、その presenting 側から出す
        if let alert = top as? UIAlertController {
            return alert.presentingViewController ?? top
        }
        return top
    }

    // MARK: - 広告読み込み
    func loadRewardedAd() {
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
                    
                    // 広告デリゲートを設定
                    self?.rewardedAd?.fullScreenContentDelegate = self
                }
            }
        }
    }
    
    // MARK: - 広告表示
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd, isAdLoaded else {
            print("❌ 広告が読み込まれていません")
            completion(false)
            return
        }
        guard !isShowingAd else {
            print("⚠️ すでに広告表示処理中")
            completion(false)
            return
        }

        adCompletionHandler = completion
        isShowingAd = true

        // ここ重要：必ずメインスレッド＋最前面の “出せる” VC を使う
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
    
    // MARK: - 広告が利用可能かチェック
    var canShowAd: Bool {
        return isAdLoaded && rewardedAd != nil
    }
}

// MARK: - GADFullScreenContentDelegate
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
            // リワード未獲得で閉じた場合のフォールバック
            if self.adCompletionHandler != nil {
                self.adCompletionHandler?(false)
                self.adCompletionHandler = nil
            }
            self.rewardedAd = nil
            self.loadRewardedAd()
        }
    }
}
