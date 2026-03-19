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

1. Open Xcode and create a new **iOS App** project (SwiftUI lifecycle).
2. Add the files from the `NutritionTracker` folder to the project target.
3. Build and run on simulator or device.

The app uses `UserDefaults` for local persistence, so data survives app restarts.
