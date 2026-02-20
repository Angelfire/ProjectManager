//
//  ProjectStore.swift
//  ProjectManager
//

import Foundation

@MainActor
@Observable
final class ProjectStore {
    var projects: [Project] = []

    private static var saveURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
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

    // MARK: - Public API

    enum AddResult {
        case success
        case alreadyExists
        case unsupportedType
    }

    @discardableResult
    func addProject(from url: URL) -> AddResult {
        let path = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        guard !projects.contains(where: { $0.path == path }) else { return .alreadyExists }

        let name = url.lastPathComponent
        guard let type = ProjectDetector.detectType(at: url) else { return .unsupportedType }
        let platforms = ProjectDetector.detectPlatforms(at: url)
        let configFiles = ProjectDetector.detectConfigFiles(at: url)
        let totalFiles = ProjectDetector.countFiles(at: url)
        let (hasGit, gitRemoteURL) = ProjectDetector.detectGitInfo(at: url)

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
        return .success
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
            let saved = try? JSONDecoder().decode([Project].self, from: data)
        else {
            return
        }
        projects = saved
    }
}
