//
//  IntentioApp.swift
//  Intentio
//

import SwiftUI
import SwiftData

@main
struct IntentioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TaskItem.self)
    }
}
