------------------------------------------------------------
-- Creates test origin-destination lines along the barriers
-- for testing route deviations.
-- Variables
--      db_srid -> SRID
--      line_len -> Line length
------------------------------------------------------------
DROP TABLE IF EXISTS automated.barrier_deviation_test_lines;
CREATE TABLE automated.barrier_deviation_test_lines (
    id SERIAL PRIMARY KEY,
    geom geometry(linestring,:db_srid),
    community_type TEXT,
    spacing INTEGER,
    raster_buffer INTEGER,
    cost_exist INTEGER,
    cost_improved INTEGER
);


------------------------------------------
-- known points (planned, collectors, wiki)
------------------------------------------
-- planned_crossings
INSERT INTO automated.barrier_deviation_test_lines (geom, community_type, spacing, raster_buffer)
SELECT  ST_SetSRID(
            ST_Rotate(
                ST_MakeLine(
                    ST_MakePoint(
                        ST_X(x.geom),
                        ST_Y(x.geom) + :line_len/2
                    ),
                    ST_MakePoint(
                        ST_X(x.geom),
                        ST_Y(x.geom) - :line_len/2
                    )
                ),
                -azi - pi()/2,                          -- rotate 90 degrees
                x.geom                                  -- use center point as the origin for rotation
            ),
            :db_srid
        ),
        community_type,
        spacing,
        raster_buffer
FROM    planned_crossings x;

-- wiki_crossings
INSERT INTO automated.barrier_deviation_test_lines (geom, community_type, spacing, raster_buffer)
SELECT  ST_SetSRID(
            ST_Rotate(
                ST_MakeLine(
                    ST_MakePoint(
                        ST_X(x.geom),
                        ST_Y(x.geom) + :line_len/2
                    ),
                    ST_MakePoint(
                        ST_X(x.geom),
                        ST_Y(x.geom) - :line_len/2
                    )
                ),
                -azi - pi()/2,                          -- rotate 90 degrees
                x.geom                                  -- use center point as the origin for rotation
            ),
            :db_srid
        ),
        community_type,
        spacing,
        raster_buffer
FROM    wiki_crossings x
WHERE   NOT EXISTS (
            SELECT  1
            FROM    planned_crossings pc
            WHERE   ST_DWithin(x.geom,pc.geom,x.spacing*0.3)
        )
AND     NOT EXISTS (
            SELECT  1
            FROM    generated.lakes
            WHERE   ST_Intersects(x.geom,lakes.geom)
        );

-- index
CREATE INDEX sidx_barrdevtestline_geom ON automated.barrier_deviation_test_lines USING GIST (geom);
ANALYZE automated.barrier_deviation_test_lines (geom);

------------------------------------------
-- additional points
------------------------------------------
-- segmentize lines
DROP TABLE IF EXISTS scratch.tmp_segs;
CREATE TABLE scratch.tmp_segs (
    id SERIAL PRIMARY KEY,
    geom geometry(linestring,:db_srid),
    community_type TEXT,
    spacing INTEGER,
    raster_buffer INTEGER
);
INSERT INTO tmp_segs (geom, community_type, spacing, raster_buffer)
SELECT  ST_LineSubstring(
            geom,
            i/ST_Length(geom),
            LEAST(i/ST_Length(geom) + spacing/ST_Length(geom),1)
        ) AS geom,
        community_type,
        spacing,
        raster_buffer
FROM    automated.barrier_lines,
        generate_series(0,floor(ST_Length(geom))::int,spacing) i
WHERE   i < ST_Length(geom)
AND     ST_Length(geom) - i > spacing;

-- get segment midpoints
DROP TABLE IF EXISTS scratch.tmp_pts;
CREATE TABLE scratch.tmp_pts (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid),
    azi FLOAT,
    community_type TEXT,
    spacing INTEGER,
    raster_buffer INTEGER
);
INSERT INTO scratch.tmp_pts (geom, azi, community_type, spacing, raster_buffer)
SELECT  ST_LineInterpolatePoint(geom,0.5) AS geom,
        ST_Azimuth(
            ST_StartPoint(geom),
            ST_EndPoint(geom)
        ) AS azi,
        community_type, spacing, raster_buffer
FROM    tmp_segs;

-- not near a collector crossing
INSERT INTO automated.barrier_deviation_test_lines (geom, community_type, spacing, raster_buffer)
SELECT  CASE
            WHEN ST_DWithin(tmp_pts.geom,cc.geom,tmp_pts.spacing*0.3)
                THEN    ST_SetSRID(
                            ST_Rotate(
                                ST_MakeLine(
                                    ST_MakePoint(
                                        ST_X(cc.geom),
                                        ST_Y(cc.geom) + :line_len/2
                                    ),
                                    ST_MakePoint(
                                        ST_X(cc.geom),
                                        ST_Y(cc.geom) - :line_len/2
                                    )
                                ),
                                -cc.azi - pi()/2,                       -- rotate 90 degrees
                                cc.geom                                 -- use center point as the origin for rotation
                            ),
                            :db_srid
                        )
            ELSE    ST_SetSRID(
                        ST_Rotate(
                            ST_MakeLine(
                                ST_MakePoint(
                                    ST_X(tmp_pts.geom),
                                    ST_Y(tmp_pts.geom) + :line_len/2
                                ),
                                ST_MakePoint(
                                    ST_X(tmp_pts.geom),
                                    ST_Y(tmp_pts.geom) - :line_len/2
                                )
                            ),
                            -tmp_pts.azi - pi()/2,                      -- rotate 90 degrees
                            tmp_pts.geom                                -- use center point as the origin for rotation
                        ),
                        :db_srid
                    )
        END,
        tmp_pts.community_type,
        tmp_pts.spacing,
        tmp_pts.raster_buffer
FROM    tmp_pts,
        collector_crossings cc
WHERE   cc.id = (
            SELECT      id
            FROM        collector_crossings cc2
            ORDER BY    ST_Distance(tmp_pts.geom,cc2.geom)
            LIMIT       1
        )
AND     NOT EXISTS (
            SELECT  1
            FROM    automated.barrier_deviation_test_lines tl
            WHERE   ST_DWithin(tmp_pts.geom,tl.geom,tmp_pts.spacing*0.3)
        )
AND     NOT EXISTS (
            SELECT  1
            FROM    generated.lakes
            WHERE   ST_Intersects(tmp_pts.geom,lakes.geom)
        );
