//
//  DescriptionView.swift
//  ProjectManager
//

import SwiftUI

struct DescriptionView: View {
    let project: Project

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                OverviewSection(project: project)
                PlatformSection(platforms: project.platforms)

                if !project.configFiles.isEmpty {
                    ConfigFilesSection(configFiles: project.configFiles)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Overview Section

private struct OverviewSection: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 1) {
                OverviewRow(
                    icon: "folder.fill",
                    iconColor: .blue,
                    label: "Directory",
                    value: project.path
                ) {
                    CopyButton {
                        let expandedPath = project.path.replacingOccurrences(
                            of: "~", with: NSHomeDirectory()
                        )
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(expandedPath, forType: .string)
                    }
                    SmallActionButton(icon: "folder", tooltip: "Open in Finder") {
                        let expandedPath = project.path.replacingOccurrences(
                            of: "~", with: NSHomeDirectory()
                        )
                        NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath))
                    }
                }

                OverviewRow(
                    icon: "doc.text.fill",
                    iconColor: .orange,
                    label: "Type",
                    value: project.type.rawValue
                )

                OverviewRow(
                    icon: "doc.on.doc.fill",
                    iconColor: .purple,
                    label: "Files",
                    value: "\(project.totalFiles) items"
                )

                if project.hasGit {
                    OverviewRow(
                        icon: "arrow.triangle.branch",
                        iconColor: .green,
                        label: "Git",
                        value: gitDisplayValue
                    ) {
                        if !project.gitRemoteURL.isEmpty {
                            CopyButton {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(
                                    project.gitRemoteURL, forType: .string
                                )
                            }
                        }
                    }
                } else {
                    OverviewRow(
                        icon: "arrow.triangle.branch",
                        iconColor: .gray,
                        label: "Git",
                        value: "Not initialized"
                    )
                }
            }
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var gitDisplayValue: String {
        if project.gitRemoteURL.isEmpty {
            return "Local repository"
        }
        return project.gitRemoteURL
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: ".git", with: "")
    }
}

// MARK: - Overview Row

private struct OverviewRow<Actions: View>: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    @ViewBuilder var actions: Actions

    init(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.value = value
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(.rect(cornerRadius: 6))

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            actions
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
    }
}

// MARK: - Small Action Buttons

private struct CopyButton: View {
    let action: () -> Void
    @State private var copied = false

    var body: some View {
        Button {
            action()
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10))
                .foregroundStyle(copied ? .green : .secondary)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.06))
                .clipShape(.rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
        .accessibilityLabel("Copy")
    }
}

private struct SmallActionButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.06))
                .clipShape(.rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}

// MARK: - Config Files Section

private struct ConfigFilesSection: View {
    let configFiles: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration Files")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ], spacing: 10
            ) {
                ForEach(configFiles, id: \.self) { file in
                    ConfigFileCard(fileName: file)
                }
            }
        }
    }
}

private struct ConfigFileCard: View {
    let fileName: String

    private var fileIcon: String {
        switch fileName {
        case _ where fileName.hasSuffix(".json"):
            "curlybraces"
        case _ where fileName.hasSuffix(".yml"), _ where fileName.hasSuffix(".yaml"):
            "list.bullet.indent"
        case _ where fileName.hasSuffix(".swift"):
            "swift"
        case _ where fileName.hasSuffix(".toml"):
            "gearshape"
        case "Dockerfile", ".dockerignore":
            "shippingbox.fill"
        case ".gitignore", ".gitattributes":
            "arrow.triangle.branch"
        case _ where fileName.hasPrefix(".env"):
            "lock.fill"
        case _ where fileName.hasSuffix(".mjs"), _ where fileName.hasSuffix(".js"),
            _ where fileName.hasSuffix(".ts"), _ where fileName.hasSuffix(".cjs"):
            "doc.text.fill"
        default:
            "doc.fill"
        }
    }

    private var fileColor: Color {
        switch fileName {
        case _ where fileName.hasSuffix(".json"):
            .yellow
        case _ where fileName.hasSuffix(".yml"), _ where fileName.hasSuffix(".yaml"):
            .pink
        case _ where fileName.hasSuffix(".swift"), "Package.swift":
            .orange
        case "Dockerfile", ".dockerignore":
            .cyan
        case ".gitignore", ".gitattributes":
            .green
        case _ where fileName.hasPrefix(".env"):
            .red
        case _ where fileName.hasSuffix(".mjs"), _ where fileName.hasSuffix(".js"),
            _ where fileName.hasSuffix(".ts"), _ where fileName.hasSuffix(".cjs"):
            .blue
        default:
            .gray
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon)
                .font(.system(size: 12))
                .foregroundStyle(fileColor)

            Text(fileName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Platform Section

private struct PlatformSection: View {
    let platforms: [PlatformInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Platform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                ForEach(platforms, id: \.name) { platform in
                    PlatformCard(name: platform.name, file: platform.file)
                }
            }
        }
    }
}

private struct PlatformCard: View {
    let name: String
    let file: String

    private var platformIcon: String {
        switch name {
        case "Node.js": "shippingbox.fill"
        case "TypeScript": "doc.text.fill"
        case "Deno": "lizard.fill"
        case "Bun": "takeoutbag.and.cup.and.straw.fill"
        default: "questionmark.square"
        }
    }

    private var platformColor: Color {
        switch name {
        case "Node.js": .green
        case "TypeScript": .blue
        case "Deno": .white
        case "Bun": .yellow
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
