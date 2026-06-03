import SwiftUI
import AppIntents

@main
struct AlterEgoApp: App {

    init() {
        // Register App Shortcuts with Siri on every launch.
        // Without this call, Siri doesn't know the phrases exist.
        AlterEgoShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
