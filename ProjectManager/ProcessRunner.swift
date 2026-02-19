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
        // Source .zshrc to load fnm/nvm/volta/pnpm PATH, then run the command
        let wrappedCommand = "source ~/.zshrc 2>/dev/null; \(command)"
        process.arguments = ["-c", wrappedCommand]
        process.currentDirectoryURL = dirURL

        // Create a new process group so we can kill all children
        process.qualityOfService = .userInitiated

        // Inherit current environment and add common tool paths
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

        // Make tools think they have a terminal (enables colored output)
        env["TERM"] = "xterm-256color"
        env["FORCE_COLOR"] = "1"  // Node.js chalk/colors
        env["CLICOLOR_FORCE"] = "1"  // BSD/macOS tools
        env["NO_COLOR"] = nil  // Remove any NO_COLOR
        process.environment = env

        // Provide /dev/null for stdin so the shell doesn't wait for input
        process.standardInput = FileHandle.nullDevice

        // Capture stdout
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe

        // Capture stderr (Astro, Vite, Next.js often write here)
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        let projectID = project.id

        // Read stdout asynchronously
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

        // Read stderr asynchronously
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
            // Close pipe handlers
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
            // Make the process its own process group leader
            // so kill(-pid) kills all children too
            let pid = process.processIdentifier
            setpgid(pid, pid)
            runningProcesses[projectID] = process
        } catch {
            appendOutput(for: projectID, line: "⚠ Failed to start: \(error.localizedDescription)")
        }
    }

    func stop(projectID: UUID) {
        guard let process = runningProcesses[projectID] else { return }
        appendOutput(for: projectID, line: "")
        appendOutput(for: projectID, line: "⏹ Stopping process...")

        let pid = process.processIdentifier
        let detectedPort = extractPort(from: detectedURL[projectID])

        // 1. Kill the entire process tree recursively (SIGKILL immediately)
        killProcessTree(pid: pid)

        // 2. Terminate the zsh wrapper itself
        if process.isRunning {
            process.terminate()
        }

        // 3. Kill by port — this catches any orphaned node/astro processes
        if let port = detectedPort {
            killByPort(port: port)
        }

        // 4. Final sweep after delay (no weak self — just capture the values)
        let capturedPort = detectedPort
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            // Re-kill tree in case anything respawned
            kill(pid, SIGKILL)
            kill(-pid, SIGKILL)
            if let port = capturedPort {
                // Use lsof directly — no self needed
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

    /// Recursively kill a process and all its descendants with SIGKILL
    private func killProcessTree(pid: pid_t) {
        let childPIDs = getDescendantPIDs(of: pid)

        // SIGKILL everything immediately — no graceful shutdown needed
        for childPID in childPIDs.reversed() {
            kill(childPID, SIGKILL)
        }
        kill(pid, SIGKILL)
        kill(-pid, SIGKILL)
    }

    /// Get all descendant PIDs of a process using pgrep
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

    /// Kill any process listening on a specific port
    private func killByPort(port: Int) {
        let proc = Foundation.Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", "lsof -ti :\(port) | xargs kill -9 2>/dev/null"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
    }

    /// Extract port number from a URL string
    private func extractPort(from urlString: String?) -> Int? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return url.port
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

    // MARK: - Private

    private func appendOutput(for projectID: UUID, line: String) {
        if output[projectID] == nil {
            output[projectID] = []
        }
        output[projectID]?.append(line)
        // Cap at 1000 lines to avoid memory issues
        if let count = output[projectID]?.count, count > 1000 {
            output[projectID]?.removeFirst(count - 1000)
        }
    }

    /// Detect common URL patterns from server output
    private func detectURL(in line: String, for projectID: UUID) {
        // Strip ANSI escape codes for reliable matching
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

        // Skip lines about ports being in use / busy / unavailable
        if lower.contains("in use") || lower.contains("busy") || lower.contains("unavailable")
            || lower.contains("trying another")
        {
            return
        }

        // Match explicit URL patterns: http://localhost:PORT, http://127.0.0.1:PORT, http://0.0.0.0:PORT
        let urlPattern = #"https?://(?:localhost|127\.0\.0\.1|0\.0\.0\.0)(:\d+)(?:/[^\s]*)?"#
        if let range = stripped.range(of: urlPattern, options: .regularExpression) {
            var url = String(stripped[range])
            // Normalize 0.0.0.0 to localhost
            url = url.replacingOccurrences(of: "0.0.0.0", with: "localhost")
            url = url.replacingOccurrences(of: "127.0.0.1", with: "localhost")
            // Always update — later URLs are more accurate (e.g. after port fallback)
            detectedURL[projectID] = url
            return
        }

        // Match "port XXXX" or "PORT: XXXX" patterns (only if no URL found yet)
        if detectedURL[projectID] == nil {
            let portPattern = #"(?:port|PORT|Port)[:\s]+(\d{3,5})"#
            if let range = stripped.range(of: portPattern, options: .regularExpression) {
                // Skip if the line is about port conflicts
                let match = String(stripped[range])
                let digits = match.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                if let port = Int(digits), port > 0, port <= 65535 {
                    detectedURL[projectID] = "http://localhost:\(port)"
                }
            }
        }
    }

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
        }
    }

    /// Detect package manager by lock file presence
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
