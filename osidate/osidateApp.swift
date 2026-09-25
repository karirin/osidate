//
//  osidateApp.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI
import FirebaseCore
import GoogleMobileAds
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // AdMob初期化
        MobileAds.shared.start(completionHandler: { status in
            print("✅ AdMob初期化完了")
            print("📊 アダプターステータス: \(status.adapterStatusesByClassName)")
        })
        
        return true
    }
}

@main
struct osidateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = OshiNotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            TopView()
        }
    }
}
