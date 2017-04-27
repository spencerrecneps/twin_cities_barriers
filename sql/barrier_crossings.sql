------------------------------------------------------------
-- Searches od_points for connections that cross barriers
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create tables
DROP TABLE IF EXISTS automated.barrier_polys_merged;
CREATE TABLE automated.barrier_polys_merged (
    id SERIAL PRIMARY KEY,
    geom geometry(polygon,:db_srid)
);

DROP TABLE IF EXISTS automated.barrier_crossings;
CREATE TABLE automated.barrier_crossings (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid)
);

-- merge barrier polys
INSERT INTO automated.barrier_polys_merged (geom)
SELECT  (ST_Dump(ST_Union(ST_Buffer(geom,5)))).geom
FROM    automated.barrier_polys;

-- index
CREATE INDEX sidx_barrierpolysmerged ON automated.barrier_polys_merged USING GIST (geom);
ANALYZE automated.barrier_polys_merged;

-- identify crossings
INSERT INTO automated.barrier_crossings (geom)
SELECT  ST_Centroid(ST_MakeLine(
            ST_ClosestPoint(a.geom,b.geom),
            ST_ClosestPoint(b.geom,a.geom)
        ))
FROM    automated.barrier_polys_merged a, automated.barrier_polys_merged b
WHERE   a.id != b.id
AND     (
            ST_Area(a.geom) > 10000
        OR  ST_Area(b.geom) > 10000
        )
AND     ST_DWithin(a.geom,b.geom,100)
AND     NOT EXISTS (
            SELECT  1
            FROM    automated.barrier_polys_merged p
            WHERE   p.id != a.id
            AND     p.id != b.id
            AND     ST_Intersects(
                        p.geom,
                        ST_MakeLine(
                                    ST_ClosestPoint(a.geom,b.geom),
                                    ST_ClosestPoint(b.geom,a.geom)
                        )
                    )
        );

-- index
CREATE INDEX sidx_barrier_crossings ON automated.barrier_crossings USING GIST (geom);

-- drop table
DROP TABLE IF EXISTS automated.barrier_polys_merged;
VACUUM ANALYZE;
