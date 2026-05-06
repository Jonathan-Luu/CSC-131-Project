# Nutrition Tracker iOS App (SwiftUI)

This repository contains a ready-to-use SwiftUI app source for a nutrition tracker.

## Features Implemented

- Set daily nutrition goals (calories, protein, cholesterol max)
- Track nutrients from added foods
- View a history log of all foods added
- Remove food entries if added by mistake
- See goal consistency across logged days
- Recommendations for food to meet goals
- Calculate BMR / daily energy needs from profile inputs

## Files

- `NutritionTracker/NutritionTrackerApp.swift`
- `NutritionTracker/ContentView.swift`
- `NutritionTracker/Models.swift`
- `NutritionTracker/NutritionStore.swift`
- `NutritionTracker/DashboardView.swift`
- `NutritionTracker/AddFoodView.swift`
- `NutritionTracker/HistoryView.swift`
- `NutritionTracker/GoalsView.swift`
- `NutritionTracker/RecommendationsView.swift`
- `NutritionTracker/BMRCalculatorView.swift`

## Run in Xcode

This repo now includes a committed Xcode project file.

1. Open the project:
   - `open NutritionTracker.xcodeproj`
2. Select an iOS simulator and press Run in Xcode.

### If you see a black screen

- Make sure you opened `NutritionTracker.xcodeproj` (generated from this repo), not a different project.
- In Xcode, the selected scheme should be `NutritionTracker`.
- Use `Product > Clean Build Folder`, then run again.
- Confirm only the `NutritionTracker/*.swift` files are in the app target.

### Optional: regenerate with XcodeGen

If you prefer generated projects, this repo also includes `project.yml`:

1. `brew install xcodegen`
2. `xcodegen generate`

The app uses `UserDefaults` for local persistence, so data survives app restarts.
