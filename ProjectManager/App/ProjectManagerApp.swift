//
//  ProjectManagerApp.swift
//  ProjectManager
//
//  Created by Andres Bedoya on 18/02/26.
//

import SwiftUI

@main
struct ProjectManagerApp: App {
    @State private var runner = ProcessRunner()

    var body: some Scene {
        WindowGroup {
            ContentView(runner: runner)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification)
                ) { _ in
                    runner.stopAll()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 750)
    }
}
