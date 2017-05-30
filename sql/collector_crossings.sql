------------------------------------------------------------
-- Identifies points where a collector road
-- crosses a barrier.
-- Variables
--   db_srid=26915
------------------------------------------------------------
DROP TABLE IF EXISTS automated.collector_crossings;
CREATE TABLE automated.collector_crossings (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid)
);

WITH pts AS (
    SELECT  (ST_Dump(ST_Force2D(ST_Intersection(b.geom,roads.geom)))).geom AS geom
    FROM    barrier_lines b,
            roads_metro roads
    WHERE   roads.f_class LIKE 'A3%'
    AND     ST_Intersects(b.geom,roads.geom)
    AND     ST_Length(ST_Intersection(roads.geom,ST_Buffer(b.geom,5))) < 8
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
