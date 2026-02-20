//
//  ActionButton.swift
//  ProjectManager
//

import SwiftUI

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(.rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
