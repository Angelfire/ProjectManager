//
//  Project.swift
//  ProjectManager
//

import Foundation

// MARK: - Project Type

enum ProjectType: String, Codable {
    case nodeJS = "Node.js"
    case deno = "Deno"
    case bun = "Bun"
    case web = "Web"
}

// MARK: - Supporting Types

struct PlatformInfo: Codable, Hashable {
    let name: String
    let file: String
}

struct DependencyInfo: Codable, Hashable {
    let name: String
    let description: String
}

// MARK: - Project

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
