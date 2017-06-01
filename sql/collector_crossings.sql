------------------------------------------------------------
-- Identifies points where a collector road
-- crosses a barrier.
-- Variables
--   db_srid=26915
------------------------------------------------------------
DROP TABLE IF EXISTS automated.collector_crossings;
CREATE TABLE automated.collector_crossings (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid),
    azi FLOAT,
    community_type TEXT,
    spacing INTEGER,
    raster_buffer INTEGER
);

WITH pts AS (
    SELECT  (ST_Dump(ST_Force2D(ST_Intersection(b.geom,roads.geom)))).geom AS geom
    FROM    barrier_lines b,
            roads_metro roads
    WHERE   roads.f_class LIKE 'A3%'
    AND     ST_Intersects(b.geom,roads.geom)
    AND     ST_Length(ST_Intersection(roads.geom,ST_Buffer(b.geom,5))) < 16
),
clusters AS (
    SELECT  ST_CollectionExtract(unnest(ST_ClusterWithin(pts.geom,30)),1) AS geom
    FROM    pts
)
INSERT INTO automated.collector_crossings (geom)
SELECT  (
            SELECT      ST_ClosestPoint(
                            bl.geom,
                            clusters.geom
                        )
            FROM        barrier_lines bl
            ORDER BY    ST_Distance(bl.geom,ST_Centroid(clusters.geom)) ASC
            LIMIT       1
        )
FROM    clusters;

-- index
CREATE INDEX sidx_collector_crossings_geom ON automated.collector_crossings USING GIST (geom);
ANALYZE automated.collector_crossings (geom);

-- barrier characteristics
UPDATE  automated.collector_crossings
SET     community_type = bl.community_type,
        spacing = bl.spacing,
        raster_buffer = bl.raster_buffer
FROM    barrier_lines bl
WHERE   bl.id = (
            SELECT      id
            FROM        barrier_lines bl2
            WHERE       ST_DWithin(collector_crossings.geom,bl2.geom,10)
            ORDER BY    ST_Distance(collector_crossings.geom,bl2.geom)
            LIMIT       1
        );

-- azimuth of barrier
UPDATE  automated.collector_crossings
SET     azi = (
            SELECT      ST_Azimuth(
                            collector_crossings.geom,
                            ST_EndPoint(
                                ST_Intersection(
                                    ST_Buffer(collector_crossings.geom,40),
                                    bl.geom
                                )
                            )
                        )
            FROM        barrier_lines bl
            WHERE       ST_DWithin(collector_crossings.geom,bl.geom,10)
            ORDER BY    ST_Distance(collector_crossings.geom,bl.geom) ASC
            LIMIT       1
        );
