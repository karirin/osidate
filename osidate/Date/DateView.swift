//
//  DateView.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI

// MARK: - デートビュー
struct DateView: View {
    @ObservedObject var viewModel: RomanceAppViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("デート場所を選んでください")
                    .font(.title2)
                    .padding()
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(viewModel.availableLocations) { location in
                            DateLocationCard(location: location) {
                                viewModel.startDate(at: location)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("デート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}
