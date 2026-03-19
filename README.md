# Nutrition Tracker iOS App (SwiftUI)

This repository contains a ready-to-use SwiftUI app source for a nutrition tracker.

## Features Implemented

- Set daily nutrition goals (calories, protein, cholesterol max)
- Track nutrients from added foods
- View a history log of all foods added
- Remove food entries if added by mistake
- See goal consistency across logged days
- Get food recommendations based on current nutrient deficits
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

This repo is now set up with `XcodeGen`, so you can generate and run the project quickly.

1. On your Mac, install XcodeGen (one-time):
   - `brew install xcodegen`
2. In this repo folder, generate the Xcode project:
   - `xcodegen generate`
3. Open the project:
   - `open NutritionTracker.xcodeproj`
4. Select an iOS simulator and press Run in Xcode.

The app uses `UserDefaults` for local persistence, so data survives app restarts.
