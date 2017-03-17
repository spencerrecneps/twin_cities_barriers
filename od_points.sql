------------------------------------------------------------
-- Creates the origin/destination points to be used
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS od_points;
CREATE TABLE generated.od_points (
    id SERIAL PRIMARY KEY,
    geoid TEXT,
    geom geometry(point,:db_srid)
);

-- insert points from census tracts
INSERT INTO od_points (geoid, geom)
SELECT  t.geoid, ST_Centroid(t.geom)
FROM    received.tl_2016_27_tract t
WHERE   EXISTS (
            SELECT  1
            FROM    community_designations cd
            WHERE   ST_Intersects(ST_Centroid(t.geom), cd.geom)
        );
