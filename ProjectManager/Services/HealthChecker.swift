//
//  HealthChecker.swift
//  ProjectManager
//

import Foundation

@MainActor
@Observable
class HealthChecker {
    var healthData: [UUID: HealthInfo] = [:]

    func health(for id: UUID) -> HealthInfo {
        healthData[id] ?? HealthInfo()
    }

    func refresh(project: Project) async {
        healthData[project.id] = HealthInfo(isLoading: true)

        let path = (project.path as NSString).expandingTildeInPath
        let type = project.type
        let hasGit = project.hasGit

        let result = await Task.detached { () -> HealthInfo in
            let folder = self.detectHeavyFolderSync(at: path, type: type)
            let git = self.detectGitStatusSync(at: path, hasGit: hasGit)

            var info = HealthInfo(isLoading: false)
            info.heavyFolderName = folder.name
            info.heavyFolderSize = folder.size
            info.unpushedCommits = git.unpushed
            info.modifiedFiles = git.modified
            info.untrackedFiles = git.untracked
            return info
        }.value

        healthData[project.id] = result
    }

    // MARK: - Heavy Folder Size

    nonisolated private func detectHeavyFolderSync(at path: String, type: ProjectType) -> (
        name: String, size: String
    ) {
        let folderName: String
        switch type {
        case .nodeJS, .bun, .deno:
            folderName = "node_modules"
        case .swiftPackage, .xcodeProject:
            folderName = ".build"
        case .web:
            folderName = "node_modules"
        }

        let fullPath = (path as NSString).appendingPathComponent(folderName)
        guard FileManager.default.fileExists(atPath: fullPath) else {
            return (folderName, "")
        }

        let size = shell("du -sh \"\(fullPath)\" | cut -f1").trimmingCharacters(
            in: .whitespacesAndNewlines)
        return (folderName, size.isEmpty ? "Unknown" : size)
    }

    // MARK: - Git Status

    nonisolated private func detectGitStatusSync(at path: String, hasGit: Bool) -> (
        unpushed: Int, modified: Int, untracked: Int
    ) {
        guard hasGit else { return (0, 0, 0) }

        let unpushedStr = shell("cd \"\(path)\" && git rev-list --count @{u}..HEAD 2>/dev/null")
        let unpushed = Int(unpushedStr.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let statusOutput = shell("cd \"\(path)\" && git status --porcelain 2>/dev/null")
        let lines = statusOutput.components(separatedBy: "\n").filter { !$0.isEmpty }

        var modified = 0
        var untracked = 0
        for line in lines {
            if line.hasPrefix("??") {
                untracked += 1
            } else {
                modified += 1
            }
        }

        return (unpushed, modified, untracked)
    }

    // MARK: - Shell Helper

    nonisolated private func shell(_ command: String) -> String {
        let process = Process()
        let outPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice

        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? NSHomeDirectory()
        let pnpmHome = "\(home)/Library/pnpm"
        let extraPaths = [
            pnpmHome,
            "\(home)/.local/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        env["PNPM_HOME"] = pnpmHome
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
