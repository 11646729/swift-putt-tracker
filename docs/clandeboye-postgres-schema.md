# Clandeboye Golf Club: PostgreSQL Table Structure

**Source file:** `clandeboyeGolfClub.json`
**Date:** 2026-10-18

**Question:** Read the file `clandeboye.json` and suggest a table structure to
save the data in a PostgreSQL database.

---

## 1. What is in the file

The file describes one club with two courses.

| Course | Tees | Holes |
|--------|------|-------|
| Ava Golf Course | medal (white), society (green), ladies (red) | 18 |
| Dufferin Golf Course | championship (blue), medal (white), society (green), ladies (red) | 18 |

Each hole has a distance, par and stroke index for every tee on its course.
The file also holds GeoJSON map features: the clubhouse point and a green
polygon.

OpenSourceGolf url: https://opensourcegolf.com/open-course.html#schema


---

## 2. Suggested tables

```sql
-- One row per club
CREATE TABLE golf_club (
    id                 serial PRIMARY KEY,
    name               text NOT NULL UNIQUE,
    phone_number       text,
    logo_image         text,
    clubhouse_lat      double precision,
    clubhouse_lon      double precision,
    source_file_id     integer,
    source_version     integer,
    source_created_at  timestamptz
);
-- clubhouse_*: from the "clubHouse" feature. GeoJSON order is [lon, lat].
-- source_*: fileHeader id / version / creationDate (import audit).

CREATE TABLE golf_course (
    id           serial PRIMARY KEY,
    club_id      integer NOT NULL
                 REFERENCES golf_club ON DELETE CASCADE,
    name         text NOT NULL,
    description  text,
    units        text NOT NULL DEFAULT 'yards'
                 CHECK (units IN ('yards', 'metres')),
    UNIQUE (club_id, name)
);

-- courseDetails[]: one row per tee on a course
CREATE TABLE course_tee (
    id                      serial PRIMARY KEY,
    course_id               integer NOT NULL
                            REFERENCES golf_course ON DELETE CASCADE,
    tee_type                text NOT NULL,
    tee_colour              text NOT NULL,
    standard_scratch_score  numeric(4,1),
    slope_rating            integer,
    UNIQUE (course_id, tee_type)
);
-- tee_type: championship / medal / society / ladies
-- tee_colour: blue / white / green / red
-- slope_rating: not in the JSON yet; needed for the handicap formulas.

-- holeDetails[]: facts about a hole that do not depend on the tee
CREATE TABLE course_hole (
    id           serial PRIMARY KEY,
    course_id    integer NOT NULL
                 REFERENCES golf_course ON DELETE CASCADE,
    hole_number  smallint NOT NULL
                 CHECK (hole_number BETWEEN 1 AND 18),
    name         text,
    description  text,
    image        text,
    UNIQUE (course_id, hole_number)
);

-- holeDetails[].distances[]: distance, par and stroke index per tee
CREATE TABLE hole_tee (
    hole_id              integer NOT NULL
                         REFERENCES course_hole ON DELETE CASCADE,
    tee_id               integer NOT NULL
                         REFERENCES course_tee ON DELETE CASCADE,
    distance             integer NOT NULL,
    par                  smallint NOT NULL CHECK (par BETWEEN 3 AND 6),
    stroke_index_18hole  smallint NOT NULL
                         CHECK (stroke_index_18hole BETWEEN 1 AND 18),
    PRIMARY KEY (hole_id, tee_id)
);
-- stroke_index_18hole: the official stroke index for a full 18-hole round.
-- Later: UNIQUE (tee_id, stroke_index_18hole), once the data is cleaned.

-- Stroke index allocation for partial rounds (9, 13, or custom hole ranges)
CREATE TABLE stroke_index_allocation (
    id              serial PRIMARY KEY,
    tee_id          integer NOT NULL
                    REFERENCES course_tee ON DELETE CASCADE,
    hole_id         integer NOT NULL
                    REFERENCES course_hole ON DELETE CASCADE,
    number_of_holes smallint NOT NULL CHECK (number_of_holes <= 18),
    hole_range      text NOT NULL,  -- e.g., 'Front 9', 'Back 9', '1-13', '1-18'
    stroke_index    smallint NOT NULL,
    UNIQUE (tee_id, number_of_holes, hole_range, hole_id),
    FOREIGN KEY (hole_id, tee_id) REFERENCES hole_tee(hole_id, tee_id)
);
-- When playing fewer than 18 holes, stroke indexes are re-allocated.
-- For example, Front 9: holes 1-9 get stroke indexes 1-9 based on their
-- relative difficulty (not their 18-hole index).
-- hole_range examples: 'Front 9' (holes 1-9), 'Back 9' (holes 10-18),
-- '1-13' (first 13 holes), '1-18' (full round)

CREATE INDEX idx_stroke_allocation_lookup 
    ON stroke_index_allocation(tee_id, number_of_holes, hole_range);

-- GeoJSON features (clubhouse point, green polygons)
-- Belongs to either a club or a course, not both.
CREATE TABLE map_feature (
    id         serial PRIMARY KEY,
    club_id    integer REFERENCES golf_club ON DELETE CASCADE,
    course_id  integer REFERENCES golf_course ON DELETE CASCADE,
    name       text NOT NULL,
    geometry   jsonb NOT NULL,
    CHECK (num_nonnulls(club_id, course_id) = 1)
);
-- geometry: GeoJSON in CRS84 (lon/lat WGS84). Could be a PostGIS
-- geometry(..., 4326) column instead.
```

### How the tables relate

**Course data (static, from JSON import):**
```
golf_club 1 --- * golf_course 1 --- * course_tee
                       |                   |
                       1                   |
                       |                   |
                       * course_hole       |
                            |              |
                            *              *
                            +--- hole_tee --+
                                     |
                                     *
                                     |
                       stroke_index_allocation

map_feature  ->  golf_club or golf_course
```

**Round data (dynamic, from iOS app sync):**
```
golf_course  <--  round_plan  1 --- 0..1 round_play  1 --- * hole_play
course_tee   <--                                |
                                                |
                                         course_hole (for par validation)
                                         stroke_index_allocation (for handicap strokes)
```

---

## 2A. Stroke index allocation for partial rounds

When playing fewer than 18 holes, stroke indexes must be re-allocated based on the relative difficulty of the holes being played, not their full 18-hole indexes.

### Why this matters

**Example:** On a course where:
- Hole 1 has 18-hole stroke index 7 (medium difficulty)
- Hole 2 has 18-hole stroke index 1 (hardest hole)
- Hole 3 has 18-hole stroke index 15 (easier)

When playing only the front 9:
- Hole 2 becomes stroke index 1 (still the hardest of the 9)
- Hole 1 becomes stroke index 3 or 4 (among the harder of the 9)
- Hole 3 becomes stroke index 8 or 9 (among the easier of the 9)

The `stroke_index_allocation` table stores these re-calculated indexes for each combination of tee, hole range, and number of holes.

### Populating the table

The allocation is computed when course data is imported:

1. **18 holes (full round):** Copy `stroke_index_18hole` from `hole_tee`
2. **Front 9 (holes 1–9):** Rank holes 1–9 by their 18-hole stroke index, assign 1–9
3. **Back 9 (holes 10–18):** Rank holes 10–18 by their 18-hole stroke index, assign 1–9
4. **13 holes (holes 1–13):** Rank holes 1–13 by their 18-hole stroke index, assign 1–13
5. **Custom ranges:** Rank the selected holes, assign sequential indexes

### Example query

To get stroke indexes for the front 9 on the Dufferin white tees:

```sql
SELECT ch.hole_number, sia.stroke_index, ht.par
FROM stroke_index_allocation sia
JOIN course_hole ch ON ch.id = sia.hole_id
JOIN hole_tee ht ON ht.hole_id = ch.id AND ht.tee_id = sia.tee_id
JOIN course_tee ct ON ct.id = sia.tee_id
JOIN golf_course gc ON gc.id = ct.course_id
WHERE gc.name = 'Dufferin Golf Course'
  AND ct.tee_type = 'medal'
  AND sia.number_of_holes = 9
  AND sia.hole_range = 'Front 9'
ORDER BY ch.hole_number;
```

---

## 3. Design decisions

| Decision | Reason |
|----------|--------|
| Derived values are not stored | `outPar`, `inPar`, `totalPar`, the three distances and `numberOfGolfCourses` can be computed from `hole_tee` and `golf_course`. Storing them lets them disagree with the holes (see section 4). A `course_tee_totals` view can provide them. |
| Par is on `hole_tee`, not the hole | Dufferin holes 8 and 18 are par 4 from the men's tees and par 5 from the ladies' tees. Stroke index also differs per tee. |
| Hole data is keyed by tee, not colour | `hole_tee` points at a `course_tee` row, so the colour is stored once. |
| Stroke indexes are pre-computed for partial rounds | The `stroke_index_allocation` table stores re-ranked stroke indexes for 9, 13, and 18-hole rounds. This is necessary because handicap strokes are allocated by relative difficulty of the holes being played, not the full 18-hole index. See section 2A. |
| Images stored as URLs/paths, not binary data | `logo_image` and `image` fields store file paths or URLs (text) rather than binary image data. This keeps the database lean, simplifies backups, enables CDN serving, and allows the web/app layer to handle image optimization. Images are stored on the filesystem or object storage (S3, etc.). |
| Coordinates stored as separate lat/lon columns | `clubhouse_lat` and `clubhouse_lon` use `double precision` for simplicity. This works for basic distance calculations and point storage. If spatial queries (nearest club, contains point, etc.) become important, migrate to PostGIS `geography(Point, 4326)` columns. See section 3A. |
| GeoJSON kept as `jsonb` | GeoJSON in `map_feature.geometry` keeps the file's structure and does not need PostGIS. It is easy to move to PostGIS `geometry(..., 4326)` columns later if spatial queries (intersection, within, etc.) are wanted. |

---

## 3A. Image and coordinate storage alternatives

### Image storage

**Current approach:** Store file paths or URLs as `text`

```sql
logo_image  text,  -- e.g., '/images/clubs/clandeboye-logo.png'
image       text,  -- e.g., 'https://cdn.example.com/holes/dufferin-hole-8.jpg'
```

**Pros:**
- Database stays small and fast
- Images can be served by CDN or optimized web server
- Easy to replace/update images without database writes
- Backups are faster (no large blobs)
- Can use filesystem or object storage (S3, CloudFront, etc.)

**Cons:**
- Requires separate file storage management
- Risk of orphaned files or broken paths

**Alternative: Store binary data in database**

```sql
logo_image  bytea,  -- Binary image data
```

**When to consider bytea:**
- Very small images (thumbnails, icons)
- Images that must be atomically consistent with row data
- Simplified deployment (no separate file storage)

**Not recommended because:**
- Bloats database size and slows backups
- Database is not optimized for serving images
- Harder to implement CDN caching
- More complex to generate responsive/optimized versions

**Recommendation:** Keep images as text paths. For an iOS app syncing to a local Vapor server, store images in the `Public/images/` directory and reference them by path.

---

### Coordinate storage

**Current approach:** Separate `double precision` columns

```sql
clubhouse_lat  double precision,  -- e.g., 54.658716
clubhouse_lon  double precision,  -- e.g., -5.604549
```

**Pros:**
- Simple to understand and query
- No extensions required
- Works for basic distance calculations (haversine formula)
- Compatible with any PostgreSQL version

**Cons:**
- No built-in spatial indexing
- No spatial operations (contains, intersects, nearest neighbor)
- Distance calculations require manual formulas

**Alternative 1: PostGIS geography type**

```sql
-- Requires PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

clubhouse_location  geography(Point, 4326),  -- WGS84 lat/lon
```

**Pros:**
- Built-in spatial indexes (GIST)
- Rich spatial functions (`ST_Distance`, `ST_DWithin`, `ST_Contains`)
- Accurate distance calculations on Earth's surface
- Standard geography/geometry types

**Cons:**
- Requires PostGIS extension
- More complex setup
- Heavier dependency

**Alternative 2: PostGIS geometry type**

```sql
clubhouse_location  geometry(Point, 4326),  -- WGS84 lat/lon (projected)
```

**Difference from geography:**
- `geography`: Uses Earth's spheroid (accurate for distances)
- `geometry`: Uses flat plane (faster, less accurate over large distances)

**Recommendation:**

**For now (Phase 1):** Use separate `double precision` columns
- Simple
- Sufficient for storing and displaying club locations
- Easy to migrate later

**When to upgrade to PostGIS:**
- Need to find "nearest golf course to my location"
- Need to check if a point is within a course boundary
- Building a map with spatial queries (all courses within 50km)
- Want to optimize spatial searches with indexes

**Example migration to PostGIS:**

```sql
-- Add PostGIS extension
CREATE EXTENSION postgis;

-- Add new column
ALTER TABLE golf_club 
    ADD COLUMN location geography(Point, 4326);

-- Migrate data (longitude first, latitude second in PostGIS!)
UPDATE golf_club 
SET location = ST_SetSRID(ST_MakePoint(clubhouse_lon, clubhouse_lat), 4326)
WHERE clubhouse_lon IS NOT NULL AND clubhouse_lat IS NOT NULL;

-- Add spatial index
CREATE INDEX idx_golf_club_location ON golf_club USING GIST(location);

-- Drop old columns (optional, after confirming migration)
ALTER TABLE golf_club 
    DROP COLUMN clubhouse_lat,
    DROP COLUMN clubhouse_lon;
```

**Example spatial queries with PostGIS:**

```sql
-- Find clubs within 10km of a point
SELECT name, ST_Distance(location, ST_SetSRID(ST_MakePoint(-5.6, 54.6), 4326)) AS distance_meters
FROM golf_club
WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint(-5.6, 54.6), 4326), 10000)
ORDER BY distance_meters;

-- Find nearest 5 clubs to a location
SELECT name, ST_Distance(location, ST_SetSRID(ST_MakePoint(-5.6, 54.6), 4326)) AS distance_meters
FROM golf_club
WHERE location IS NOT NULL
ORDER BY location <-> ST_SetSRID(ST_MakePoint(-5.6, 54.6), 4326)
LIMIT 5;
```

---

## 3B. GeoJSON in map_feature

The `map_feature.geometry` column stores GeoJSON as `jsonb`. This is appropriate because:

1. **Preserves source data structure** from the JSON import files
2. **No PostGIS required** for storing polygon/point data
3. **Easy to extract** and send to mapping libraries (MapKit, Leaflet)
4. **Future-proof:** Can migrate to PostGIS `geometry` column if needed

**When to migrate map_feature to PostGIS geometry:**
- Need to query "which green contains this point?"
- Want to calculate area, perimeter, or other geometric properties
- Building map tile servers or spatial analytics
- Need spatial indexes for performance

**Current approach is sufficient for:**
- Displaying greens/features on a map
- Storing and retrieving GeoJSON for map rendering
- Basic import/export workflows

---

## 4. Problems in the JSON to fix before importing

| Problem | Detail |
|---------|--------|
| Ava holes 2 to 18 look like placeholders | Every hole repeats 524 / 506 / 417 yards, par 5 and stroke index 1 / 1 / 5. Only hole 1 looks real. This also contradicts the course header (`totalPar` 70, `outPar` 36). |
| `firstGreen` polygon is dummy data | Its coordinates run from 100.0, 0.0 to 101.0, 1.0, which is nowhere near Co. Down. |
| Repeated stroke indexes | In Ava, every hole has stroke index 1 (1 / 1 / 5 across the tees), so the unique stroke-index constraint is left off for now. |
| No slope or course rating | Only `standardScratchScore` is present, but `golf-handicap-formulas.md` needs both Slope and Course Rating. `slope_rating` is added as a nullable column. |
| Names and tee colours differ from the app | The JSON says "Clandeboye Golf Club" and "Ava Golf Course"; the app defaults to "Clandeboye" and "AVA". The app's `TeeColour` has Yellow but no Blue; the JSON has blue and no yellow. |

---

## 5. Link to the sync

The app's `RoundPlan`, `RoundPlay` and `HolePlay` models (v2 Phase 1 and 2) currently store the
club and course as plain text. When sync is built, they should be linked
to `golf_course` and `course_tee` by ID rather than name.

### 5.1 Round-side tables (app → server sync)

```sql
-- v2 Phase 1: pre-round planning
CREATE TABLE round_plan (
    id                  serial PRIMARY KEY,
    golf_club_id        integer REFERENCES golf_club ON DELETE RESTRICT,
    golf_course_id      integer REFERENCES golf_course ON DELETE RESTRICT,
    course_tee_id       integer REFERENCES course_tee ON DELETE RESTRICT,
    number_of_holes     smallint NOT NULL CHECK (number_of_holes IN (9, 13, 18)),
    nine_hole_side      text CHECK (nine_hole_side IN ('Front 9', 'Back 9')),
    planned_tee_time    timestamptz NOT NULL,
    tee_time_booked     boolean NOT NULL DEFAULT false,
    players             text[] NOT NULL DEFAULT '{}',
    partners_informed   boolean NOT NULL DEFAULT false,
    calendar_updated    boolean NOT NULL DEFAULT false,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CHECK ((number_of_holes = 9 AND nine_hole_side IS NOT NULL) OR (number_of_holes != 9 AND nine_hole_side IS NULL))
);
-- nine_hole_side: only meaningful when numberOfHoles = 9

-- v2 Phase 2: playing the round (conditions and competition)
CREATE TABLE round_play (
    id                   serial PRIMARY KEY,
    round_plan_id        integer UNIQUE
                         REFERENCES round_plan ON DELETE CASCADE,
    competition_format   text NOT NULL DEFAULT 'Stableford'
                         CHECK (competition_format IN ('Stroke Play', 'Stableford')),
    weather              text NOT NULL DEFAULT 'Sunny'
                         CHECK (weather IN ('Sunny', 'Partly Cloudy', 'Cloudy', 'Rainy')),
    temperature          smallint NOT NULL DEFAULT 15,  -- degrees Celsius
    started_at           timestamptz NOT NULL DEFAULT now(),
    finished_at          timestamptz,
    synced_at            timestamptz
);
-- round_plan_id: nullable when a round is played without a plan (walk-on)
-- synced_at: when this record was last uploaded to the server

-- v2 Phase 2: hole-by-hole results
CREATE TABLE hole_play (
    id            serial PRIMARY KEY,
    round_play_id integer NOT NULL
                  REFERENCES round_play ON DELETE CASCADE,
    hole_number   smallint NOT NULL CHECK (hole_number BETWEEN 1 AND 18),
    par           smallint NOT NULL CHECK (par BETWEEN 3 AND 6),
    score         smallint CHECK (score BETWEEN 1 AND 12),
    putts_short   smallint NOT NULL DEFAULT 0,  -- 0–4 ft
    putts_mid     smallint NOT NULL DEFAULT 0,  -- 4–10 ft
    putts_long    smallint NOT NULL DEFAULT 0,  -- 10+ ft
    UNIQUE (round_play_id, hole_number)
);
-- score: nullable until entered; at least 1, up to 12 (10 + 2 penalty strokes)

-- Index for fetching all holes in a round in order
CREATE INDEX idx_hole_play_round ON hole_play(round_play_id, hole_number);
```

### 5.2 Sync strategy

The iOS app keeps `RoundPlan`, `RoundPlay` and `HolePlay` in SwiftData (local SQLite).
A manual "Sync Now" button uploads completed rounds to the Vapor server's Postgres
database over local Wi-Fi (Bonjour `.local` hostname).

**Mapping:**
- `RoundPlan.golfClubName` / `courseName` → lookup `golf_club.id` / `golf_course.id` on insert
- `RoundPlay.competitionFormat` / `weather` / `temperature` → direct copy
- `HolePlay.holeNumber` / `par` / `score` / putts → direct copy

**Status tracking:**
- `RoundPlay` gets a `synced: Bool` flag (SwiftData side); server records `synced_at`
- The app only uploads rounds where `synced == false`

**Tee selection:**
The app doesn't yet capture which tee is played (green / white / yellow / red).
A future phase should add `RoundPlan.teeColour` and map it to `course_tee_id`.

---

## 6. OpenSourceGolf format assessment

**Question:** How feasible is it to use the OpenSourceGolf file format to store
the data in `clandeboyeGolfClub.json`?

`OpenSourceGolf.json` in `docs/` is a sample: one course ("Harbour Pines") with
a single hole filled in. There is no formal spec in the project, so this
assessment is based on the sample only. If the real format has a published
schema, it should be checked.

**Verdict:** feasible as a lossy import/export format, but not as the main
storage format. The Clandeboye file keeps more detail than this format can hold.

### 6.1 Field mapping

| Clandeboye JSON | OpenSourceGolf | Result |
|-----------------|----------------|--------|
| Club name, phone, logo | `name` only | Phone and logo are lost |
| Club, then courses (two levels) | One course per file | Two files needed, club info repeated |
| Clubhouse point (GeoJSON) | `location.lat` / `lng` | Maps across; city, state, country and timezone are not in the Clandeboye file and would need adding |
| Hole `name`, description, image | No field | Lost |
| Per-tee par | One `par` per hole | **Lost.** Dufferin holes 8 and 18 are par 4 from the men's tees and par 5 from the ladies' |
| Per-tee stroke index | One `handicap` per hole | **Lost.** Dufferin stroke indexes differ on many ladies' holes |
| Per-tee distance | `tees[]` with `distance_yards` | Maps cleanly |
| Tee type and colour (medal / white) | Tee `name` ("Black", "Blue") | The two must be merged into one name; the medal / society / ladies labels are lost |
| Per-tee `standardScratchScore`, `totalPar` | One course-level `par`, `rating`, `slope` | **Lost.** Dufferin's ladies' par is 73, not 71 |
| Out / In totals | Not stored | Fine, they are derived |
| Green polygons (GeoJSON) | `pin_positions`, `hazards`, `layup_targets` | Different data; nothing maps across |
| `fileHeader` (id, version, date) | `metadata` and a UUID `id` | Maps across, with a new ID |
| Units | Yards only | Fine; the Clandeboye file is in yards |

### 6.2 What the format adds

Hazards, layup targets, pin positions, city, state, country, timezone and a
licence field (CC BY 4.0). None of this is in the Clandeboye file.

### 6.3 Why it matters for this app

Per-tee par, stroke index and rating are what the handicap formulas in
`golf-handicap-formulas.md` need for Stableford and net scores. For Ava, where
every tee has the same par, nothing is lost. For Dufferin, the ladies' tees
would get the wrong par and stroke indexes.

### 6.4 Options

| Option | Effort | Trade-off |
|--------|--------|-----------|
| Use the format as is | Low | Loses per-tee par, stroke index and rating, and hole names |
| Extend the format with extra fields | Medium | Keeps the data, but it is unknown whether the format allows extra fields, and the result is no longer standard |
| Keep the Postgres schema (sections 2 to 4) as the main store; add an OpenSourceGolf import / export converter | Medium | Nothing is lost internally, and files can still be exchanged in that format |

**Recommendation:** the third option. The Postgres schema stays the source of
truth, and OpenSourceGolf is only an adapter.

### 6.5 Data to check first

- **Ava placeholder data:** holes 2 to 18 are still placeholder copies (section 4).
- **Clubhouse coordinates:** `[-5.604549, 54.258716]` look off. Clandeboye isIn
  believed to be near Bangor, at roughly 54.6 degrees north. Please verify.
---

## 7. Open questions

- ~~Write a converted sample (for example Dufferin in OpenSourceGolf format) to
  show exactly what is lost?~~ (Deferred: OpenSourceGolf is not the primary format)
- ~~Draft the round-side tables next (plan, play, hole results)?~~ **Done** (section 5.1)
- ~~Save the schema as a standalone `.sql` file in `docs/`?~~ **Done** (`clandeboye-schema.sql`)
- Add `slope_rating` and `course_rating` to `course_tee` for handicap calculations (see `golf-handicap-formulas.md`)?
- How should the v1 `Round` and `HoleScore` models migrate to the v2 schema?

---

## 8. Change log

- 2026-10-18: Initial schema design for course data (sections 1–6)
- 2026-11-12: Added round-side tables (`round_plan`, `round_play`, `hole_play`) for v2 app sync (section 5.1); updated relationships diagram; created `clandeboye-schema.sql`; moved open questions to section 7
- 2026-11-12: Added `stroke_index_allocation` table for partial rounds; renamed `stroke_index` to `stroke_index_18hole` in `hole_tee`; added section 2A explaining stroke index re-allocation for rounds with fewer than 18 holes
- 2026-11-12: Added sections 3A and 3B explaining image storage and coordinate storage design decisions; documented PostGIS migration path for future spatial queries
