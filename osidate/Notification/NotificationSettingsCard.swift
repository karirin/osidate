//
//  NotificationSettingsCard.swift
//  osidate
//
//  設定画面の「推しからの通知」ON/OFF
//

import SwiftUI
import UserNotifications

struct NotificationSettingsCard: View {
    @State private var isOn = OshiNotificationManager.shared.isEnabled
    @State private var isDeniedBySystem = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("通知")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.leading)

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(get: { isOn }, set: handleToggle)) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.pink)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("推しからのメッセージ")
                                .foregroundColor(.primary)
                            Text("朝・夜のあいさつや誕生日・記念日にお知らせします")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .tint(.pink)

                if isOn && isDeniedBySystem {
                    Button(action: openSystemSettings) {
                        Text("iPhoneの設定で通知がオフになっています。タップして設定を開く")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding()
            .background(cardColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
        .onAppear(perform: refreshSystemStatus)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshSystemStatus() }
        }
    }

    private func handleToggle(_ newValue: Bool) {
        generateHapticFeedback()
        isOn = newValue
        OshiNotificationManager.shared.isEnabled = newValue
        guard newValue else { return }

        // OFF→ON のとき、まだ許可を求めていなければここで求める
        OshiNotificationManager.shared.requestAuthorization { _ in
            refreshSystemStatus()
        }
    }

    private func refreshSystemStatus() {
        OshiNotificationManager.shared.authorizationStatus { status in
            isDeniedBySystem = status == .denied
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
