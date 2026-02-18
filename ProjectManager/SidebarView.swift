//
//  SidebarView.swift
//  ProjectManager
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Binding var selectedProject: Project?
    var store: ProjectStore
    @State private var showFolderPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Auto-run section (only shown when projects are running)
            if !store.runningProjects.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-run")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

                    ForEach(store.runningProjects) { project in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "display")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                                Text(project.name)
                                    .font(.system(size: 13))
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 7, height: 7)
                                Text("Running")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            .padding(.leading, 34)
                            .padding(.bottom, 4)
                        }
                    }
                }
                .padding(.bottom, 4)

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }

            // Projects section
            VStack(alignment: .leading, spacing: 4) {
                Text("Projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                if store.projects.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("No projects added at this time.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(store.projects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            SidebarProjectRow(project: project, isSelected: selectedProject?.id == project.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Bottom buttons
            VStack(spacing: 8) {
                Button(action: { showFolderPicker = true }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 13))
                        Text("Add Existing")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white.opacity(0.9))
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 280)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    store.addProject(from: url)
                }
            case .failure:
                break
            }
        }
    }
}

struct SidebarProjectRow: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            projectIcon
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                Text(project.type.rawValue)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .contentShape(.rect)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.7) : .clear)
        )
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private var projectIcon: some View {
        switch project.type {
        case .xcodeProject:
            Image(systemName: "hammer.fill")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
        case .swiftPackage:
            Image(systemName: "swift")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
        case .nodeJS:
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 13))
                .foregroundStyle(.green)
        case .deno:
            Image(systemName: "lizard.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white)
        case .bun:
            Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                .font(.system(size: 12))
                .foregroundStyle(.yellow)
        }
    }
}
