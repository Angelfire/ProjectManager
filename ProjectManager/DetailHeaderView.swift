//
//  DetailHeaderView.swift
//  ProjectManager
//

import SwiftUI

struct DetailHeaderView: View {
    let project: Project
    @State private var autorunEnabled: Bool = true
    @State private var selectedTab: String = "Stats"

    private let tabs = ["Terminal", "Git", "Stats", "Description"]

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(project.path)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Autorun toggle
                Button(action: { autorunEnabled.toggle() }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(autorunEnabled ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text("Autorun")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Action buttons row
            HStack(spacing: 8) {
                ActionButton(icon: "folder", label: "Finder", color: .blue) {
                    openInFinder()
                }
                ActionButton(icon: "terminal", label: "Terminal", color: .green)
                ActionButton(icon: "curlybraces", label: "Zed", color: .blue)
                ActionButton(icon: "cat", label: "GitHub Des...", color: .purple)
                ActionButton(icon: "cursorarrow.click.2", label: "Cursor", color: .cyan)
                ActionButton(icon: "archivebox", label: "Archive", color: .gray)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Tab bar
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == tab
                                    ? Color.white.opacity(0.1)
                                    : .clear
                            )
                            .clipShape(.rect(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.03))

            Divider()
                .opacity(0.3)
        }
    }

    private func openInFinder() {
        let expandedPath = project.path.replacingOccurrences(of: "~", with: NSHomeDirectory())
        let url = URL(fileURLWithPath: expandedPath)
        NSWorkspace.shared.open(url)
    }
}

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
