------------------------------------------------------------
-- Identifies points where a cluster of wikimap
-- comments suggest a new barrier crossing.
-- Variables
--   db_srid=26915
--   cluster_tolerance=50
--   num_points=2
--   max_barrier_dist=300
------------------------------------------------------------
DROP TABLE IF EXISTS automated.wiki_crossings;
CREATE TABLE automated.wiki_crossings (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid)
);

WITH clusters AS (
    SELECT  ST_CollectionExtract(unnest(ST_ClusterWithin(wiki.geom,:cluster_tolerance)),1) AS geom
    FROM    received.wiki_comments wiki
    WHERE   name = 'suggested new crossing'
)
INSERT INTO automated.wiki_crossings (geom)
SELECT  (
            SELECT      ST_ClosestPoint(bl.geom,ST_Centroid(clusters.geom))
            FROM        barrier_lines bl
            WHERE       ST_DWithin(bl.geom,clusters.geom,:max_barrier_dist)
            ORDER BY    ST_Distance(bl.geom,ST_Centroid(clusters.geom)) ASC
            LIMIT       1
        )
FROM    clusters
WHERE   ST_NPoints(geom) >= :num_points
AND     EXISTS (
            SELECT  1
            FROM    barrier_lines bl
            WHERE   ST_DWithin(bl.geom,clusters.geom,:max_barrier_dist)
        );
