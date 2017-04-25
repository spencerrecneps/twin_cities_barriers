------------------------------------------------------------
-- Searches od_points for connections that cross barriers
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS scratch.barrier_pointsdump;
CREATE TABLE scratch.barrier_pointsdump (
    id SERIAL PRIMARY KEY,
    feat INTEGER,
    pt INTEGER,
    geom geometry(point,:db_srid)
);

DROP TABLE IF EXISTS automated.barrier_lines;
CREATE TABLE automated.barrier_lines (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid)
);

-- INSERT INTO automated.barrier_lines (geom)
-- SELECT ST_ApproximateMedialAxis(geom)
-- FROM scratch.barrier_polys;


INSERT INTO scratch.barrier_pointsdump (feat, pt, geom)
SELECT (dump).path[1], (dump).path[2], (dump).geom
FROM (SELECT ST_DumpPoints(ST_ApproximateMedialAxis(geom)) AS dump FROM scratch.barrier_polys) a;

CREATE INDEX sidx_barrier_pointsdump ON scratch.barrier_pointsdump USING GIST (geom);
ANALYZE scratch.barrier_pointsdump;


-- WITH RECURSIVE pts AS (
--     SELECT  id, id AS base_id, 1 AS ord, feat, pt, geom
--     FROM    barrier_pointsdump
--     UNION
--     SELECT  b.id, p.base_id, p.ord + 1, b.feat, b.pt, b.geom
--     FROM    barrier_pointsdump b,
--             pts p
--     WHERE   NOT EXISTS (
--                 SELECT  1
--                 FROM    pts p2
--                 WHERE   b.geom = p2.geom
--             )
-- )
-- SELECT * FROM pts;
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
-- -- index
-- CREATE INDEX sidx_barrier_lines_geom ON automated.barrier_lines USING GIST (geom);
-- ANALYZE automated.barrier_lines;
