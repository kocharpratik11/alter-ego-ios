import AppIntents
import Foundation

// MARK: - Main Siri App Intent
// Runs entirely in the background — app never opens.
// Siri speaks the confirmation aloud after processing.
// Trigger: "Hey Siri, Log with Alter Ego" → Siri asks "What's the command?" → speak it

struct VoiceCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Log with Alter Ego"
    static var description = IntentDescription(
        "Send a voice command to Alter Ego — add groceries, log baby events, create todos, and more.",
        categoryName: "Family"
    )

    // Stay in background — Siri speaks the result, app does NOT open
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Command",
        description: "What would you like to do? E.g. 'Add oat milk to Costco' or 'Aurik slept 45 minutes'"
    )
    var command: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await VoiceCommandProcessor.shared.process(command)
        return .result(dialog: IntentDialog(stringLiteral: result.confirmation))
    }
}

// MARK: - Open App Intent
// Trigger: "Hey Siri, Open Alter Ego" — opens the app to the Today tab

struct OpenAlterEgoIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Alter Ego"
    static var description = IntentDescription("Open the Alter Ego family dashboard")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - App Shortcuts provider

struct AlterEgoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Background command logging — app stays closed, Siri reads out the result
        AppShortcut(
            intent: VoiceCommandIntent(),
            phrases: [
                "Log with \(.applicationName)",
                "Ask \(.applicationName)",
                "Note for \(.applicationName)",
                "\(.applicationName) log"
            ],
            shortTitle: "Log with Alter Ego",
            systemImageName: "waveform.badge.mic"
        )

        // Open the app
        AppShortcut(
            intent: OpenAlterEgoIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show \(.applicationName)"
            ],
            shortTitle: "Open Alter Ego",
            systemImageName: "house.fill"
        )
    }
}

// MARK: - Quick action intents (Spotlight / Shortcuts suggestions)
// These also run in the background.

struct LogBabyFeedIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Baby Feed"
    static var description = IntentDescription("Quickly log a feed for Aurik")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount", description: "How much? e.g. 4oz, left breast")
    var amount: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await VoiceCommandProcessor.shared.process("Aurik had a feed, \(amount)")
        return .result(dialog: IntentDialog(stringLiteral: result.confirmation))
    }
}

struct LogBabyNapIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Baby Nap"
    static var description = IntentDescription("Quickly log a nap for Aurik")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Duration", description: "How long in minutes? e.g. 45")
    var durationMinutes: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await VoiceCommandProcessor.shared.process("Aurik slept \(durationMinutes) minutes")
        return .result(dialog: IntentDialog(stringLiteral: result.confirmation))
    }
}

struct AddGroceryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Grocery Item"
    static var description = IntentDescription("Add an item to the grocery list")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Item", description: "What to add? e.g. oat milk from Costco")
    var item: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await VoiceCommandProcessor.shared.process("Add \(item) to groceries")
        return .result(dialog: IntentDialog(stringLiteral: result.confirmation))
    }
}
