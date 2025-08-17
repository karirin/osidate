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
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313" // テスト用ID
    
    override init() {
        super.init()
        loadRewardedAd()
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
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ ルートビューコントローラーが見つかりません")
            completion(false)
            return
        }
        
        adCompletionHandler = completion
        isShowingAd = true
        
        print("🎬 リワード広告表示開始")
        rewardedAd.present(from: rootViewController) { [weak self] in
            // リワード獲得時の処理
            print("🎁 リワード獲得!")
            DispatchQueue.main.async {
                self?.adCompletionHandler?(true)
                self?.adCompletionHandler = nil
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
    func ad( ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ 広告表示失敗: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isShowingAd = false
            self.adCompletionHandler?(false)
            self.adCompletionHandler = nil
            // 次の広告を読み込み
            self.loadRewardedAd()
        }
    }
    
    func adWillPresentFullScreenContent( ad: FullScreenPresentingAd) {
        print("🎬 広告表示開始")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎬 広告表示終了")
        DispatchQueue.main.async {
            self.isShowingAd = false
            // リワードを受け取らずに閉じた場合
            if self.adCompletionHandler != nil {
                self.adCompletionHandler?(false)
                self.adCompletionHandler = nil
            }
            // 次の広告を読み込み
            self.loadRewardedAd()
        }
    }
}
