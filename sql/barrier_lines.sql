------------------------------------------------------------
-- Searches od_points for connections that cross barriers
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create tables
DROP TABLE IF EXISTS scratch.barrier_lines_raw;
CREATE TABLE scratch.barrier_lines_raw (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid)
);

DROP TABLE IF EXISTS scratch.barrier_pointsdump;
CREATE TABLE scratch.barrier_pointsdump (
    id SERIAL PRIMARY KEY,
    rawid INTEGER,
    feat INTEGER,
    pt INTEGER,
    geom geometry(point,:db_srid)
);



DROP TABLE IF EXISTS automated.barrier_lines;
CREATE TABLE automated.barrier_lines (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid)
);

-- read barrier polys
INSERT INTO scratch.barrier_lines_raw (geom)
SELECT ST_ApproximateMedialAxis(geom)
FROM scratch.barrier_polys;

-- index
CREATE INDEX sidx_barrier_lines_geom ON scratch.barrier_lines_raw USING GIST (geom);
ANALYZE scratch.barrier_lines_raw;

-- connect diagonals of single cells
INSERT INTO scratch.barrier_lines_raw (geom)
SELECT  ST_Multi(ST_MakeLine(
            ST_Centroid(a.geom),
            ST_Centroid(b.geom)
        ))
FROM    scratch.barrier_polys a, scratch.barrier_polys b
WHERE   a.ogc_fid != b.ogc_fid
AND     a.ogc_fid > b.ogc_fid
AND     ST_DWithin(a.geom,b.geom,5)
AND     ST_Area(a.geom) = 30*30
AND     ST_Area(b.geom) = 30*30;

-- connect diagonals of one single cell
INSERT INTO scratch.barrier_lines_raw (geom)
SELECT  ST_Multi(ST_MakeLine(
            ST_Centroid(a.geom),
            ST_ClosestPoint(b.geom,a.geom)
        ))
FROM    scratch.barrier_polys a, scratch.barrier_lines_raw b
WHERE   NOT EXISTS (
            SELECT  1
            FROM    scratch.barrier_lines_raw r
            WHERE   ST_Intersects(a.geom,r.geom)
        )
AND     ST_DWithin(a.geom,b.geom,ceil(sqrt(30^2+30^2)/2))   -- half the diagonal length of a 30x30 cell
AND     ST_Area(a.geom) = 30*30;

-- connect diagonal gaps
INSERT INTO scratch.barrier_lines_raw (geom)
SELECT  ST_Multi(ST_MakeLine(
            ST_ClosestPoint(a.geom,b.geom),
            ST_ClosestPoint(b.geom,a.geom)
        ))
FROM    scratch.barrier_lines_raw a, scratch.barrier_lines_raw b
WHERE   a.id != b.id
AND     a.id > b.id
AND     ST_DWithin(a.geom,b.geom,ceil(sqrt(30^2+30^2)));   -- the diagonal length of a 30x30 cell

-- dump points
INSERT INTO scratch.barrier_pointsdump (rawid, feat, pt, geom)
SELECT id, (dump).path[1], (dump).path[2], (dump).geom
FROM (SELECT id, ST_DumpPoints(geom) AS dump FROM scratch.barrier_lines_raw) a;

CREATE INDEX sidx_barrier_pointsdump ON scratch.barrier_pointsdump USING GIST (geom);
ANALYZE scratch.barrier_pointsdump;



--
DROP TABLE IF EXISTS scratch.linemerge;
CREATE TABLE scratch.linemerge (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,26915)
);
insert into linemerge (geom)
select st_multi(st_collectionextract(st_linemerge(geom),2))
from barrier_lines_raw


-- build lines
WITH RECURSIVE pts AS (
    SELECT  id, id AS base_id, 1 AS ord, feat, pt, geom
    FROM    barrier_pointsdump
    UNION
    SELECT  b.id, p.base_id, p.ord + 1, b.feat, b.pt, b.geom
    FROM    barrier_pointsdump b,
            pts p
    WHERE   NOT EXISTS (
                SELECT  1
                FROM    pts p2
                WHERE   b.geom = p2.geom
            )
)
SELECT * FROM pts;
--
--
--
--
--
-- INSERT INTO automated.barrier_lines (geom)
--
-- from
-- (select id, st_dumppoints(geom) as geom from barrier_lines limit 100) a
--
--
--
--
--
--
