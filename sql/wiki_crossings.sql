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
    geom geometry(point,:db_srid),
    azi FLOAT,
    community_type TEXT,
    spacing INTEGER,
    raster_buffer INTEGER
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

-- index
CREATE INDEX sidx_wiki_crossings_geom ON automated.wiki_crossings USING GIST (geom);
ANALYZE automated.wiki_crossings (geom);

-- barrier characteristics
UPDATE  automated.wiki_crossings
SET     community_type = bl.community_type,
        spacing = bl.spacing,
        raster_buffer = bl.raster_buffer
FROM    barrier_lines bl
WHERE   bl.id = (
            SELECT      id
            FROM        barrier_lines bl2
            WHERE       ST_DWithin(wiki_crossings.geom,bl2.geom,10)
            ORDER BY    ST_Distance(wiki_crossings.geom,bl2.geom)
            LIMIT       1
        );

-- azimuth of barrier
UPDATE  automated.wiki_crossings
SET     azi = (
            SELECT      ST_Azimuth(
                            wiki_crossings.geom,
                            ST_EndPoint(
                                ST_Intersection(
                                    ST_Buffer(wiki_crossings.geom,1),
                                    bl.geom
                                )
                            )
                        )
            FROM        barrier_lines bl
            WHERE       ST_DWithin(wiki_crossings.geom,bl.geom,10)
            ORDER BY    ST_Distance(wiki_crossings.geom,bl.geom) ASC
            LIMIT       1
        );
