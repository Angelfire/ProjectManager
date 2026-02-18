//
//  ProjectStore.swift
//  ProjectManager
//

import Foundation

@MainActor
@Observable
class ProjectStore {
    var projects: [Project] = []

    var runningProjects: [Project] {
        projects.filter(\.isRunning)
    }

    func addProject(from url: URL) {
        let name = url.lastPathComponent
        let path = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")

        let type = detectProjectType(at: url)
        let platforms = detectPlatforms(at: url)

        let project = Project(
            name: name,
            type: type,
            icon: "",
            path: path,
            projectStarted: "",
            totalCommits: 0,
            contributors: 0,
            platforms: platforms,
            dependencies: []
        )

        projects.append(project)
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

    private func detectPlatforms(at url: URL) -> [(name: String, file: String)] {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
        var platforms: [(name: String, file: String)] = []

        // Swift
        if contents.contains("Package.swift") {
            platforms.append(("Swift", "Package.swift"))
        }
        if contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
            if let xcodeproj = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                platforms.append(("Xcode", xcodeproj))
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
            platforms.append((runtime, "package.json"))
        }

        // Deno
        if contents.contains("deno.json") {
            platforms.append(("Deno", "deno.json"))
        } else if contents.contains("deno.jsonc") {
            platforms.append(("Deno", "deno.jsonc"))
        }

        // TypeScript
        if contents.contains("tsconfig.json") {
            platforms.append(("TypeScript", "tsconfig.json"))
        }

        return platforms
    }
}
