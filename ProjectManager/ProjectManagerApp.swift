//
//  ProjectManagerApp.swift
//  ProjectManager
//
//  Created by Andres Bedoya on 18/02/26.
//

import SwiftUI

@main
struct ProjectManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 920, height: 620)
    }
}
