//
//  ProjectDetector.swift
//  ProjectManager
//

import Foundation

/// Detects project type, platforms, config files, and git info from a directory.
enum ProjectDetector {

    // MARK: - Project Type

    static func detectType(at url: URL) -> ProjectType {
        let contents = directoryContents(at: url)

        // Swift / Xcode
        if contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") })
        {
            return .xcodeProject
        }
        if contents.contains("Package.swift") {
            return .swiftPackage
        }

        // Deno
        if contents.contains("deno.json") || contents.contains("deno.jsonc") {
            return .deno
        }

        // Bun
        if contents.contains("bunfig.toml") || contents.contains("bun.lockb")
            || contents.contains("bun.lock")
        {
            return .bun
        }

        // Node.js
        if contents.contains("package.json") {
            return .nodeJS
        }

        // Plain web (HTML/CSS/JS without any framework)
        if contents.contains(where: { $0.hasSuffix(".html") }) {
            return .web
        }

        return .xcodeProject
    }

    // MARK: - Platforms

    static func detectPlatforms(at url: URL) -> [PlatformInfo] {
        let contents = directoryContents(at: url)
        var platforms: [PlatformInfo] = []

        // Swift
        if contents.contains("Package.swift") {
            platforms.append(PlatformInfo(name: "Swift", file: "Package.swift"))
        }
        if let xcodeproj = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
            platforms.append(PlatformInfo(name: "Xcode", file: xcodeproj))
        }

        // Node.js / Bun
        if contents.contains("package.json") {
            let runtime: String
            if contents.contains("bunfig.toml") || contents.contains("bun.lockb")
                || contents.contains("bun.lock")
            {
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

        // Plain web (HTML/CSS/JS)
        if contents.contains(where: { $0.hasSuffix(".html") }) {
            let htmlFile =
                contents.first(where: { $0 == "index.html" })
                ?? contents.first(where: { $0.hasSuffix(".html") })
                ?? "index.html"
            platforms.append(PlatformInfo(name: "HTML", file: htmlFile))
        }
        if contents.contains(where: { $0.hasSuffix(".css") }) {
            platforms.append(
                PlatformInfo(
                    name: "CSS",
                    file: contents.first(where: { $0.hasSuffix(".css") }) ?? "style.css"))
        }
        if contents.contains(where: { $0.hasSuffix(".js") }) {
            platforms.append(
                PlatformInfo(
                    name: "JavaScript",
                    file: contents.first(where: { $0.hasSuffix(".js") }) ?? "script.js"))
        }

        return platforms
    }

    // MARK: - Config Files

    static func detectConfigFiles(at url: URL) -> [String] {
        let contents = directoryContents(at: url)

        let knownConfigs = [
            "package.json", "tsconfig.json", "deno.json", "deno.jsonc",
            "bunfig.toml", "Package.swift", ".env", ".env.local",
            "Makefile", "Dockerfile", "docker-compose.yml", "docker-compose.yaml",
            ".eslintrc.json", ".eslintrc.js", ".prettierrc", ".prettierrc.json",
            "vite.config.ts", "vite.config.js", "next.config.js", "next.config.mjs",
            "astro.config.mjs", "astro.config.ts", "tailwind.config.js", "tailwind.config.ts",
            "postcss.config.js", "postcss.config.cjs", "webpack.config.js",
            "rollup.config.js", ".gitignore", "README.md", "LICENSE",
            "index.html", "manifest.json", "robots.txt", "sitemap.xml", ".htaccess",
        ]

        return contents.filter { file in
            knownConfigs.contains(file) || file.hasSuffix(".xcodeproj")
        }.sorted()
    }

    // MARK: - File Count

    static func countFiles(at url: URL) -> Int {
        directoryContents(at: url).count
    }

    // MARK: - Git Info

    static func detectGitInfo(at url: URL) -> (hasGit: Bool, remoteURL: String) {
        let gitDir = url.appendingPathComponent(".git")

        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            return (false, "")
        }

        let configPath = gitDir.appendingPathComponent("config").path
        guard let configContent = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return (true, "")
        }

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

    // MARK: - Helper

    private static func directoryContents(at url: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    }
}
