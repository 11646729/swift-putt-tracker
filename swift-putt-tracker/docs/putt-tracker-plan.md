# Putt Tracker — Project Plan (Draft v1)

## 1. Problem Statement
Golfers want to track detailed putting stats during a round to identify patterns (e.g. missing left on downhill putts, weak lag putting from long range) and improve over time. Existing apps often bury putting stats inside full shot-tracking suites. This app focuses specifically on putts, with rich per-putt detail, without forcing full-round shot tracking.

## 2. Scope

**In scope (v1)**
- Track every putt taken on each hole during a round
- Per-putt detail: distance, break/line, made or missed, and result of miss (short/long/left/right)
- Round summary: total putts, putts per hole, 1-putt/2-putt/3-putt counts
- Basic history: view past rounds
- Works fully offline (course, no signal is common)

**Explicitly out of scope (v1)**
- Full shot tracking (drives, approaches, etc.)
- GPS-based yardages / course mapping
- Social features, sharing, leaderboards
- Stats benchmarking against other golfers
- Multi-user / scoring for a group

*(These could become v2+ once the core is solid.)*

## 3. Core User Flows
1. **Start a round** — pick or create a course, start round, land on Hole 1
2. **Log a putt** — for the current hole: enter distance, select break (e.g. straight/left-to-right/right-to-left/uphill/downhill), mark made or missed, if missed select miss direction
3. **Move between holes** — swipe or tap next/previous; running putt count visible
4. **Finish round** — see round summary (total putts, per-hole breakdown, makes by distance range)
5. **Review history** — list of past rounds, tap into one to see full detail

## 4. Data Model (draft)

```
Round
 - id
 - date
 - course_name
 - holes: [Hole]

Hole
 - hole_number
 - putts: [Putt]

Putt
 - id
 - order_in_hole
 - distance_feet
 - break: enum (straight, left_to_right, right_to_left, uphill, downhill, combo)
 - made: bool
 - miss_direction: enum (short, long, left, right) — null if made
```

## 5. Architecture Sketch

- **Client**: React Native (single codebase for iOS/Android) — or native Swift/Kotlin if you want platform-specific feel. *(Decision needed — see open questions.)*
- **Local storage**: on-device DB (SQLite via a lightweight ORM) so it works offline; this is the primary data store for v1
- **Sync/backend**: none required for v1 — optional cloud sync/backup could be v2
- **State**: simple local state management (round in progress lives in memory + is persisted after each putt so a crash doesn't lose data)

## 6. Build Phases

1. **Phase 1 — Data layer**: define local DB schema, CRUD for Round/Hole/Putt
2. **Phase 2 — Core logging flow**: start round → log putt → next hole → finish round (no polish, just functional)
3. **Phase 3 — Round summary screen**: aggregate stats from a completed round
4. **Phase 4 — History**: list + detail view of past rounds
5. **Phase 5 — Polish**: UI/UX pass, faster entry (e.g. big tap targets for on-course use, minimal typing)
6. **Phase 6 (stretch)**: cloud backup/sync, stats trends over time, export data

Each phase should be independently testable before moving to the next.

## 7. Open Questions / Assumptions
- Native (Swift/Kotlin) vs cross-platform (React Native/Flutter) — affects timeline and your own skill fit
- How is "break" actually entered on-course quickly? (dropdown vs a simple visual tap-on-green?) — worth prototyping this interaction specifically since it's used most often
- Do you want putt distance in feet or a rounded bucket (e.g. "0-3ft", "3-10ft", "10-20ft", "20ft+") for faster entry?
- Any interest in tracking green speed or weather conditions per round?

---
*This is a living document — edit sections directly as decisions get made, before any code is written.*
