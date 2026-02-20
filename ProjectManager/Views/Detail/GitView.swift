//
//  GitView.swift
//  ProjectManager
//

import SwiftUI

struct GitView: View {
    let project: Project
    @State private var currentBranch: String = ""
    @State private var lastCommitMessage: String = ""
    @State private var lastCommitAuthor: String = ""
    @State private var lastCommitDate: String = ""
    @State private var recentCommits: [GitCommit] = []
    @State private var isLoading = true

    private var expandedPath: String {
        project.path.replacingOccurrences(of: "~", with: NSHomeDirectory())
    }

    var body: some View {
        if !project.hasGit {
            noGitView
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Branch & Remote
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            infoRow(
                                icon: "arrow.triangle.branch", label: "Branch",
                                value: currentBranch, color: .green)
                            Divider().opacity(0.3)
                            infoRow(
                                icon: "link", label: "Remote",
                                value: project.gitRemoteURL.isEmpty
                                    ? "No remote" : project.gitRemoteURL, color: .blue)
                        }
                        .padding(4)
                    } label: {
                        Label("Repository", systemImage: "externaldrive.fill.badge.checkmark")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    // Last Commit
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.orange)
                                    .frame(width: 18)
                                Text(lastCommitMessage.isEmpty ? "—" : lastCommitMessage)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                            }
                            Divider().opacity(0.3)
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text(lastCommitAuthor.isEmpty ? "—" : lastCommitAuthor)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text(lastCommitDate.isEmpty ? "—" : lastCommitDate)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(4)
                    } label: {
                        Label("Last Commit", systemImage: "arrow.uturn.left.circle")
                            .font(.system(size: 13, weight: .semibold))
                    }

                    // Recent Commits
                    GroupBox {
                        if recentCommits.isEmpty && !isLoading {
                            Text("No commits found")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(4)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(recentCommits) { commit in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(commit.shortHash)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.yellow)
                                            .frame(width: 60, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(commit.message)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text("\(commit.author) • \(commit.relativeDate)")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 4)

                                    if commit.id != recentCommits.last?.id {
                                        Divider().opacity(0.2)
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Recent Commits", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .padding(20)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .task(id: project.id) {
                await loadGitInfo()
            }
        }
    }

    @ViewBuilder
    private var noGitView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Not a Git Repository")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Initialize a git repository to see branch and commit info.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func loadGitInfo() async {
        isLoading = true
        defer { isLoading = false }

        currentBranch = runGit("rev-parse --abbrev-ref HEAD")
        lastCommitMessage = runGit("log -1 --format=%s")
        lastCommitAuthor = runGit("log -1 --format=%an")
        lastCommitDate = runGit("log -1 --format=%ar")

        // Load recent commits
        let logOutput = runGit("log --oneline -10 --format=%h||%s||%an||%ar")
        recentCommits =
            logOutput
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .map { line in
                let parts = line.components(separatedBy: "||")
                return GitCommit(
                    shortHash: parts.count > 0 ? parts[0] : "",
                    message: parts.count > 1 ? parts[1] : "",
                    author: parts.count > 2 ? parts[2] : "",
                    relativeDate: parts.count > 3 ? parts[3] : ""
                )
            }
    }

    private func runGit(_ arguments: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments.components(separatedBy: " ")
        process.currentDirectoryURL = URL(fileURLWithPath: expandedPath)
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(
                in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }
}
