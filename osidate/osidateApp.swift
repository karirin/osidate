//
//  osidateApp.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI
import FirebaseCore

@main
struct osidateApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: RomanceAppViewModel())
        }
    }
}
