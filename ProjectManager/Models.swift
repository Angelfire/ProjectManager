//
//  Models.swift
//  ProjectManager
//

import Foundation

enum ProjectType: String, Codable {
    case xcodeProject = "Xcode Project"
    case swiftPackage = "Swift Package"
    case nodeJS = "Node.js"
    case deno = "Deno"
    case bun = "Bun"
}

struct PlatformInfo: Codable, Hashable {
    let name: String
    let file: String
}

struct DependencyInfo: Codable, Hashable {
    let name: String
    let description: String
}

// MARK: - Health

enum HealthLevel: String {
    case good, warning, critical
}

struct HealthInfo {
    var heavyFolderSize: String = "—"
    var heavyFolderName: String = ""
    var unpushedCommits: Int = 0
    var untrackedFiles: Int = 0
    var modifiedFiles: Int = 0
    var isLoading: Bool = true

    var level: HealthLevel {
        if unpushedCommits > 10 { return .critical }
        if unpushedCommits > 0 || modifiedFiles > 3 { return .warning }
        return .good
    }

    var score: Int {
        var s = 100
        s -= unpushedCommits * 3
        s -= modifiedFiles * 2
        s -= untrackedFiles
        return max(0, min(100, s))
    }
}

struct Project: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let type: ProjectType
    let icon: String
    let path: String
    var isRunning: Bool = false

    // Overview
    let configFiles: [String]
    let totalFiles: Int
    let gitRemoteURL: String
    let hasGit: Bool

    // Platform
    let platforms: [PlatformInfo]

    // Dependencies
    let dependencies: [DependencyInfo]

    init(
        id: UUID = UUID(),
        name: String,
        type: ProjectType,
        icon: String,
        path: String,
        isRunning: Bool = false,
        configFiles: [String],
        totalFiles: Int,
        gitRemoteURL: String,
        hasGit: Bool,
        platforms: [PlatformInfo],
        dependencies: [DependencyInfo]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.path = path
        self.isRunning = isRunning
        self.configFiles = configFiles
        self.totalFiles = totalFiles
        self.gitRemoteURL = gitRemoteURL
        self.hasGit = hasGit
        self.platforms = platforms
        self.dependencies = dependencies
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, icon, path
        case configFiles, totalFiles, gitRemoteURL, hasGit
        case platforms, dependencies
    }
}
