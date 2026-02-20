//
//  ContentView.swift
//  ProjectManager
//
//  Created by Andres Bedoya on 18/02/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedProject: Project?
    @State private var store = ProjectStore()
    let runner: ProcessRunner
    @State private var healthChecker = HealthChecker()

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedProject: $selectedProject, store: store, runner: runner,
                healthChecker: healthChecker)
        } detail: {
            if let project = selectedProject {
                DetailView(project: project, runner: runner, healthChecker: healthChecker)
            } else {
                Text("Select a project")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .onChange(of: selectedProject) { _, newProject in
            if let project = newProject, healthChecker.healthData[project.id] == nil {
                Task { await healthChecker.refresh(project: project) }
            }
        }
    }
}

#Preview {
    ContentView(runner: ProcessRunner())
        .frame(width: 900, height: 600)
}
