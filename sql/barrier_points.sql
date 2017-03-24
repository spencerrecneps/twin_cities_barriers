------------------------------------------------------------
-- Searches od_points for connections that cross barriers
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS barrier_points;
CREATE TABLE generated.barrier_points (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid)
);

-- insert
WITH all_barriers AS (
    SELECT  (ST_Dump(ST_Intersection(bl.geom, barriers.geom))).geom
    FROM    barrier_lines bl,
            barriers
    WHERE   ST_Intersects(bl.geom,barriers.geom)
    AND     (
                (bl.cost_exist > 500 AND bl.cost_improved::FLOAT / bl.cost_exist < 0.7)
            OR  (bl.cost_exist < 500 AND bl.cost_improved::FLOAT / bl.cost_exist < 0.5)
            )
)
INSERT INTO generated.barrier_points (geom)
SELECT  ST_Centroid(
            unnest(
                ST_ClusterWithin(
                        geom,
                        100
                )
            )
        )
FROM    all_barriers;
