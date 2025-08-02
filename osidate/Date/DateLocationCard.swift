//
//  DateLocationCard.swift
//  osidate
//
//  Created by Apple on 2025/08/01.
//

import SwiftUI

struct DateLocationCard: View {
    let location: DateLocation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text(location.name)
                    .font(.headline)
                
                Text(location.description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            .shadow(radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
