//
//  BannerView.swift
//  osimono
//
//  Created by Apple on 2025/05/22.
//

import GoogleMobileAds
import SwiftUI

struct BannerAdView: UIViewRepresentable {
//    private let adUnitID = "ca-app-pub-3940256099942544/2934735716"
    private let adUnitID = "ca-app-pub-4898800212808837/4056494532"
    @State private var adHeight: CGFloat = 50
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        bannerView.rootViewController = getRootViewController()
        
        let request = Request()
        bannerView.load(request)
        
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        let parent: BannerAdView
        
        init(_ parent: BannerAdView) {
            self.parent = parent
        }
        
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("広告の読み込み成功")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("広告の読み込み失敗: \(error.localizedDescription)")
        }
    }
}

struct BannerAdChatListView: UIViewRepresentable {
//    private let adUnitID = "ca-app-pub-3940256099942544/2934735716"
    private let adUnitID = "ca-app-pub-4898800212808837/5507333697"
    @State private var adHeight: CGFloat = 50
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        bannerView.rootViewController = getRootViewController()
        
        let request = Request()
        bannerView.load(request)
        
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        let parent: BannerAdChatListView
        
        init(_ parent: BannerAdChatListView) {
            self.parent = parent
        }
        
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("広告の読み込み成功")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("広告の読み込み失敗: \(error.localizedDescription)")
        }
    }
}

struct BannerAdChatView: UIViewRepresentable {
//    private let adUnitID = "ca-app-pub-3940256099942544/2934735716"
    private let adUnitID = "ca-app-pub-4898800212808837/7053986130"
    @State private var adHeight: CGFloat = 50
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        bannerView.rootViewController = getRootViewController()
        
        let request = Request()
        bannerView.load(request)
        
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        let parent: BannerAdChatView
        
        init(_ parent: BannerAdChatView) {
            self.parent = parent
        }
        
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("広告の読み込み成功")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("広告の読み込み失敗: \(error.localizedDescription)")
        }
    }
}
