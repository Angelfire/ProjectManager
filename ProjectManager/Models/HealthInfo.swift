//
//  HealthInfo.swift
//  ProjectManager
//

import Foundation

// MARK: - Health Level

enum HealthLevel: String {
    case good, warning, critical
}

// MARK: - Health Info

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

// MARK: - Git Commit

struct GitCommit: Identifiable {
    var id: String { shortHash }
    let shortHash: String
    let message: String
    let author: String
    let relativeDate: String
}
