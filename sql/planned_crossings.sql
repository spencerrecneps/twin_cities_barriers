------------------------------------------------------------
-- Identifies points where a planned facility
-- crosses a barrier.
-- Variables
--   db_srid=26915
------------------------------------------------------------
DROP TABLE IF EXISTS automated.planned_crossings;
CREATE TABLE automated.planned_crossings (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid),
    azi FLOAT,
    community_type TEXT,
    spacing INTEGER,
    raster_buffer INTEGER
);

---------------------------------------------
-- All possible intersection points of all
-- all barrier types
---------------------------------------------
DROP TABLE IF EXISTS tmp_plancross;
CREATE TEMPORARY TABLE tmp_plancross (id SERIAL PRIMARY KEY, geom geometry(point,:db_srid));

-- expressways
INSERT INTO tmp_plancross (geom)
SELECT  (ST_Dump(ST_Intersection(b.geom,p.geom))).geom
FROM    bike_fac_costs_expys b,
        bike_fac_costs_plan p
WHERE   ST_Intersects(b.geom,p.geom);

-- railroads
INSERT INTO tmp_plancross (geom)
SELECT  (ST_Dump(ST_Intersection(b.geom,p.geom))).geom
FROM    bike_fac_costs_rails b,
        bike_fac_costs_plan p
WHERE   ST_Intersects(b.geom,p.geom);

-- streams
INSERT INTO tmp_plancross (geom)
SELECT  (ST_Dump(ST_Intersection(b.geom,p.geom))).geom
FROM    bike_fac_costs_streams b,
        bike_fac_costs_plan p
WHERE   ST_Intersects(b.geom,p.geom);

CREATE INDEX sidx_tmpplancrssgeom ON tmp_plancross USING GIST (geom); ANALYZE tmp_plancross;

-- grab center of clusters
WITH clusters AS (
    SELECT  unnest(ST_ClusterWithin(geom,50)) AS geom
    FROM    tmp_plancross
)
INSERT INTO automated.planned_crossings (geom)
SELECT  (
            SELECT      ST_ClosestPoint(
                            bl.geom,
                            (
                                SELECT      geom
                                FROM        ST_Dump(clusters.geom)
                                ORDER BY    ST_Distance(geom,ST_Centroid(clusters.geom)) ASC
                                LIMIT       1
                            )
                        )
            FROM        barrier_lines bl
            ORDER BY    ST_Distance(bl.geom,clusters.geom) ASC
            LIMIT       1
        )
FROM    clusters;

-- index
CREATE INDEX sidx_planned_crossings_geom ON automated.planned_crossings USING GIST (geom);
ANALYZE automated.planned_crossings (geom);

-- barrier characteristics
UPDATE  automated.planned_crossings
SET     community_type = bl.community_type,
        spacing = bl.spacing,
        raster_buffer = bl.raster_buffer
FROM    barrier_lines bl
WHERE   bl.id = (
            SELECT      id
            FROM        barrier_lines bl2
            WHERE       ST_DWithin(planned_crossings.geom,bl2.geom,30)
            ORDER BY    ST_Distance(planned_crossings.geom,bl2.geom)
            LIMIT       1
        );

-- azimuth of barrier
UPDATE  automated.planned_crossings
SET     azi = (
            SELECT      ST_Azimuth(
                            planned_crossings.geom,
                            ST_EndPoint(
                                ST_Intersection(
                                    ST_Buffer(planned_crossings.geom,1),
                                    bl.geom
                                )
                            )
                        )
            FROM        barrier_lines bl
            WHERE       ST_DWithin(planned_crossings.geom,bl.geom,10)
            ORDER BY    ST_Distance(planned_crossings.geom,bl.geom) ASC
            LIMIT       1
        );
