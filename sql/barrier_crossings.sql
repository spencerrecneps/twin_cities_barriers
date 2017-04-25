------------------------------------------------------------
-- Searches od_points for connections that cross barriers
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS scratch.barrier_crossings;
CREATE TABLE scratch.barrier_crossings (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid)
);

INSERT INTO scratch.barrier_crossings (geom)
SELECT  ST_Centroid(ST_MakeLine(
            ST_ClosestPoint(a.geom,b.geom),
            ST_ClosestPoint(b.geom,a.geom)
        ))
FROM    scratch.barrier_polys a, scratch.barrier_polys b
WHERE   a.id != b.id
AND     (
            ST_Area(a.geom) > 10000
        OR  ST_Area(b.geom) > 10000
        )
AND     ST_DWithin(a.geom,b.geom,100)
AND     NOT EXISTS (
            SELECT  1
            FROM    scratch.barrier_polys p
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
