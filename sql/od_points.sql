------------------------------------------------------------
-- Creates the origin/destination points to be used
-- for identifying crossings.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS od_points;
CREATE TABLE automated.od_points (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid),
    community TEXT
);

-- insert points from urban centers
INSERT INTO od_points (geom, community)
SELECT  ST_Centroid(g.geom),
        'Urban center'
FROM    generated.grid_half_mi g
WHERE   EXISTS (
            SELECT  1
            FROM    community_designations c
            WHERE   ST_Intersects(g.geom,c.geom)
            AND     ST_Intersects(ST_Centroid(g.geom),c.geom)
            AND     c.tdg_community_designation = 'Urban Core'
        );

-- index
CREATE INDEX sidx_od_points_geom ON automated.od_points USING GIST (geom);
ANALYZE automated.od_points (geom);

-- insert points from urban
INSERT INTO od_points (geom, community)
SELECT  ST_Centroid(g.geom),
        'Urban'
FROM    generated.grid_threeqrtr_mi g
WHERE   EXISTS (
            SELECT  1
            FROM    community_designations c
            WHERE   ST_Intersects(g.geom,c.geom)
            AND     ST_Intersects(ST_Centroid(g.geom),c.geom)
            AND     c.tdg_community_designation = 'Urban'
        )
AND     NOT EXISTS (
            SELECT  1
            FROM    od_points p
            WHERE   ST_Intersects(g.geom,p.geom)
            AND     ST_DWithin(ST_Centroid(g.geom),p.geom,403)  -- 403m ~ 1/4 mi
        );
ANALYZE automated.od_points (geom);

-- insert points from suburban
INSERT INTO od_points (geom, community)
SELECT  ST_Centroid(g.geom),
        'Suburban'
FROM    generated.grid_one_mi g
WHERE   EXISTS (
            SELECT  1
            FROM    community_designations c
            WHERE   ST_Intersects(g.geom,c.geom)
            AND     ST_Intersects(ST_Centroid(g.geom),c.geom)
            AND     c.tdg_community_designation = 'Suburban'
        )
AND     NOT EXISTS (
            SELECT  1
            FROM    od_points p
            WHERE   ST_Intersects(g.geom,p.geom)
            AND     ST_DWithin(ST_Centroid(g.geom),p.geom,606)  -- 606m ~ 3/8 mi
        );
ANALYZE automated.od_points (geom);

-- insert points from rural
INSERT INTO od_points (geom, community)
SELECT  ST_Centroid(g.geom),
        'Rural'
FROM    generated.grid_two_mi g
WHERE   EXISTS (
            SELECT  1
            FROM    community_designations c
            WHERE   ST_Intersects(g.geom,c.geom)
            AND     ST_Intersects(ST_Centroid(g.geom),c.geom)
            AND     c.tdg_community_designation = 'Rural'
        )
AND     NOT EXISTS (
            SELECT  1
            FROM    od_points p
            WHERE   ST_Intersects(g.geom,p.geom)
            AND     ST_DWithin(ST_Centroid(g.geom),p.geom,805)  -- 805m ~ 1/2 mi
        );

-- index
CREATE INDEX idx_od_points_community ON automated.od_points (community);
ANALYZE automated.od_points;
