# Putt Tracker

A simple, focused iOS app for tracking putting stats during a round of golf. Instead of burying putting data inside a full shot-tracking suite, Putt Tracker does one thing well: fast, on-course logging of every putt, hole by hole, so you can spot patterns and improve your putting over time.

Built with **SwiftUI** and **SwiftData**, and works fully offline.

## Features

- **Start a round** — enter the golf club, course name, date, number of holes (9 or 18), tee colour, and conditions (weather/wind)
- **Log putts hole by hole** — big tap targets for quick on-course entry; putts are logged into three distance bins:
  - 0–4 ft
  - 4–10 ft
  - 10+ ft
- **Track extra context per hole** — mark whether the putter was used off the green
- **Navigate holes** — move forward/back through the round with a running putt count and progress bar
- **Round summary** — total putts, holes played, average putts per hole, a breakdown by distance bin, and a hole-by-hole list
- **History** — browse past rounds, see overall stats (rounds played, average putts per round/hole), and swipe to delete
- **Offline-first** — all data is stored locally on-device; no account, network connection, or backend required

## Tech Stack

- **SwiftUI** for the UI
- **SwiftData** (`@Model`, `@Query`, `@Relationship`) for local persistence
- No third-party dependencies

## Project Structure

```
swift-putt-tracker/
├── PuttTrackerApp.swift      # App entry point, sets up the SwiftData model container
├── Models.swift               # Round & HoleScore models, plus supporting enums
├── HomeView.swift              # Landing screen: start a round, recent rounds
├── NewRoundView.swift          # Form to configure and begin a new round
├── ActiveRoundView.swift       # Per-hole putt entry screen
├── RoundSummaryView.swift      # Summary shown at end of round / when viewing history
├── HistoryView.swift           # Full list of past rounds + overall stats
└── docs/
    └── putt-tracker-plan.md    # Original project plan / scope notes
```

### Data Model

```
Round
 - date, golfClubName, courseName, teeColour, weather, wind, numberOfHoles
 - holes: [HoleScore]

HoleScore
 - holeNumber
 - puttsShort (0–4 ft), puttsMid (4–10 ft), puttsLong (10+ ft)
 - usedPutterOffGreen
```

## Getting Started

1. Open `swift-putt-tracker.xcodeproj` (or `.xcworkspace`) in Xcode.
2. Select a simulator or a connected device as the run destination.
3. Build and run (`⌘R`).

No additional setup, API keys, or dependencies are required.

## Roadmap

See [`docs/putt-tracker-plan.md`](swift-putt-tracker/docs/putt-tracker-plan.md) for the original scope and phased build plan. Ideas explicitly out of scope for now include full shot tracking, GPS/course mapping, and social/sharing features — these may be revisited in a future version.
