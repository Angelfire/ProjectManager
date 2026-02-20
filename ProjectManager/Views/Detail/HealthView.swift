//
//  HealthView.swift
//  ProjectManager
//

import SwiftUI

struct HealthView: View {
    let project: Project
    let checker: HealthChecker

    private var info: HealthInfo {
        checker.health(for: project.id)
    }

    var body: some View {
        if info.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Analyzing project health…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: project.id) {
                await checker.refresh(project: project)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Score card
                    scoreCard

                    // Git status
                    if project.hasGit {
                        gitStatusCard
                    }

                    // Heavy folder
                    if !info.heavyFolderSize.isEmpty {
                        heavyFolderCard
                    }
                }
                .padding(20)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    Task { await checker.refresh(project: project) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(20)
                .help("Refresh health check")
            }
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        GroupBox {
            HStack(spacing: 20) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: Double(info.score) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(info.score)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor)
                        Text("/100")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(scoreColor)
                            .frame(width: 8, height: 8)
                        Text(
                            info.level == .good
                                ? "Healthy"
                                : info.level == .warning ? "Needs Attention" : "Critical"
                        )
                        .font(.system(size: 14, weight: .semibold))
                    }
                    Text(healthSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(4)
        } label: {
            Label("Health Score", systemImage: "heart.text.clipboard")
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var scoreColor: Color {
        switch info.level {
        case .good: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    private var healthSummary: String {
        var parts: [String] = []
        if info.unpushedCommits > 0 {
            parts.append(
                "\(info.unpushedCommits) unpushed commit\(info.unpushedCommits == 1 ? "" : "s")")
        }
        if info.modifiedFiles > 0 {
            parts.append("\(info.modifiedFiles) modified file\(info.modifiedFiles == 1 ? "" : "s")")
        }
        if info.untrackedFiles > 0 {
            parts.append(
                "\(info.untrackedFiles) untracked file\(info.untrackedFiles == 1 ? "" : "s")")
        }
        if parts.isEmpty {
            parts.append("Everything looks good")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Git Status Card

    private var gitStatusCard: some View {
        GroupBox {
            VStack(spacing: 10) {
                statusRow(
                    icon: "arrow.up.circle", label: "Unpushed Commits",
                    value: "\(info.unpushedCommits)",
                    color: info.unpushedCommits > 0 ? .orange : .green)
                Divider().opacity(0.3)
                statusRow(
                    icon: "pencil.circle", label: "Modified Files", value: "\(info.modifiedFiles)",
                    color: info.modifiedFiles > 0 ? .yellow : .green)
                Divider().opacity(0.3)
                statusRow(
                    icon: "questionmark.circle", label: "Untracked Files",
                    value: "\(info.untrackedFiles)",
                    color: info.untrackedFiles > 0 ? .secondary : .green)
            }
            .padding(4)
        } label: {
            Label("Git Status", systemImage: "arrow.triangle.branch")
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private func statusRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Heavy Folder Card

    private var heavyFolderCard: some View {
        GroupBox {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                Text(info.heavyFolderName)
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Text(info.heavyFolderSize)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(folderSizeColor)
            }
            .padding(4)
        } label: {
            Label("Disk Usage", systemImage: "externaldrive")
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var folderSizeColor: Color {
        let size = info.heavyFolderSize.lowercased()
        if size.contains("g") { return .red }
        if size.contains("m") {
            if let num = Double(
                size.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression))
            {
                return num > 500 ? .orange : .secondary
            }
        }
        return .secondary
    }
}
