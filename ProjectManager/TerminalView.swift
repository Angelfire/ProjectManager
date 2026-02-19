//
//  TerminalView.swift
//  ProjectManager
//

import SwiftUI

struct TerminalView: View {
    let project: Project
    var runner: ProcessRunner

    private var lines: [String] {
        runner.output[project.id] ?? []
    }

    private var serverURL: String? {
        runner.detectedURL[project.id]
    }

    private var isRunning: Bool {
        runner.isRunning(project.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Server URL banner
            if let url = serverURL {
                ServerBanner(url: url)
            }

            if lines.isEmpty && !isRunning {
                // Empty state
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No output yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Press Run to start the project")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                Spacer()
            } else {
                // Terminal output
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                TerminalLine(text: line)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: lines.count) { _, newCount in
                        if newCount > 0 {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(newCount - 1, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.1))
                .clipShape(.rect(cornerRadius: 8))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Bottom toolbar
            HStack(spacing: 12) {
                if isRunning {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                        if let cmd = runner.runningCommand[project.id] {
                            Text(cmd)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if !lines.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.gray.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text("Stopped")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !lines.isEmpty {
                    Button {
                        runner.clearOutput(for: project.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Clear")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Server Banner

private struct ServerBanner: View {
    let url: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 13))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 1) {
                Text("Server running")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                Text(url)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.blue)
                    .textSelection(.enabled)
            }

            Spacer()

            Button {
                if let nsURL = URL(string: url) {
                    NSWorkspace.shared.open(nsURL)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                    Text("Open in Browser")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.6))
                .clipShape(.rect(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("Copy URL")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Terminal Line

private struct TerminalLine: View {
    let text: String

    private var cleaned: String {
        cleanANSI(text)
    }

    private var lineColor: Color {
        let lower = cleaned.lowercased()
        if text.hasPrefix("$") {
            return .green
        } else if text.hasPrefix("⚠") {
            return .yellow
        } else if text.hasPrefix("⏹") {
            return .secondary
        } else if lower.contains("error") || lower.contains("failed") {
            return .red.opacity(0.9)
        } else if lower.contains("warn") {
            return .yellow.opacity(0.9)
        } else if lower.contains("ready in") || lower.contains("listening") || lower.contains("started") {
            return .green.opacity(0.9)
        } else if lower.contains("http://") || lower.contains("https://") {
            return .cyan
        }
        return .white.opacity(0.8)
    }

    private var lineFont: Font {
        if text.hasPrefix("$") {
            return .system(size: 12, weight: .semibold, design: .monospaced)
        }
        return .system(size: 11.5, design: .monospaced)
    }

    var body: some View {
        Text(cleaned)
            .font(lineFont)
            .foregroundStyle(lineColor)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1)
    }

    /// Strip ANSI escape sequences for display
    private func cleanANSI(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: "\u{1B}\\[[0-9;]*[a-zA-Z]",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\u{1B}\\]8;;[^\u{1B}]*\u{1B}\\\\",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\u{1B}\\[[^m]*m",
                with: "",
                options: .regularExpression
            )
    }
}
