//
//  InterstitialAdManager.swift
//  osidate
//
//  Created by Apple on 2025/08/17.
//

import GoogleMobileAds
import SwiftUI

class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var isLoading = false
    @Published var isPresenting = false
    
    private var interstitialAd: InterstitialAd?
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用ID
    
    override init() {
        super.init()
        loadInterstitialAd()
    }
    
    func loadInterstitialAd() {
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
    
    func showInterstitialAd() {
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
    
    // MARK: - GADFullScreenContentDelegate
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("📱 インタースティシャル広告が閉じられました")
        isPresenting = false
        interstitialAd = nil
        // 次の広告を事前読み込み
        loadInterstitialAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("🚫 インタースティシャル広告表示失敗: \(error.localizedDescription)")
        isPresenting = false
        interstitialAd = nil
        loadInterstitialAd()
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎬 インタースティシャル広告表示開始")
    }
}
