-- Clandeboye Golf Club: PostgreSQL Database Schema
-- Generated: 2026-11-12 (updated for stroke index allocation)
-- Source: clandeboye-postgres-schema.md
--
-- Key features:
-- - Course data: clubs, courses, tees, holes with per-tee distances and pars
-- - Stroke index allocation: pre-computed indexes for 9, 13, and 18-hole rounds
-- - Round data: plans, play records, and hole-by-hole scoring
-- - Sync support: tracking for iOS app -> server synchronization

-- ============================================================================
-- COURSE DATA (Static: imported from JSON files)
-- ============================================================================

-- One row per club
CREATE TABLE golf_club (
    id                 serial PRIMARY KEY,
    name               text NOT NULL UNIQUE,
    phone_number       text,
    logo_image         text,  -- Path or URL to logo image file, e.g., '/images/clubs/clandeboye.png'
                               -- Images are stored on filesystem or CDN, not as binary data in the database
    clubhouse_lat      double precision,  -- WGS84 latitude (e.g., 54.658716)
    clubhouse_lon      double precision,  -- WGS84 longitude (e.g., -5.604549)
                                           -- Using separate columns for simplicity; can migrate to PostGIS geography(Point, 4326) later for spatial queries
    source_file_id     integer,
    source_version     integer,
    source_created_at  timestamptz
);
-- clubhouse_lat/lon: Simple coordinate storage. Sufficient for displaying locations.
--   Future: Migrate to PostGIS for spatial queries (nearest club, within bounds, etc.)
-- logo_image: Text path keeps database lean; images served by filesystem/CDN
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
    image        text,  -- Path or URL to hole image, e.g., '/images/holes/dufferin-8.jpg' or CDN URL
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
-- When playing fewer than 18 holes, stroke indexes are re-allocated based on
-- the relative difficulty of the holes being played.
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
-- hole_range examples: 'Front 9' (holes 1-9), 'Back 9' (holes 10-18),
-- '1-13' (first 13 holes), '1-18' (full round)
-- For 9-hole rounds on the front nine: holes are re-ranked 1-9 by difficulty
-- For back nine: holes 10-18 are re-ranked 1-9 by difficulty
-- This ensures handicap strokes are allocated correctly for partial rounds

CREATE INDEX idx_stroke_allocation_lookup 
    ON stroke_index_allocation(tee_id, number_of_holes, hole_range);

-- GeoJSON features (clubhouse point, green polygons)
-- Belongs to either a club or a course, not both.
CREATE TABLE map_feature (
    id         serial PRIMARY KEY,
    club_id    integer REFERENCES golf_club ON DELETE CASCADE,
    course_id  integer REFERENCES golf_course ON DELETE CASCADE,
    name       text NOT NULL,
    geometry   jsonb NOT NULL,  -- GeoJSON in CRS84 (lon/lat WGS84)
                                -- Stored as JSONB for flexibility; can migrate to PostGIS geometry(*, 4326) if spatial queries are needed
    CHECK (num_nonnulls(club_id, course_id) = 1)
);
-- geometry: GeoJSON keeps source file structure. Easy to send to MapKit/web maps.
--   Future: Migrate to PostGIS geometry for spatial operations (contains, intersects, area, etc.)

-- ============================================================================
-- ROUND DATA (Dynamic: synced from iOS app)
-- ============================================================================

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

-- ============================================================================
-- HELPFUL VIEWS
-- ============================================================================

-- Per-tee totals view (derived values not stored in tables)
CREATE VIEW course_tee_totals AS
SELECT
    ct.id AS tee_id,
    ct.course_id,
    ct.tee_type,
    ct.tee_colour,
    SUM(ht.par) AS total_par,
    SUM(CASE WHEN ch.hole_number <= 9 THEN ht.par ELSE 0 END) AS out_par,
    SUM(CASE WHEN ch.hole_number > 9 THEN ht.par ELSE 0 END) AS in_par,
    SUM(ht.distance) AS total_distance,
    SUM(CASE WHEN ch.hole_number <= 9 THEN ht.distance ELSE 0 END) AS out_distance,
    SUM(CASE WHEN ch.hole_number > 9 THEN ht.distance ELSE 0 END) AS in_distance
FROM course_tee ct
JOIN hole_tee ht ON ht.tee_id = ct.id
JOIN course_hole ch ON ch.id = ht.hole_id
GROUP BY ct.id, ct.course_id, ct.tee_type, ct.tee_colour;

-- Stroke index allocation helper view
-- Shows stroke indexes for all supported round configurations
CREATE VIEW hole_stroke_indexes AS
SELECT
    gc.name AS course_name,
    ct.tee_type,
    ct.tee_colour,
    ch.hole_number,
    sia.number_of_holes,
    sia.hole_range,
    sia.stroke_index,
    ht.par,
    ht.distance
FROM stroke_index_allocation sia
JOIN course_tee ct ON ct.id = sia.tee_id
JOIN golf_course gc ON gc.id = ct.course_id
JOIN course_hole ch ON ch.id = sia.hole_id
JOIN hole_tee ht ON ht.hole_id = ch.id AND ht.tee_id = ct.id
ORDER BY gc.name, ct.tee_type, sia.number_of_holes, sia.hole_range, ch.hole_number;

-- Round summary view
CREATE VIEW round_summary AS
SELECT
    rp.id AS round_id,
    rpl.id AS plan_id,
    gc.name AS club_name,
    gco.name AS course_name,
    ct.tee_type,
    ct.tee_colour,
    rpl.planned_tee_time,
    rp.started_at,
    rp.finished_at,
    rp.competition_format,
    rp.weather,
    rp.temperature,
    COUNT(hp.id) AS holes_played,
    SUM(hp.par) AS total_par,
    SUM(hp.score) AS total_score,
    SUM(hp.putts_short + hp.putts_mid + hp.putts_long) AS total_putts,
    rp.synced_at
FROM round_play rp
LEFT JOIN round_plan rpl ON rpl.id = rp.round_plan_id
LEFT JOIN golf_club gc ON gc.id = rpl.golf_club_id
LEFT JOIN golf_course gco ON gco.id = rpl.golf_course_id
LEFT JOIN course_tee ct ON ct.id = rpl.course_tee_id
LEFT JOIN hole_play hp ON hp.round_play_id = rp.id
GROUP BY rp.id, rpl.id, gc.name, gco.name, ct.tee_type, ct.tee_colour,
         rpl.planned_tee_time, rp.started_at, rp.finished_at,
         rp.competition_format, rp.weather, rp.temperature, rp.synced_at;
-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Populate stroke index allocations for a specific tee
-- This function should be called after importing hole_tee data
CREATE OR REPLACE FUNCTION populate_stroke_index_allocations(p_tee_id integer)
RETURNS void AS $$
DECLARE
    v_course_id integer;
BEGIN
    -- Get the course_id for this tee
    SELECT course_id INTO v_course_id
    FROM course_tee
    WHERE id = p_tee_id;

    -- Delete existing allocations for this tee
    DELETE FROM stroke_index_allocation WHERE tee_id = p_tee_id;

    -- 18 holes (full round): use original stroke indexes
    INSERT INTO stroke_index_allocation (tee_id, hole_id, number_of_holes, hole_range, stroke_index)
    SELECT 
        p_tee_id,
        ht.hole_id,
        18,
        '1-18',
        ht.stroke_index_18hole
    FROM hole_tee ht
    JOIN course_hole ch ON ch.id = ht.hole_id
    WHERE ht.tee_id = p_tee_id
      AND ch.course_id = v_course_id
      AND ch.hole_number BETWEEN 1 AND 18;

    -- Front 9: re-rank holes 1-9 by their 18-hole stroke index
    INSERT INTO stroke_index_allocation (tee_id, hole_id, number_of_holes, hole_range, stroke_index)
    SELECT 
        p_tee_id,
        ht.hole_id,
        9,
        'Front 9',
        ROW_NUMBER() OVER (ORDER BY ht.stroke_index_18hole) AS stroke_index
    FROM hole_tee ht
    JOIN course_hole ch ON ch.id = ht.hole_id
    WHERE ht.tee_id = p_tee_id
      AND ch.course_id = v_course_id
      AND ch.hole_number BETWEEN 1 AND 9;

    -- Back 9: re-rank holes 10-18 by their 18-hole stroke index
    INSERT INTO stroke_index_allocation (tee_id, hole_id, number_of_holes, hole_range, stroke_index)
    SELECT 
        p_tee_id,
        ht.hole_id,
        9,
        'Back 9',
        ROW_NUMBER() OVER (ORDER BY ht.stroke_index_18hole) AS stroke_index
    FROM hole_tee ht
    JOIN course_hole ch ON ch.id = ht.hole_id
    WHERE ht.tee_id = p_tee_id
      AND ch.course_id = v_course_id
      AND ch.hole_number BETWEEN 10 AND 18;

    -- First 13 holes: re-rank holes 1-13 by their 18-hole stroke index
    INSERT INTO stroke_index_allocation (tee_id, hole_id, number_of_holes, hole_range, stroke_index)
    SELECT 
        p_tee_id,
        ht.hole_id,
        13,
        '1-13',
        ROW_NUMBER() OVER (ORDER BY ht.stroke_index_18hole) AS stroke_index
    FROM hole_tee ht
    JOIN course_hole ch ON ch.id = ht.hole_id
    WHERE ht.tee_id = p_tee_id
      AND ch.course_id = v_course_id
      AND ch.hole_number BETWEEN 1 AND 13;

END;
$$ LANGUAGE plpgsql;

-- Populate stroke index allocations for all tees on a course
CREATE OR REPLACE FUNCTION populate_course_stroke_indexes(p_course_id integer)
RETURNS void AS $$
DECLARE
    v_tee_id integer;
BEGIN
    FOR v_tee_id IN 
        SELECT id FROM course_tee WHERE course_id = p_course_id
    LOOP
        PERFORM populate_stroke_index_allocations(v_tee_id);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Example usage after importing course data:
-- SELECT populate_course_stroke_indexes(1);  -- Ava course
-- SELECT populate_course_stroke_indexes(2);  -- Dufferin course

