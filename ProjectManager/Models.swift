//
//  Models.swift
//  ProjectManager
//

import Foundation

enum ProjectType: String {
    case xcodeProject = "Xcode Project"
    case swiftPackage = "Swift Package"
    case nodeJS = "Node.js"
    case deno = "Deno"
    case bun = "Bun"
}

struct Project: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: ProjectType
    let icon: String // emoji or SF Symbol
    let path: String
    var isRunning: Bool = false

    // Stats
    let projectStarted: String
    let totalCommits: Int
    let contributors: Int

    // Platform
    let platforms: [(name: String, file: String)]

    // Dependencies
    let dependencies: [(name: String, description: String)]

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct AutoRunItem: Identifiable {
    let id = UUID()
    let name: String
    let isStarred: Bool
    let isRunning: Bool
}

// MARK: - Sample Data

extension Project {
    static let sampleProjects: [Project] = [
        Project(
            name: "shipyard",
            type: .xcodeProject,
            icon: "terminal",
            path: "~/Developer/shipyard",
            projectStarted: "2022-01-15",
            totalCommits: 342,
            contributors: 2,
            platforms: [("Swift", "Package.swift")],
            dependencies: []
        ),
        Project(
            name: "iconfactory",
            type: .swiftPackage,
            icon: "flame",
            path: "~/Developer/iconfactory",
            projectStarted: "2021-06-20",
            totalCommits: 128,
            contributors: 1,
            platforms: [("Swift", "Package.swift")],
            dependencies: []
        ),
        Project(
            name: "flaviocopes.com",
            type: .nodeJS,
            icon: "globe",
            path: "~/www/flaviocopes.com",
            projectStarted: "2017-08-03",
            totalCommits: 4824,
            contributors: 3,
            platforms: [
                ("Node.js", "package.json"),
                ("TypeScript", "tsconfig.json")
            ],
            dependencies: [
                ("@astrojs/mdx", "Add support for MDX pages in your Astr..."),
                ("@astrojs/netlify", "Deploy your site to Netlify"),
                ("@astrojs/rss", "Add RSS feeds to your Astro projects"),
                ("@astrojs/sitemap", "Generate a sitemap for Astro site"),
                ("@netlify/blobs", "TypeScript client for Netlify Blobs"),
                ("@tailwindcss/typography", "A Tailwind CSS plugin for automatically...")
            ]
        ),
        Project(
            name: "thevalleyofcode.com",
            type: .nodeJS,
            icon: "globe",
            path: "~/www/thevalleyofcode.com",
            projectStarted: "2020-03-10",
            totalCommits: 1520,
            contributors: 2,
            platforms: [("Node.js", "package.json")],
            dependencies: []
        ),
        Project(
            name: "bootcamp.dev",
            type: .nodeJS,
            icon: "globe",
            path: "~/www/bootcamp.dev",
            projectStarted: "2023-01-05",
            totalCommits: 678,
            contributors: 1,
            platforms: [("Node.js", "package.json")],
            dependencies: []
        )
    ]
}
