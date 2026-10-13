# Putt Tracker

Personal iOS app for recording golf putting statistics during a round. Built for one user (me), on my Mac, for my iPhone.

## Tech stack

- Swift + SwiftUI
- SwiftData for local persistence
- iOS 17+ deployment target
- No third-party dependencies. Do not add Swift packages or external libraries without asking first.

## Project structure (v1)

All source files live in the main app target:

- `PuttTrackerApp.swift`: the single `@main` entry point
- `Models.swift`: SwiftData models and enums (`Round`, `TeeColour`, etc.)
- `HomeView.swift`: landing screen
- `NewRoundView.swift`: round setup (date, club, course, weather, wind, tees, hole count)
- `ActiveRoundView.swift`: per-hole putt entry during a round
- `RoundSummaryView.swift`: summary after a round is finished
- `HistoryView.swift`: list of past rounds

## Domain rules

- Golf club name and course name are required when creating a round.
- Round metadata: date, club name, course name, weather, wind.
- Putts are counted in three distance bins: 0-4 ft, 4-10 ft, 10+ ft.
- `TeeColour` enum has Green, White, Yellow, Red. Green is the default.
- Each hole has a "putter off green" checkbox.
- Default hole count is 9.

## Coding conventions

- Use SwiftUI and SwiftData idioms for iOS 17+ (`@Model`, `@Query`, `@Bindable`, `@Environment(\.modelContext)`). Avoid deprecated APIs and Core Data.
- Use async/await, not completion handlers.
- Keep views small. Pull logic into the model or helper types rather than burying it in view bodies.
- When summing a property over a collection, use `.map(\.property).reduce(0, +)`. The form `reduce(0) { $0 + $1.property }` causes type-inference errors in this project.
- Match the existing naming and file style. Don't reformat or rename unrelated code.

## Gotchas

- Xcode auto-generates its own `@main` file when a project is created. If a build fails with a duplicate `@main` error, delete the Xcode-generated file and keep `PuttTrackerApp.swift`.
- When adding a new Swift file, make sure it is included in the app target.

## Build and run

- Open the `.xcodeproj` in Xcode and run on a simulator or my iPhone.
- If you can build from the command line, use `xcodebuild` with the Putt Tracker scheme and an iOS simulator destination, and report any compiler errors back to me.

## Version 2 (planned, not started)

Do not build v2 features unless I explicitly ask. The plan is:

- Sync completed rounds to a Postgres database running locally on my Mac.
- A small Vapor server on the Mac, reached from the phone over home Wi-Fi via its Bonjour `.local` hostname.
- Sync is manual only, via a "Sync Now" button. No background sync, no VPN, no retry logic.
- Add a `synced: Bool` flag to `Round` to track pending uploads.
- v2 will be built in 6 sequential phases: round plan, playing the round, score, analysis, competition result, improvement plan.
- Per-phase instructions will live in `putt-tracker-v2-phases.md`. Read that file before starting any v2 work.

## How I want you to work

- For anything touching more than one file, tell me your plan first, then make the changes.
- Prefer the simplest approach that works. This is a personal app, not a production product.
- Don't change the SwiftData model without telling me. Schema changes can break existing saved rounds.
- After making changes, tell me what you changed and which files were touched.
