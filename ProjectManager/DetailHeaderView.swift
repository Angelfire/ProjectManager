//
//  DetailHeaderView.swift
//  ProjectManager
//

import SwiftUI

struct DetailHeaderView: View {
    let project: Project
    @Binding var selectedTab: String

    private let tabs = ["Description", "Terminal", "Git"]

    var body: some View {
        VStack(spacing: 0) {
            // Action buttons
            HStack(spacing: 8) {
                ActionButton(icon: "folder", label: "Finder", color: .blue) {
                    openInApp("Finder")
                }
                ActionButton(icon: "chevron.left.forwardslash.chevron.right", label: "VSCode", color: .blue) {
                    openInApp("VSCode")
                }
                ActionButton(icon: "cursorarrow.rays", label: "Cursor", color: .cyan) {
                    openInApp("Cursor")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Tab bar
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab)
                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .contentShape(.rect)
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
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.03))

            Divider()
                .opacity(0.3)
        }
    }

    private var expandedPath: String {
        project.path.replacingOccurrences(of: "~", with: NSHomeDirectory())
    }

    private func openInApp(_ appName: String) {
        let url = URL(fileURLWithPath: expandedPath)
        if appName == "Finder" {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expandedPath)
        } else {
            let appURL: URL? = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID(for: appName))
            if let appURL {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config)
            }
        }
    }

    private func openInTerminal() {
        let script = """
        tell application "Terminal"
            activate
            do script "cd \\\"\(expandedPath)\\\""
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private func bundleID(for appName: String) -> String {
        switch appName {
        case "VSCode": return "com.microsoft.VSCode"
        case "Cursor": return "com.todesktop.230313mzl4w4u92"
        default: return ""
        }
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
