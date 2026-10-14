# Putt Tracker v2: Phase Instructions

Living document. Update each phase's section as plans change, and tick off the status as you go.

## v2 Overview

- Goal: sync completed rounds from the iOS app to the local Postgres database on the Mac
- Sync is manual, via a "Sync Now" button (no background sync)
- A local Vapor server on the Mac is reached over home Wi-Fi using Bonjour (`.local` hostname)
- A `synced: Bool` flag on the `Round` model tracks pending uploads
- No VPN, no retry logic

The phases follow a round from planning through to improvement, and run in sequence. Don't start a phase until the previous one is done.

| # | Phase | Status |
|---|-------|--------|
| 1 | Golf Round Plan | Done |
| 2 | Playing the Round | Not started |
| 3 | Round Score | Not started |
| 4 | Round & Score Analysis | Not started |
| 5 | Competition Results | Not started |
| 6 | Improvement Plan | Not started |

---

## Phase 1: Golf Round Plan

**Status:** Done

**Objective:**
Version 2 extends Version 1 to include all shots in a round of golf. Phase 1 captures the information needed to plan the round before it is played.

**Data to record:**
- Which golf club
- Which golf course
- Number of Holes - 9 or 13 or 18
- Planned tee time
- Tee time booked? (yes / no)
- Who is playing
- Golfing partners informed? (yes / no)
- Calendar updated? (yes / no)

**Instructions:**
1. Open a new data entry screen.
2. Enter the above data in the sequence shown above.
3. Save the plan locally; it's not linked to an actual `Round` yet. That link is Phase 2's job, once play actually starts.

**Files affected:**
- `Models.swift` — added the `RoundPlan` model (separate from `Round`, no changes to the existing v1 schema)
- `RoundPlanView.swift` — new screen; create or edit a plan
- `HomeView.swift` — added a "Plan a Round" entry point and an "Upcoming Plans" list
- `PuttTrackerApp.swift` — registered `RoundPlan` with the model container

**Done when:**
- Players, club and tee time are recorded
- Booking, partner notification and calendar are all marked yes

**Notes:**
- Kept `RoundPlan` as its own model rather than extending `Round`, to avoid any schema risk to existing saved rounds (per CLAUDE.md). Phase 2 will need to decide how a plan becomes (or links to) a played `Round`.

---

## Phase 2: Playing the Round

**Status:** Not started

**Objective:**
Play the actual round and record the conditions.

**Data to record:**
- Weather conditions
- Temperature
- Putting stats (existing v1 tracking: distance bins, putter off green, etc.)

**Instructions:**
1. [Step]
2. [Step]

**Files affected:**
- [File]

**Done when:**
- Round is played and conditions are recorded

**Notes:**

---

## Phase 3: Round Score

**Status:** Not started

**Objective:**
Record the score for the round and confirm it has been submitted.

**Data to record:**
- Score for the round
- Score submitted? (yes / no)

**Instructions:**
1. [Step]
2. [Step]

**Files affected:**
- [File]

**Done when:**
- Score is recorded and marked as submitted

**Notes:**

---

## Phase 4: Round & Score Analysis

**Status:** Not started

**Objective:**
Analyse the round and the scoring to see what went well and what didn't.

**Instructions:**
1. [Step]
2. [Step]

**Files affected:**
- [File]

**Done when:**
- [Acceptance check]

**Notes:**

---

## Phase 5: Competition Results

**Status:** Not started

**Objective:**
Record the result of the competition.

**Data to record:**
- Result (e.g. 4th place overall)

**Instructions:**
1. [Step]
2. [Step]

**Files affected:**
- [File]

**Done when:**
- Competition result is recorded

**Notes:**

---

## Phase 6: Improvement Plan

**Status:** Not started

**Objective:**
Plan how to improve by practising specific shots, based on the analysis.

**Data to record:**
- Shots to practise
- Practice plan

**Instructions:**
1. [Step]
2. [Step]

**Files affected:**
- [File]

**Done when:**
- A practice plan is written for the chosen shots

**Notes:**

---

## Change Log

- 2026-10-11: Document created with phase skeleton
- 2026-10-11: Expanded from 4 to 6 phases; added phase names and data fields
- 2026-10-14: Phase 1 implemented (RoundPlan model + RoundPlanView + Home entry point); status set to Done
