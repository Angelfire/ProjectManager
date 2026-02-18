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

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedProject: $selectedProject, store: store)
        } detail: {
            if let project = selectedProject {
                DetailView(project: project)
            } else {
                Text("Select a project")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

struct DetailView: View {
    let project: Project

    var body: some View {
        VStack(spacing: 0) {
            DetailHeaderView(project: project)
            StatsView(project: project)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .frame(width: 900, height: 600)
}
