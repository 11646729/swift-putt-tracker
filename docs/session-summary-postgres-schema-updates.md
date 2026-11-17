# Session Summary: PostgreSQL Schema Updates and Golf Club Data Models

**Date:** November 17, 2026  
**Project:** Clandeboye Golf Club - Putt Tracker App

---

## Overview

This session focused on updating the PostgreSQL database schema for the Clandeboye Golf Club app, addressing stroke index allocation for partial rounds, evaluating data storage strategies, and creating Swift Codable models for golf club JSON data.

---

## 1. Stroke Index Allocation for Partial Rounds

### Problem Identified
When playing fewer than 18 holes (9, 13, or custom ranges), stroke indexes must be re-allocated based on the **relative difficulty** of the holes being played, not their full 18-hole indexes.

### Example
On a course where:
- Hole 1 has 18-hole stroke index 7 (medium difficulty)
- Hole 2 has 18-hole stroke index 1 (hardest hole)
- Hole 3 has 18-hole stroke index 15 (easier)

When playing only the **front 9**:
- Hole 2 → stroke index 1 (still the hardest of the 9)
- Hole 1 → stroke index 3-4 (among the harder of the 9)
- Hole 3 → stroke index 8-9 (among the easier of the 9)

### Solution Implemented

#### New Table: `stroke_index_allocation`
```sql
CREATE TABLE stroke_index_allocation (
    id              serial PRIMARY KEY,
    tee_id          integer NOT NULL REFERENCES course_tee,
    hole_id         integer NOT NULL REFERENCES course_hole,
    number_of_holes smallint NOT NULL CHECK (number_of_holes <= 18),
    hole_range      text NOT NULL,  -- 'Front 9', 'Back 9', '1-13', '1-18'
    stroke_index    smallint NOT NULL,
    UNIQUE (tee_id, number_of_holes, hole_range, hole_id),
    FOREIGN KEY (hole_id, tee_id) REFERENCES hole_tee(hole_id, tee_id)
);
```

#### Modified: `hole_tee` table
```sql
-- BEFORE
stroke_index  smallint NOT NULL

-- AFTER
stroke_index_18hole  smallint NOT NULL
```
Renamed to clarify this is the official stroke index for a full 18-hole round.

#### Helper Functions Created
```sql
-- Populate allocations for a specific tee
CREATE OR REPLACE FUNCTION populate_stroke_index_allocations(p_tee_id integer)

-- Populate allocations for all tees on a course
CREATE OR REPLACE FUNCTION populate_course_stroke_indexes(p_course_id integer)
```

#### Supported Configurations
1. **18 holes (full round):** Copy `stroke_index_18hole` from `hole_tee`
2. **Front 9 (holes 1-9):** Re-rank holes 1-9 by difficulty, assign 1-9
3. **Back 9 (holes 10-18):** Re-rank holes 10-18 by difficulty, assign 1-9
4. **13 holes (holes 1-13):** Re-rank holes 1-13 by difficulty, assign 1-13

---

## 2. Image Storage Strategy

### Question
Is storing images as `text` (file paths) the best choice vs. `bytea` (binary data)?

### Decision: Use `text` for file paths ✅

#### Current Design
```sql
logo_image  text,  -- e.g., '/images/clubs/clandeboye-logo.png'
image       text,  -- e.g., 'https://cdn.example.com/holes/dufferin-8.jpg'
```

#### Advantages
- ✅ Database stays small and fast
- ✅ Faster backups (no large blobs)
- ✅ Images can be served by CDN or optimized web server
- ✅ Easy to replace/update images without database writes
- ✅ Can use filesystem or object storage (S3, CloudFront, etc.)
- ✅ For Vapor server: store in `Public/images/` directory

#### Why NOT `bytea` (binary data)
- ❌ Bloats database size dramatically
- ❌ Slows down backups and replication
- ❌ Postgres not optimized for serving images
- ❌ Harder to implement CDN caching
- ❌ Complex to generate responsive/optimized versions

#### When to Consider `bytea`
Only for tiny images (icons < 10KB) that must be atomically consistent with row data.

---

## 3. Coordinate Storage Strategy

### Question
Is `double precision` for lat/lon better than GeoJSON or PostGIS `geography` type?

### Decision: Use `double precision` for now, migrate to PostGIS later if needed ✅

#### Current Design
```sql
clubhouse_lat  double precision,  -- 54.658716
clubhouse_lon  double precision,  -- -5.604549
```

#### Advantages
- ✅ Simple to understand and work with
- ✅ No PostgreSQL extensions required
- ✅ Compatible with any Postgres version
- ✅ Sufficient for storing and displaying locations
- ✅ Works for basic distance calculations (haversine formula)

#### When to Upgrade to PostGIS `geography(Point, 4326)`
Upgrade when you need:
- 🔍 Spatial queries ("Find golf courses within 10km")
- ⚡ Performance with spatial indexing (GIST indexes)
- 🛠️ Spatial operations (`ST_Distance`, `ST_DWithin`, `ST_Contains`)

#### Migration Path Provided
```sql
-- 1. Enable PostGIS
CREATE EXTENSION postgis;

-- 2. Add new column
ALTER TABLE golf_club ADD COLUMN location geography(Point, 4326);

-- 3. Migrate data (lon first, lat second in PostGIS!)
UPDATE golf_club 
SET location = ST_SetSRID(ST_MakePoint(clubhouse_lon, clubhouse_lat), 4326);

-- 4. Add spatial index
CREATE INDEX idx_golf_club_location ON golf_club USING GIST(location);

-- 5. Drop old columns (optional)
ALTER TABLE golf_club DROP COLUMN clubhouse_lat, DROP COLUMN clubhouse_lon;
```

#### GeoJSON in `map_feature.geometry`
Keeping as `jsonb` is appropriate because:
- ✅ Preserves source data structure
- ✅ No PostGIS required
- ✅ Easy to extract and send to MapKit/Leaflet
- ✅ Can migrate to PostGIS `geometry` later if spatial queries needed

---

## 4. Data Validation (Section 6.5 Questions)

### Questions Answered ✅

#### 1. Ava Golf Course Data
**Status:** ✅ **REAL DATA - NOT PLACEHOLDER**

The schema documentation was incorrect. All 18 holes have proper, unique data:
- Hole 1: "Furrest" - 346/335/328 yards, Par 4
- Hole 2: "Tower Gap" - 524/506/417 yards, Par 5
- Hole 3: "Purple Alley" - 166/148/148 yards, Par 3
- ... through Hole 18: "Tinker's Green"

#### 2. Clubhouse Coordinates
**Status:** ✅ **CORRECT**

```json
"coordinates": [-5.684726, 54.626032]
```
- Longitude: -5.684726
- Latitude: 54.626032
- Location: Near Bangor, County Down, Northern Ireland ✅

The schema documentation had incorrect coordinates listed (`[-5.604549, 54.258716]`).

#### 3. Green Polygon Data
**Status:** ❌ **STILL DUMMY DATA**

```json
"coordinates": [[[100.0, 0.0], [101.0, 0.0], [101.0, 1.0], [100.0, 1.0], [100.0, 0.0]]]
```
This placeholder data needs real green coordinates.

---

## 5. Swift Codable Models Created

### Problem
App was attempting to decode `clandeboyeGolfClub.json` as a `TextEditorCommand` type, causing "Unable to decode" errors.

### Solution
Created two new Swift files with proper Codable structures:

#### File 1: `GolfClubData.swift`
Defines Codable structs matching the JSON structure:
- `GolfClubDocument` - Root structure
- `FileHeader` - File metadata
- `GolfClub` - Club information with courses
- `Course` - Course details with holes and WHS parameters
- `CourseDetail` - Tee-specific summary (par, distance, SSS)
- `HoleDetail` - Individual hole information
- `HoleDistance` - Par, distance, stroke index per tee
- `GeoFeature`, `Geometry` - GeoJSON support
- `WHSParameters`, `RatingParameters` - World Handicap System data

#### File 2: `GolfClubLoader.swift`
Utility service for loading golf club JSON:
```swift
// Load from bundle
let clubDoc = try GolfClubLoader.load(from: "clandeboyeGolfClub")

// Load multiple files
let clubs = GolfClubLoader.loadAll(from: ["clandeboye", "otherClub"])

// Convenience extensions
let course = clubDoc.course(named: "Ava Golf Course")
let hole1 = course?.hole(number: 1)
let greenTee = course?.details(for: "society")
```

### Key Features
- ✅ Handles both Point and Polygon GeoJSON coordinates
- ✅ Proper error handling with `LoadError` enum
- ✅ Convenience extensions for easy data access
- ✅ Support for WHS (World Handicap System) parameters
- ✅ Type-safe access to courses, holes, and tee details

---

## 6. Documentation Updates

### Files Updated

#### `clandeboye-postgres-schema.md`
- ✅ Added **Section 2A**: Stroke index allocation for partial rounds
- ✅ Added **Section 3A**: Image and coordinate storage alternatives
- ✅ Added **Section 3B**: GeoJSON storage explanation
- ✅ Updated **Section 3**: Design decisions table
- ✅ Updated **Section 6.5**: Data validation results
- ✅ Updated **Section 8**: Change log

#### `clandeboye-schema.sql`
- ✅ Added `stroke_index_allocation` table
- ✅ Renamed `stroke_index` to `stroke_index_18hole` in `hole_tee`
- ✅ Added `hole_stroke_indexes` view
- ✅ Added helper functions for populating stroke index allocations
- ✅ Added inline comments explaining design choices
- ✅ Updated file header with key features

### New Files Created
- ✅ `GolfClubData.swift` - Codable models for JSON decoding
- ✅ `GolfClubLoader.swift` - Service for loading golf club data
- ✅ `session-summary-postgres-schema-updates.md` - This document

---

## 7. Schema Design Decisions Summary

| Decision | Reason | Future Migration |
|----------|--------|------------------|
| **Images as text paths** | Keeps DB lean, enables CDN serving, faster backups | N/A - this is best practice |
| **Lat/lon as double precision** | Simple, no extensions needed, sufficient for display | Migrate to PostGIS when spatial queries needed |
| **GeoJSON as jsonb** | Preserves source structure, no PostGIS needed | Migrate to PostGIS geometry for spatial operations |
| **Stroke indexes pre-computed** | Accurate handicap allocation for partial rounds | Extend with custom hole ranges if needed |
| **Derived values not stored** | Prevents data inconsistency | Use views for totals |
| **Par on hole_tee, not hole** | Dufferin has different pars per tee | N/A - correct design |

---

## 8. Relationship Diagrams

### Course Data (Static)
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

### Round Data (Dynamic)
```
golf_course  <--  round_plan  1 --- 0..1 round_play  1 --- * hole_play
course_tee   <--                                |
                                                |
                                         course_hole (for par validation)
                                         stroke_index_allocation (for handicap strokes)
```

---

## 9. Key Takeaways

### Completed ✅
1. Stroke index allocation for 9, 13, and 18-hole rounds
2. Image and coordinate storage strategy documented
3. PostGIS migration path provided
4. Data validation questions answered (Ava data is real, coordinates correct)
5. Swift Codable models created for JSON decoding
6. JSON loading service with convenience extensions
7. Complete SQL schema with helper functions and views

### Recommended Next Steps
1. **Add `clandeboyeGolfClub.json` to Xcode project** as bundle resource
2. **Test JSON loading** with `GolfClubLoader`
3. **Update green polygon coordinates** (currently dummy data)
4. **Consider adding** `course_rating` to `course_tee` table for handicap calculations
5. **Plan v1 to v2 migration** for `Round` and `HoleScore` models

### Open Questions
- Add `slope_rating` and `course_rating` to `course_tee` for handicap calculations?
- How should v1 `Round` and `HoleScore` models migrate to v2 schema?
- Create a data import tool to populate PostgreSQL from JSON files?

---

## 10. Files Modified/Created

### Modified
- `/repo/clandeboye-postgres-schema.md` - Added sections 2A, 3A, 3B; updated design decisions
- `/repo/clandeboye-schema.sql` - Added stroke index allocation table, functions, and views

### Created
- `/repo/GolfClubData.swift` - Codable models for golf club JSON
- `/repo/GolfClubLoader.swift` - Service for loading golf club data
- `/repo/session-summary-postgres-schema-updates.md` - This summary document

---

## Appendix: Code Examples

### Loading Golf Club Data
```swift
// Load from bundle
do {
    let clubDoc = try GolfClubLoader.load(from: "clandeboyeGolfClub")
    
    // Access club info
    print(clubDoc.golfClub.name) // "Clandeboye Golf Club"
    
    // Find a course
    if let ava = clubDoc.course(named: "Ava Golf Course") {
        // Get tee details
        if let greenTee = ava.details(for: "society") {
            print("Par: \(greenTee.totalPar)")
        }
        
        // Get hole info
        if let hole1 = ava.hole(number: 1),
           let medalDist = hole1.distance(for: "medal") {
            print("\(hole1.name): \(medalDist.distance) yards, Par \(medalDist.par)")
        }
    }
} catch {
    print("Error: \(error)")
}
```

### Populating Stroke Index Allocations
```sql
-- After importing course data, populate stroke indexes
SELECT populate_course_stroke_indexes(1);  -- Ava course
SELECT populate_course_stroke_indexes(2);  -- Dufferin course

-- Query stroke indexes for front 9
SELECT ch.hole_number, sia.stroke_index, ht.par
FROM stroke_index_allocation sia
JOIN course_hole ch ON ch.id = sia.hole_id
JOIN hole_tee ht ON ht.hole_id = ch.id AND ht.tee_id = sia.tee_id
WHERE sia.tee_id = 1
  AND sia.number_of_holes = 9
  AND sia.hole_range = 'Front 9'
ORDER BY ch.hole_number;
```

### PostGIS Migration (Future)
```sql
-- When spatial queries are needed
CREATE EXTENSION postgis;

ALTER TABLE golf_club ADD COLUMN location geography(Point, 4326);

UPDATE golf_club 
SET location = ST_SetSRID(ST_MakePoint(clubhouse_lon, clubhouse_lat), 4326);

CREATE INDEX idx_golf_club_location ON golf_club USING GIST(location);

-- Find nearest courses
SELECT name, ST_Distance(location, ST_MakePoint(-5.6, 54.6)::geography) AS meters
FROM golf_club
ORDER BY location <-> ST_MakePoint(-5.6, 54.6)::geography
LIMIT 5;
```

---

**End of Summary**

**Project Status:** Schema design complete and documented. Ready for implementation and data import.

**Next Session:** Implement data import pipeline and test sync between iOS app and PostgreSQL database.
