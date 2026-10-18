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
    hole_id       integer NOT NULL
                  REFERENCES course_hole ON DELETE CASCADE,
    tee_id        integer NOT NULL
                  REFERENCES course_tee ON DELETE CASCADE,
    distance      integer NOT NULL,
    par           smallint NOT NULL CHECK (par BETWEEN 3 AND 6),
    stroke_index  smallint NOT NULL
                  CHECK (stroke_index BETWEEN 1 AND 18),
    PRIMARY KEY (hole_id, tee_id)
);
-- Later: UNIQUE (tee_id, stroke_index), once the data is cleaned.

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

```
golf_club 1 --- * golf_course 1 --- * course_tee
                       |                   |
                       1                   |
                       |                   |
                       * course_hole       |
                            |              |
                            *              *
                            +--- hole_tee --+

map_feature  ->  golf_club or golf_course
```

---

## 3. Design decisions

| Decision | Reason |
|----------|--------|
| Derived values are not stored | `outPar`, `inPar`, `totalPar`, the three distances and `numberOfGolfCourses` can be computed from `hole_tee` and `golf_course`. Storing them lets them disagree with the holes (see section 4). A `course_tee_totals` view can provide them. |
| Par is on `hole_tee`, not the hole | Dufferin holes 8 and 18 are par 4 from the men's tees and par 5 from the ladies' tees. Stroke index also differs per tee. |
| Hole data is keyed by tee, not colour | `hole_tee` points at a `course_tee` row, so the colour is stored once. |
| GeoJSON kept as `jsonb` | It keeps the file's structure and does not need PostGIS. It is easy to move to PostGIS geometry columns later if spatial queries are wanted. |

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

The app's `RoundPlan`, `RoundPlay` and `HolePlay` models currently store the
club and course as plain text. When sync is built, they would be better linked
to `golf_course` and `course_tee`. The round-side tables (plan, play, hole
results) have not been designed yet.

---

## 6. Open questions

- Draft the round-side tables next (plan, play, hole results)?
- Save the schema as a standalone `.sql` file in `docs/`?
