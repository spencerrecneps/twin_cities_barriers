------------------------------------------------------------
-- Searches od_points for connections that cross barriers
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS barrier_points;
CREATE TABLE automated.barrier_points (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid),
    community_type TEXT,
    point_type TEXT
);

-- insert
INSERT INTO automated.barrier_points (geom, community_type, point_type)
SELECT  ST_Centroid(geom),
        community_type,
        point_type
FROM    barrier_deviation_test_lines
WHERE   cost_exist >    CASE
                        WHEN community_type = 'urban center' THEN 600
                        WHEN community_type = 'urban' THEN 900
                        WHEN community_type = 'suburban' THEN 1200
                        WHEN community_type = 'rural' THEN 2400
                        END;
