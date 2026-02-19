//
//  ProjectStore.swift
//  ProjectManager
//

import Foundation

@MainActor
@Observable
class ProjectStore {
    var projects: [Project] = []

    private static var saveURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ProjectManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("projects.json")
    }

    var runningProjects: [Project] {
        projects.filter(\.isRunning)
    }

    init() {
        loadProjects()
    }

    func addProject(from url: URL) {
        // Avoid duplicates
        let path = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        guard !projects.contains(where: { $0.path == path }) else { return }

        let name = url.lastPathComponent
        let type = detectProjectType(at: url)
        let platforms = detectPlatforms(at: url)
        let configFiles = detectConfigFiles(at: url)
        let totalFiles = countFiles(at: url)
        let (hasGit, gitRemoteURL) = detectGitInfo(at: url)

        let project = Project(
            name: name,
            type: type,
            icon: "",
            path: path,
            configFiles: configFiles,
            totalFiles: totalFiles,
            gitRemoteURL: gitRemoteURL,
            hasGit: hasGit,
            platforms: platforms,
            dependencies: []
        )

        projects.append(project)
        saveProjects()
    }

    func removeProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }

    // MARK: - Persistence

    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: Self.saveURL, options: .atomic)
        } catch {
            // Save failed silently
        }
    }

    private func loadProjects() {
        guard let data = try? Data(contentsOf: Self.saveURL),
              let saved = try? JSONDecoder().decode([Project].self, from: data) else {
            return
        }
        projects = saved
    }

    private func detectProjectType(at url: URL) -> ProjectType {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []

        // Swift detection
        if contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
            return .xcodeProject
        }
        if contents.contains("Package.swift") {
            return .swiftPackage
        }

        // Deno detection (deno.json or deno.jsonc)
        if contents.contains("deno.json") || contents.contains("deno.jsonc") {
            return .deno
        }

        // Bun detection (bunfig.toml or bun.lockb)
        if contents.contains("bunfig.toml") || contents.contains("bun.lockb") || contents.contains("bun.lock") {
            return .bun
        }

        // Node.js detection (package.json without Bun/Deno indicators)
        if contents.contains("package.json") {
            return .nodeJS
        }

        return .xcodeProject
    }

    private func detectPlatforms(at url: URL) -> [PlatformInfo] {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
        var platforms: [PlatformInfo] = []

        // Swift
        if contents.contains("Package.swift") {
            platforms.append(PlatformInfo(name: "Swift", file: "Package.swift"))
        }
        if contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
            if let xcodeproj = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                platforms.append(PlatformInfo(name: "Xcode", file: xcodeproj))
            }
        }

        // Node.js / Bun
        if contents.contains("package.json") {
            let runtime: String
            if contents.contains("bunfig.toml") || contents.contains("bun.lockb") || contents.contains("bun.lock") {
                runtime = "Bun"
            } else {
                runtime = "Node.js"
            }
            platforms.append(PlatformInfo(name: runtime, file: "package.json"))
        }

        // Deno
        if contents.contains("deno.json") {
            platforms.append(PlatformInfo(name: "Deno", file: "deno.json"))
        } else if contents.contains("deno.jsonc") {
            platforms.append(PlatformInfo(name: "Deno", file: "deno.jsonc"))
        }

        // TypeScript
        if contents.contains("tsconfig.json") {
            platforms.append(PlatformInfo(name: "TypeScript", file: "tsconfig.json"))
        }

        return platforms
    }

    private func detectConfigFiles(at url: URL) -> [String] {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []

        let knownConfigs = [
            "package.json", "tsconfig.json", "deno.json", "deno.jsonc",
            "bunfig.toml", "Package.swift", ".env", ".env.local",
            "Makefile", "Dockerfile", "docker-compose.yml", "docker-compose.yaml",
            ".eslintrc.json", ".eslintrc.js", ".prettierrc", ".prettierrc.json",
            "vite.config.ts", "vite.config.js", "next.config.js", "next.config.mjs",
            "astro.config.mjs", "astro.config.ts", "tailwind.config.js", "tailwind.config.ts",
            "postcss.config.js", "postcss.config.cjs", "webpack.config.js",
            "rollup.config.js", ".gitignore", "README.md", "LICENSE"
        ]

        return contents.filter { file in
            knownConfigs.contains(file) || file.hasSuffix(".xcodeproj")
        }.sorted()
    }

    private func countFiles(at url: URL) -> Int {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
        return contents.count
    }

    private func detectGitInfo(at url: URL) -> (hasGit: Bool, remoteURL: String) {
        let gitDir = url.appendingPathComponent(".git")
        let fm = FileManager.default

        guard fm.fileExists(atPath: gitDir.path) else {
            return (false, "")
        }

        let configPath = gitDir.appendingPathComponent("config").path
        guard let configContent = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return (true, "")
        }

        // Parse git remote URL from config
        let lines = configContent.components(separatedBy: .newlines)
        var inRemoteOrigin = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[remote \"origin\"]" {
                inRemoteOrigin = true
                continue
            }
            if trimmed.hasPrefix("[") {
                inRemoteOrigin = false
                continue
            }
            if inRemoteOrigin, trimmed.hasPrefix("url = ") {
                let url = String(trimmed.dropFirst(6))
                return (true, url)
            }
        }

        return (true, "")
    }
}
