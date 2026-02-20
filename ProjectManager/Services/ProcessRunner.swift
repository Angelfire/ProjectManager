//
//  ProcessRunner.swift
//  ProjectManager
//

import Foundation

@MainActor
@Observable
final class ProcessRunner {
    private var runningProcesses: [UUID: Foundation.Process] = [:]

    /// Console output per project (array of lines)
    var output: [UUID: [String]] = [:]

    /// Detected server URL per project (e.g. "http://localhost:3000")
    var detectedURL: [UUID: String] = [:]

    /// The command that was used to run the project
    var runningCommand: [UUID: String] = [:]

    func isRunning(_ projectID: UUID) -> Bool {
        runningProcesses[projectID] != nil
    }

    // MARK: - Run

    func run(project: Project) {
        guard !isRunning(project.id) else { return }

        let expandedPath = project.path.replacingOccurrences(of: "~", with: NSHomeDirectory())
        let dirURL = URL(fileURLWithPath: expandedPath)

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            appendOutput(for: project.id, line: "⚠ Directory not found: \(expandedPath)")
            return
        }
        guard let command = runCommand(for: project, at: expandedPath) else {
            appendOutput(for: project.id, line: "⚠ No run command found for this project type.")
            return
        }

        // Reset state
        output[project.id] = []
        detectedURL[project.id] = nil
        runningCommand[project.id] = command

        appendOutput(for: project.id, line: "$ \(command)")
        appendOutput(for: project.id, line: "")

        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let wrappedCommand = "source ~/.zshrc 2>/dev/null; \(command)"
        process.arguments = ["-c", wrappedCommand]
        process.currentDirectoryURL = dirURL
        process.qualityOfService = .userInitiated

        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let extraPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(home)/Library/pnpm",
            "\(home)/.deno/bin",
            "\(home)/.bun/bin",
            "/usr/bin",
            "/bin",
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = extraPaths.joined(separator: ":") + ":" + currentPath
        env["PNPM_HOME"] = "\(home)/Library/pnpm"
        env["TERM"] = "xterm-256color"
        env["FORCE_COLOR"] = "1"
        env["CLICOLOR_FORCE"] = "1"
        env["NO_COLOR"] = nil
        process.environment = env

        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        let projectID = project.id

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: .newlines)
                Task { @MainActor [weak self] in
                    for line in lines where !line.isEmpty {
                        self?.appendOutput(for: projectID, line: line)
                        self?.detectURL(in: line, for: projectID)
                    }
                }
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: .newlines)
                Task { @MainActor [weak self] in
                    for line in lines where !line.isEmpty {
                        self?.appendOutput(for: projectID, line: line)
                        self?.detectURL(in: line, for: projectID)
                    }
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            Task { @MainActor [weak self] in
                let code = proc.terminationStatus
                self?.appendOutput(for: projectID, line: "")
                self?.appendOutput(for: projectID, line: "⏹ Process exited with code \(code)")
                self?.runningProcesses.removeValue(forKey: projectID)
                self?.runningCommand.removeValue(forKey: projectID)
            }
        }

        do {
            try process.run()
            let pid = process.processIdentifier
            setpgid(pid, pid)
            runningProcesses[projectID] = process
        } catch {
            appendOutput(for: projectID, line: "⚠ Failed to start: \(error.localizedDescription)")
        }
    }

    // MARK: - Stop

    func stop(projectID: UUID) {
        guard let process = runningProcesses[projectID] else { return }
        appendOutput(for: projectID, line: "")
        appendOutput(for: projectID, line: "⏹ Stopping process...")

        let pid = process.processIdentifier
        let detectedPort = extractPort(from: detectedURL[projectID])

        killProcessTree(pid: pid)

        if process.isRunning {
            process.terminate()
        }

        if let port = detectedPort {
            killByPort(port: port)
        }

        let capturedPort = detectedPort
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            kill(pid, SIGKILL)
            kill(-pid, SIGKILL)
            if let port = capturedPort {
                let proc = Foundation.Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                proc.arguments = ["-c", "lsof -ti :\(port) | xargs kill -9 2>/dev/null"]
                proc.standardOutput = FileHandle.nullDevice
                proc.standardError = FileHandle.nullDevice
                try? proc.run()
                proc.waitUntilExit()
            }
        }

        runningProcesses.removeValue(forKey: projectID)
        runningCommand.removeValue(forKey: projectID)
        detectedURL.removeValue(forKey: projectID)
    }

    func stopAll() {
        for (id, _) in runningProcesses {
            stop(projectID: id)
        }
    }

    func clearOutput(for projectID: UUID) {
        output[projectID] = []
        detectedURL[projectID] = nil
    }

    // MARK: - Process Tree Management

    private func killProcessTree(pid: pid_t) {
        let childPIDs = getDescendantPIDs(of: pid)
        for childPID in childPIDs.reversed() {
            kill(childPID, SIGKILL)
        }
        kill(pid, SIGKILL)
        kill(-pid, SIGKILL)
    }

    private func getDescendantPIDs(of pid: pid_t) -> [pid_t] {
        var allPIDs: [pid_t] = []
        var queue: [pid_t] = [pid]

        while !queue.isEmpty {
            let currentPID = queue.removeFirst()
            let proc = Foundation.Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            proc.arguments = ["-P", "\(currentPID)"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            proc.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let childPIDs = output.split(separator: "\n").compactMap { pid_t($0) }
                allPIDs.append(contentsOf: childPIDs)
                queue.append(contentsOf: childPIDs)
            }
        }

        return allPIDs
    }

    private func killByPort(port: Int) {
        let proc = Foundation.Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", "lsof -ti :\(port) | xargs kill -9 2>/dev/null"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
    }

    private func extractPort(from urlString: String?) -> Int? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return url.port
    }

    // MARK: - Output

    private func appendOutput(for projectID: UUID, line: String) {
        if output[projectID] == nil {
            output[projectID] = []
        }
        output[projectID]?.append(line)
        if let count = output[projectID]?.count, count > 1000 {
            output[projectID]?.removeFirst(count - 1000)
        }
    }

    // MARK: - URL Detection

    private func detectURL(in line: String, for projectID: UUID) {
        let stripped =
            line
            .replacingOccurrences(
                of: "\u{1B}\\[[0-9;]*[a-zA-Z]",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "\u{1B}\\]8;;[^\u{1B}]*\u{1B}\\\\",
                with: "",
                options: .regularExpression
            )

        let lower = stripped.lowercased()

        if lower.contains("in use") || lower.contains("busy") || lower.contains("unavailable")
            || lower.contains("trying another")
        {
            return
        }

        // http://localhost:PORT, http://127.0.0.1:PORT, http://0.0.0.0:PORT
        let urlPattern = #"https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0)(:\d+)(?:/[^\s]*)?"#
        if let range = stripped.range(of: urlPattern, options: .regularExpression) {
            var url = String(stripped[range])
            url = url.replacingOccurrences(of: "0.0.0.0", with: "localhost")
            url = url.replacingOccurrences(of: "127.0.0.1", with: "localhost")
            detectedURL[projectID] = url
            return
        }

        // IPv6: http://[::]:PORT (python3 http.server)
        let ipv6Pattern = #"https?://\[[^\]]+\](:\d+)(?:/[^\s\)]*)?"#
        if let range = stripped.range(of: ipv6Pattern, options: .regularExpression) {
            let match = String(stripped[range])
            let portPattern2 = #":(\d{2,5})"#
            if let portRange = match.range(of: portPattern2, options: .regularExpression) {
                let portStr = String(match[portRange]).dropFirst()
                if let port = Int(portStr), port > 0, port <= 65535 {
                    detectedURL[projectID] = "http://localhost:\(port)"
                    return
                }
            }
        }

        // "port XXXX" pattern
        if detectedURL[projectID] == nil {
            let portPattern = #"(?:port|PORT|Port)[:\s]+(\d{3,5})"#
            if let range = stripped.range(of: portPattern, options: .regularExpression) {
                let match = String(stripped[range])
                let digits = match.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                if let port = Int(digits), port > 0, port <= 65535 {
                    detectedURL[projectID] = "http://localhost:\(port)"
                }
            }
        }
    }

    // MARK: - Run Command Resolution

    private func runCommand(for project: Project, at path: String) -> String? {
        let fm = FileManager.default

        switch project.type {
        case .nodeJS:
            let pm = detectPackageManager(at: path)
            if let data = fm.contents(atPath: "\(path)/package.json"),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let scripts = json["scripts"] as? [String: String]
            {
                if scripts["dev"] != nil {
                    return "\(pm) run dev"
                } else if scripts["start"] != nil {
                    return pm == "npm" ? "npm start" : "\(pm) run start"
                }
            }
            return pm == "npm" ? "npm start" : "\(pm) run start"

        case .deno:
            let denoConfig =
                fm.contents(atPath: "\(path)/deno.json")
                ?? fm.contents(atPath: "\(path)/deno.jsonc")
            if let data = denoConfig,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tasks = json["tasks"] as? [String: String]
            {
                if tasks["dev"] != nil {
                    return "deno task dev"
                } else if tasks["start"] != nil {
                    return "deno task start"
                }
            }
            let contents = (try? fm.contentsOfDirectory(atPath: path)) ?? []
            if contents.contains("main.ts") {
                return "deno run --allow-all main.ts"
            } else if contents.contains("mod.ts") {
                return "deno run --allow-all mod.ts"
            }
            return nil

        case .bun:
            if let data = fm.contents(atPath: "\(path)/package.json"),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let scripts = json["scripts"] as? [String: String]
            {
                if scripts["dev"] != nil {
                    return "bun run dev"
                } else if scripts["start"] != nil {
                    return "bun start"
                }
            }
            return "bun start"

        case .swiftPackage:
            return "swift run"

        case .xcodeProject:
            return "swift build"

        case .web:
            return "python3 -u -m http.server 8000"
        }
    }

    private func detectPackageManager(at path: String) -> String {
        let fm = FileManager.default
        if fm.fileExists(atPath: "\(path)/pnpm-lock.yaml") {
            return "pnpm"
        } else if fm.fileExists(atPath: "\(path)/yarn.lock") {
            return "yarn"
        } else if fm.fileExists(atPath: "\(path)/bun.lockb")
            || fm.fileExists(atPath: "\(path)/bun.lock")
        {
            return "bun"
        }
        return "npm"
    }
}
