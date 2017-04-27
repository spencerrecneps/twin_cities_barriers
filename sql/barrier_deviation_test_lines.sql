------------------------------------------------------------
-- Creates test origin-destination lines along the barriers
-- for testing route deviations.
-- Variables
--      db_srid -> SRID
--      max_dist -> Maximum distance between test points
--      line_len -> Line length
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS automated.barrier_deviation_test_lines;
CREATE TABLE automated.barrier_deviation_test_lines (
    id SERIAL PRIMARY KEY,
    geom geometry(linestring,:db_srid),
    cost_exist INTEGER,
    cost_improved INTEGER
);

-- draw lines
DROP TABLE IF EXISTS scratch.tmp_segs;
CREATE TABLE scratch.tmp_segs (id SERIAL PRIMARY KEY, geom geometry(linestring,:db_srid));
INSERT INTO tmp_segs (geom)
SELECT  ST_LineSubstring(
            geom,
            i/ST_Length(geom),
            LEAST(i/ST_Length(geom) + :max_dist/ST_Length(geom),1)
        ) AS geom
FROM    automated.barrier_lines,
        generate_series(0,floor(ST_Length(geom))::int,:max_dist) i
WHERE   i < ST_Length(geom)
AND     ST_Length(geom) - i > :max_dist;

DROP TABLE IF EXISTS scratch.tmp_pts;
CREATE TABLE scratch.tmp_pts (id SERIAL PRIMARY KEY, geom geometry(point,:db_srid), azi FLOAT);
INSERT INTO scratch.tmp_pts (geom, azi)
SELECT  ST_LineInterpolatePoint(geom,0.5) AS geom,
        ST_Azimuth(
            ST_StartPoint(geom),
            ST_EndPoint(geom)
        ) AS azi
FROM    tmp_segs;

INSERT INTO automated.barrier_deviation_test_lines (geom)
SELECT  ST_SetSRID(
            ST_Rotate(
                ST_MakeLine(
                    ST_MakePoint(
                        ST_X(geom),
                        ST_Y(geom) + :line_len/2
                    ),
                    ST_MakePoint(
                        ST_X(geom),
                        ST_Y(geom) - :line_len/2
                    )
                ),
                -azi - pi()/2,                          -- rotate 90 degrees
                geom                                    -- use center point as the origin for rotation
            ),
            :db_srid
        )
FROM    tmp_pts;
