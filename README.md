# Alter Ego — iOS App

Native iOS companion to the Alter Ego family assistant. Connects to the same Supabase database as the web app — no data migration needed.

## Stack

- **SwiftUI** — all 5 screens
- **App Intents** (iOS 16+) — Siri integration
- **Supabase REST API** via URLSession — same DB, same data
- **Claude Haiku** — AI intent routing directly from iOS

## Siri usage

Once installed on device, say any of:
- **"Hey Siri, tell Alter Ego add oat milk to Costco"**
- **"Hey Siri, tell Alter Ego Aurik slept 45 minutes"**
- **"Hey Siri, tell Alter Ego remind Dad to call dentist"**
- **"Hey Siri, Alter Ego dinner tonight is daal tadka"**

Siri will process the command, Claude will classify it, and it writes directly to Supabase.

---

## Setup (one-time)

### 1. Prerequisites

- Xcode 15+
- Apple Developer account (paid)
- Homebrew: `brew install xcodegen` (to generate the Xcode project)

### 2. Generate the Xcode project

```bash
cd /Users/kocharpratik11/alter-ego-ios
brew install xcodegen    # if not already installed
xcodegen generate
```

This creates `AlterEgo.xcodeproj` from `project.yml`.

### 3. Set your Apple Team

Open `AlterEgo.xcodeproj` → Select `AlterEgo` target → **Signing & Capabilities** → Set your Team.

### 4. Run on device

- Connect iPhone
- Select your device in Xcode
- **Cmd + R** to build and run

### 5. Change active user

Edit `AlterEgo/Config/Config.swift`:
```swift
static let currentUserID = dadID    // change to momID, dadID, or nannyID
static let currentUserName = "Dad"  // change to match
```

---

## Project structure

```
AlterEgo/
├── AlterEgoApp.swift          — App entry point
├── Config/
│   └── Config.swift           — API keys and user IDs
├── Models/
│   ├── AppUser.swift
│   ├── BabyLog.swift          — BabyLog + BabyProfile
│   ├── GroceryItem.swift
│   ├── MealModels.swift       — MealPlan + MealIdea + MealType enum
│   └── Todo.swift
├── Services/
│   ├── SupabaseService.swift  — All CRUD (no SDK, pure URLSession)
│   └── ClaudeService.swift    — Claude API + intent dispatcher
├── ViewModels/
│   ├── GroceryViewModel.swift
│   ├── BabyViewModel.swift
│   ├── TodosViewModel.swift
│   └── MealsViewModel.swift
├── Views/
│   ├── ContentView.swift      — Tab bar
│   ├── TodayView.swift        — Dashboard
│   ├── GroceryView.swift
│   ├── BabyTrackerView.swift  — With Charts framework sleep chart
│   ├── MealsView.swift        — Weekly grid (family + baby)
│   └── TodosView.swift
└── Intents/
    └── VoiceCommandIntent.swift — Siri App Intents
```

## Supabase connection

The app connects to the existing Supabase project directly — same URL, same anon key, same tables, same data. The web dashboard and iOS app can run simultaneously.

No changes to the database are required.

## Adding the Supabase Swift SDK (optional)

Currently uses raw URLSession for zero-dependency simplicity. If you prefer the official SDK:

1. In Xcode: **File → Add Package Dependencies**
2. URL: `https://github.com/supabase/supabase-swift`
3. Version: **2.x**

Then refactor `SupabaseService.swift` to use `import Supabase` and `SupabaseClient`.
