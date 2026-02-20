//
//  DetailView.swift
//  ProjectManager
//

import SwiftUI

struct DetailView: View {
    let project: Project
    let runner: ProcessRunner
    let healthChecker: HealthChecker
    @State private var selectedTab: String = "Description"

    private var isRunning: Bool {
        runner.isRunning(project.id)
    }

    private var serverURL: String? {
        runner.detectedURL[project.id]
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(project: project, selectedTab: $selectedTab)

            switch selectedTab {
            case "Description":
                DescriptionView(project: project)
            case "Terminal":
                TerminalView(project: project, runner: runner)
            case "Git":
                GitView(project: project)
            case "Health":
                HealthView(project: project, checker: healthChecker)
            default:
                Spacer()
                Text("\(selectedTab) — Coming soon")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(project.name)
        .navigationSubtitle(project.path)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let url = serverURL {
                    Button {
                        if let nsURL = URL(string: url) {
                            NSWorkspace.shared.open(nsURL)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text(url)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.blue)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.blue.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Open \(url) in browser")
                }

                Button {
                    if isRunning {
                        runner.stop(projectID: project.id)
                    } else {
                        runner.run(project: project)
                        selectedTab = "Terminal"
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isRunning ? .red : .green)
                        Text(isRunning ? "Stop" : "Run")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
            }
        }
    }
}
