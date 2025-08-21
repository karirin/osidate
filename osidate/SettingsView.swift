//
//  SettingsView.swift
//  osidate
//
//  Created by Apple on 2025/08/14.
//

import SwiftUI
import Firebase
import FirebaseAuth
import WebKit
import StoreKit
import SwiftyCrop
import FirebaseStorage

func generateHapticFeedback() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
}

struct SettingsView: View {
    @State private var username: String = "推し活ユーザー"
    @State private var favoriteOshi: String = ""
    @State private var isShowingImagePicker = false
    @State private var isShowingLogoutAlert = false
    @State private var isShowingOshiSelector = false
    @State private var showAddOshiForm = false
    
    // For bug reporting and App Store review
    @State private var showingBugReportForm = false
    @State private var showingReviewConfirmation = false
    @Environment(\.requestReview) private var requestReview
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 色の定義を動的に変更
    var primaryColor: Color { Color(.systemPink) }
    var accentColor: Color { Color(.purple) }
    var backgroundColor: Color { colorScheme == .dark ? Color(.systemBackground) : Color(.white) }
    var cardColor: Color { colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.white) }
    var textColor: Color { colorScheme == .dark ? Color(.white) : Color(.black) }
    
    @State private var showingNotificationSettings = false
    @State private var showingPrivacySettings = false
    @State private var showingShareSettings = false
    
    // おすすめアプリの表示状態
    @State private var showingRecommendedApp1 = false
    @State private var showingRecommendedApp2 = false
    
    @State private var isShowingEditOshiView = false
    
    @State private var profileImage: UIImage?
    @State private var backgroundImage: UIImage?
    @State private var showImagePicker = false
    // URLスキームを開くための環境変数
    @Environment(\.openURL) private var openURL
    
    // 管理者権限関連
    @State private var isAdmin = false
    @State private var isCheckingAdminStatus = true
    @State private var showingAdminChatAnalytics = false
    @State private var showingAdminGroupChatAnalytics = false
    @State private var showingAdminDataOverview: Bool = false
    @State private var showingUserManagement: Bool = false
    @State private var showingSystemSettings: Bool = false
    @State private var showSubscriptionView = false
    
    // 管理者UserIDのリスト
    private let adminUserIds = [
        ""
//        "3UDNienzhkdheKIy77lyjMJhY4D3",
//        "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ヘッダー
                    HStack {
                        Text("設定")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(primaryColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 管理者バッジ
                        if isAdmin {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 20))
                                .padding(.trailing, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // 管理者専用セクション
                    if isAdmin {
                        VStack(spacing: 10) {
                            HStack {
                                Text("管理者機能")
                                    .foregroundColor(.secondary)
                                    .frame(alignment: .leading)
                                Spacer()
                            }.padding(.leading)
                            
                            VStack(spacing: 15) {
                                // データ分析（既存）
                                SettingRow(
                                    icon: "chart.bar.doc.horizontal.fill",
                                    title: "データ分析",
                                    color: .blue,
                                    action: {
                                        generateHapticFeedback()
                                        showingAdminChatAnalytics = true
                                    }
                                )
                                
                                // 新機能：全データ表示
                                SettingRow(
                                    icon: "list.bullet.rectangle.portrait.fill",
                                    title: "全データ表示",
                                    color: .purple,
                                    action: {
                                        generateHapticFeedback()
                                        showingAdminDataOverview = true
                                    }
                                )
                                
                                // ユーザー管理（既存）
                                SettingRow(
                                    icon: "person.3.fill",
                                    title: "チャット",
                                    color: .green,
                                    action: {
                                        generateHapticFeedback()
                                        showingAdminChatAnalytics = true
                                    }
                                )
                                
                                // システム設定（既存）
                                SettingRow(
                                    icon: "gear.badge.questionmark",
                                    title: "グループチャット",
                                    color: .orange,
                                    action: {
                                        generateHapticFeedback()
                                        showingAdminGroupChatAnalytics = true
                                    }
                                )
                                
                                // 新機能：データエクスポート
                                SettingRow(
                                    icon: "square.and.arrow.up.fill",
                                    title: "データエクスポート",
                                    color: .indigo,
                                    action: {
                                        generateHapticFeedback()
                                        exportAllDataToCSV()
                                    }
                                )
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.red.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color.orange.opacity(0.2), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                    
//                    VStack(spacing: 10) {
//                        HStack {
//                            Text("推しを編集")
//                                .foregroundColor(.secondary)
//                                .frame(alignment: .leading)
//                            
//                            Spacer()
//                        }.padding(.horizontal)
//                        
//                        VStack(spacing: 15) {
//                            HStack {
//                                // プロフィール画像
//                                if let image = profileImage {
//                                    Image(uiImage: image)
//                                        .resizable()
//                                        .scaledToFill()
//                                        .frame(width: 60, height: 60)
//                                        .clipShape(Circle())
//                                        .overlay(
//                                            Circle()
//                                                .stroke(primaryColor, lineWidth: 2)
//                                        )
//                                } else {
//                                    Circle()
//                                        .fill(Color.gray.opacity(0.2))
//                                        .frame(width: 60, height: 60)
//                                        .overlay(
//                                            Image(systemName: "person.circle.fill")
//                                                .resizable()
//                                                .scaledToFit()
//                                                .frame(width: 30)
//                                                .foregroundColor(primaryColor)
//                                        )
//                                }
//                                
//                                VStack(alignment: .leading, spacing: 4) {
//                                    HStack {
//                                        Text(username)
//                                            .font(.headline)
//                                            .foregroundColor(.primary)
//                                        
//                                        if isAdmin {
//                                            Image(systemName: "crown.fill")
//                                                .foregroundColor(.orange)
//                                                .font(.system(size: 12))
//                                        }
//                                    }
//                                    
//                                    Text("アイコンをタップして変更")
//                                        .font(.caption)
//                                        .foregroundColor(.secondary)
//                                }
//                                
//                                Spacer()
//                            }
//                            .padding(.vertical, 8)
//                            
//                            Button(action: {
//                               withAnimation(.spring()) {
//                                   isShowingOshiSelector = true
//                               }
//                               generateHapticFeedback()
//                           }) {
//                               HStack(spacing: 10) {
//                                   Image(systemName: "arrow.triangle.2.circlepath")
//                                       .font(.system(size: 14))
//                                       .foregroundColor(primaryColor)
//                                   Text("別の推しを選択")
//                                       .font(.system(size: 14, weight: .medium))
//                                       .foregroundColor(primaryColor)
//                                   Spacer()
//                                   Image(systemName: "chevron.right")
//                                       .font(.system(size: 12))
//                                       .foregroundColor(.gray)
//                               }
//                               .padding(.horizontal, 16)
//                               .padding(.vertical, 12)
//                               .background(
//                                   RoundedRectangle(cornerRadius: 10)
//                                       .fill(primaryColor.opacity(0.1))
//                                       .overlay(
//                                           RoundedRectangle(cornerRadius: 10)
//                                               .stroke(primaryColor.opacity(0.3), lineWidth: 1)
//                                       )
//                               )
//                           }
//                        }
//                        .padding()
//                        .background(cardColor)
//                        .cornerRadius(16)
//                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
//                        .padding(.horizontal)
//                        .onTapGesture {
//                            generateHapticFeedback()
//                            isShowingEditOshiView = true
//                        }
//                    }
                    VStack(spacing: 10) {
                        HStack {
                            Text("フィードバック")
                                .foregroundColor(.secondary)
                                .frame(alignment: .leading)
                            Spacer()
                        }.padding(.leading)
                        VStack(spacing: 15) {
                            
                            // 不具合報告
                            SettingRow(
                                icon: "exclamationmark.bubble",
                                title: "バグ・ご意見を報告",
                                color: .red,
                                action: { showingBugReportForm = true }
                            )
                            
                            // アプリレビュー
                            SettingRow(
                                icon: "star.fill",
                                title: "アプリを評価する",
                                color: .yellow,
                                action: {
                                    generateHapticFeedback()
                                    showingReviewConfirmation = true
                                }
                            )
                        }
                        .padding()
                        .background(cardColor)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    
                    // おすすめアプリカード
                    VStack(spacing: 10) {
                        HStack {
                            Text("おすすめのアプリ")
                                .foregroundColor(.secondary)
                                .frame(alignment: .leading)
                            Spacer()
                        }.padding(.leading)
                        VStack(spacing: 0) {
                            // おすすめアプリ1
                            Button(action: {
                                generateHapticFeedback()
                                if let url = URL(string: "https://apps.apple.com/us/app/it%E3%82%AF%E3%82%A8%E3%82%B9%E3%83%88-it%E3%83%91%E3%82%B9%E3%83%9D%E3%83%BC%E3%83%88%E3%81%AB%E5%90%88%E6%A0%BC%E3%81%A7%E3%81%8D%E3%82%8B%E3%82%A2%E3%83%97%E3%83%AA/id6469339499") {
                                    openURL(url)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 15) {
                                    // アプリアイコン画像
                                    ZStack {
                                        Image("ITクエスト")
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ITクエスト")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("ゲーム感覚でITパスポートに合格できるアプリ")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            
                            Button(action: {
                                generateHapticFeedback()
                                if let url = URL(string: "https://apps.apple.com/us/app/%E3%83%89%E3%83%AA%E3%83%AB%E3%82%AF%E3%82%A8%E3%82%B9%E3%83%88-%E5%B0%8F%E5%AD%A6%E7%94%9F%E3%81%AE%E5%AD%A6%E7%BF%92%E3%82%A2%E3%83%97%E3%83%AA/id6711333088") {
                                    openURL(url)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 15) {
                                    // アプリアイコン画像
                                    ZStack {
                                        Image("ドリルクエスト")
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ドリルクエスト")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("ゲーム感覚で小学校レベルの勉強ができるアプリ")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            // おすすめアプリ2
                            Button(action: {
                                generateHapticFeedback()
                                if let url = URL(string: "https://apps.apple.com/us/app/%E6%8E%A8%E3%81%97%E3%83%AD%E3%82%B0-%E3%81%82%E3%81%AA%E3%81%9F%E3%81%AE%E6%8E%A8%E3%81%97%E6%B4%BB%E3%82%92%E6%8E%A8%E3%81%97%E3%81%8C%E5%BF%9C%E6%8F%B4%E3%81%97%E3%81%A6%E3%81%8F%E3%82%8C%E3%82%8B%E3%82%A2%E3%83%97%E3%83%AA/id6746085816") {
                                    openURL(url)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 15) {
                                    // アプリアイコン画像
                                    ZStack {
                                        Image("推しログ")
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("推しログ")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("あなたの推し活を推しが応援してくれるアプリ")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            
                            // おすすめアプリ3
                            Button(action: {
                                generateHapticFeedback()
                                if let url = URL(string: "https://apps.apple.com/us/app/%E3%82%B5%E3%83%A9%E3%83%AA%E3%83%BC-%E3%81%8A%E7%B5%A6%E6%96%99%E7%AE%A1%E7%90%86%E3%82%A2%E3%83%97%E3%83%AA/id6670354348") {
                                    openURL(url)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 15) {
                                    // アプリアイコン画像
                                    ZStack {
                                        Image("サラリー｜お給料管理アプリ")
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("サラリー")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("給料日までの給与が確認できる仕事のモチベーション管理アプリ")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                            }
                        }
                        .background(cardColor)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing: 10) {
                        HStack {
                            Text("アプリについて")
                                .foregroundColor(.secondary)
                                .frame(alignment: .leading)
                            Spacer()
                        }.padding(.leading)
                        VStack(spacing: 15) {
                            
                            // 各設定項目にアクションを追加
                            SettingRow(
                                icon: "doc.text.fill",
                                title: "利用規約",
                                color: .green,
                                action: { showingShareSettings = true }
                            )
                            
                            SettingRow(
                                icon: "lock.fill",
                                title: "プライバシーポリシー",
                                color: .orange,
                                action: { showingPrivacySettings = true }
                            )
                            
                            HStack {
                                Image(systemName: "wrench.adjustable")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                                
                                Text("アプリのバージョン")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("1.0.0")
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(cardColor)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationDestination(isPresented: $showingNotificationSettings) {
                WebView(urlString: "https://docs.google.com/forms/d/e/1FAIpQLSfHxhubkEjUw_gexZtQGU8ujZROUgBkBcIhB3R6b8KZpKtOEQ/viewform?embedded=true")
            }
            .navigationDestination(isPresented: $showingPrivacySettings) {
                PrivacyView()
            }
            .navigationDestination(isPresented: $showingShareSettings) {
                TermsOfServiceView()
            }
            .navigationDestination(isPresented: $showingBugReportForm) {
                BugReportView()
            }
        }
        .onAppear {
            checkAdminStatus()
        }
        .alert(isPresented: $isShowingLogoutAlert) {
            Alert(
                title: Text("ログアウト"),
                message: Text("本当にログアウトしますか？"),
                primaryButton: .destructive(Text("ログアウト")) {
                    logout()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .alert(isPresented: $showingReviewConfirmation) {
            Alert(
                title: Text("アプリを評価"),
                message: Text("App Storeでこのアプリを評価しますか？"),
                primaryButton: .default(Text("評価する")) {
                    
                    // または、App Storeのレビューページに直接移動
                    if let writeReviewURL = URL(string: "https://apps.apple.com/app/id6746085816?action=write-review") {
                        openURL(writeReviewURL)
                    }
                },
                secondaryButton: .cancel(Text("後で"))
            )
        }
    }
    
    private func exportAllDataToCSV() {
        // CSV エクスポート機能
        // 全データを取得してCSV形式で保存・共有する処理
        
        let db = Database.database().reference()
        
        // ユーザーデータを取得
        db.child("users").observeSingleEvent(of: .value) { userSnapshot in
            var csvContent = "UserID,Username,SelectedOshiID,CreatedAt\n"
            
            for userChild in userSnapshot.children {
                guard let userSnap = userChild as? DataSnapshot,
                      let userData = userSnap.value as? [String: Any] else { continue }
                
                let userId = userSnap.key
                let username = userData["username"] as? String ?? ""
                let selectedOshiId = userData["selectedOshiId"] as? String ?? ""
                let createdAt = userData["createdAt"] as? TimeInterval ?? 0
                
                csvContent += "\"\(userId)\",\"\(username)\",\"\(selectedOshiId)\",\"\(Date(timeIntervalSince1970: createdAt))\"\n"
            }
            
            // 推し活記録データを取得
            db.child("oshiItems").observeSingleEvent(of: .value) { itemSnapshot in
                csvContent += "\n\nOshiItems\n"
                csvContent += "UserID,OshiID,ItemID,Title,ItemType,CreatedAt,Price\n"
                
                for userChild in itemSnapshot.children {
                    guard let userSnap = userChild as? DataSnapshot else { continue }
                    let userId = userSnap.key
                    
                    for oshiChild in userSnap.children {
                        guard let oshiSnap = oshiChild as? DataSnapshot else { continue }
                        let oshiId = oshiSnap.key
                        
                        for itemChild in oshiSnap.children {
                            guard let itemSnap = itemChild as? DataSnapshot,
                                  let itemData = itemSnap.value as? [String: Any] else { continue }
                            
                            let itemId = itemSnap.key
                            let title = itemData["title"] as? String ?? ""
                            let itemType = itemData["itemType"] as? String ?? ""
                            let createdAt = itemData["createdAt"] as? TimeInterval ?? 0
                            let price = itemData["price"] as? Int ?? 0
                            
                            csvContent += "\"\(userId)\",\"\(oshiId)\",\"\(itemId)\",\"\(title)\",\"\(itemType)\",\"\(Date(timeIntervalSince1970: createdAt))\",\"\(price)\"\n"
                        }
                    }
                }
                
                // 聖地巡礼データを取得
                db.child("locations").observeSingleEvent(of: .value) { locationSnapshot in
                    csvContent += "\n\nLocations\n"
                    csvContent += "UserID,OshiID,LocationID,Title,Category,Latitude,Longitude,Rating,CreatedAt\n"
                    
                    for userChild in locationSnapshot.children {
                        guard let userSnap = userChild as? DataSnapshot else { continue }
                        let userId = userSnap.key
                        
                        for oshiChild in userSnap.children {
                            guard let oshiSnap = oshiChild as? DataSnapshot else { continue }
                            let oshiId = oshiSnap.key
                            
                            for locationChild in oshiSnap.children {
                                guard let locationSnap = locationChild as? DataSnapshot,
                                      let locationData = locationSnap.value as? [String: Any] else { continue }
                                
                                let locationId = locationSnap.key
                                let title = locationData["title"] as? String ?? ""
                                let category = locationData["category"] as? String ?? ""
                                let latitude = locationData["latitude"] as? Double ?? 0
                                let longitude = locationData["longitude"] as? Double ?? 0
                                let rating = locationData["ratingSum"] as? Int ?? 0
                                let createdAt = locationData["createdAt"] as? TimeInterval ?? 0
                                
                                csvContent += "\"\(userId)\",\"\(oshiId)\",\"\(locationId)\",\"\(title)\",\"\(category)\",\"\(latitude)\",\"\(longitude)\",\"\(rating)\",\"\(Date(timeIntervalSince1970: createdAt))\"\n"
                            }
                        }
                    }
                    
                    // CSVファイルを保存・共有
                    DispatchQueue.main.async {
                        self.shareCSVContent(csvContent)
                    }
                }
            }
        }
    }

    private func shareCSVContent(_ content: String) {
        let fileName = "osimono_admin_data_\(DateFormatter.fileDate.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            
            let activityViewController = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityViewController, animated: true)
            }
        } catch {
            print("CSV保存エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 管理者権限チェック
    private func checkAdminStatus() {
        guard let userID = Auth.auth().currentUser?.uid else {
            isAdmin = false
            isCheckingAdminStatus = false
            return
        }
        
        // UserIDで管理者権限をチェック
        isAdmin = adminUserIds.contains(userID)
        isCheckingAdminStatus = false
        
        if isAdmin {
            print("🔑 管理者としてログイン中: \(userID)")
        }
    }
    
    func saveSelectedOshiId(_ oshiId: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedOshiId": oshiId]) { error, _ in
            if let error = error {
                print("推しID保存エラー: \(error.localizedDescription)")
            }
        }
    }

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("画像読み込みエラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    // ログアウト
    func logout() {
        do {
            try Auth.auth().signOut()
            //            authManager.isLoggedIn = false
        } catch {
            print("ログアウトエラー: \(error.localizedDescription)")
        }
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
    }
}

// 設定行
struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            generateHapticFeedback()
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(.vertical, 8)
        }
    }
}

extension DateFormatter {
    static let fileDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

#Preview {
    SettingsView()
}

