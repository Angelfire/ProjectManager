//
//  StatsView.swift
//  ProjectManager
//

import SwiftUI

struct StatsView: View {
    let project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PlatformSection(platforms: project.platforms)

                if !project.dependencies.isEmpty {
                    DependenciesSection(dependencies: project.dependencies)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Platform Section

struct PlatformSection: View {
    let platforms: [(name: String, file: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Platform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                ForEach(Array(platforms.enumerated()), id: \.offset) { _, platform in
                    PlatformCard(name: platform.name, file: platform.file)
                }
            }
        }
    }
}

struct PlatformCard: View {
    let name: String
    let file: String

    private var platformIcon: String {
        switch name {
        case "Node.js": "shippingbox.fill"
        case "TypeScript": "doc.text.fill"
        case "Deno": "lizard.fill"
        case "Bun": "takeoutbag.and.cup.and.straw.fill"
        case "Swift": "swift"
        case "Xcode": "hammer.fill"
        default: "questionmark.square"
        }
    }

    private var platformColor: Color {
        switch name {
        case "Node.js": .green
        case "TypeScript": .blue
        case "Deno": .white
        case "Bun": .yellow
        case "Swift": .orange
        case "Xcode": .blue
        default: .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: platformIcon)
                .font(.system(size: 22))
                .foregroundStyle(platformColor)
                .frame(width: 36, height: 36)
                .background(platformColor.opacity(0.15))
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(file)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Dependencies Section

struct DependenciesSection: View {
    let dependencies: [(name: String, description: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dependencies")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(dependencies.enumerated()), id: \.offset) { _, dep in
                    DependencyCard(name: dep.name, description: dep.description)
                }
            }
        }
    }
}

struct DependencyCard: View {
    let name: String
    let description: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .font(.system(size: 18))
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .background(Color.orange.opacity(0.12))
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
