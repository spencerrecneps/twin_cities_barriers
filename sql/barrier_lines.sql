------------------------------------------------------------
-- Searches od_points for connections that cross barriers
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS barrier_lines;
CREATE TABLE automated.barrier_lines (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid)
);

INSERT INTO automated.barrier_lines (geom)
SELECT ST_ApproximateMedialAxis(geom)
FROM scratch.barrier_polys;

-- UPDATE  automated.barrier_lines
-- SET     geom = ST_Simplify(geom,60,True);

-- index
CREATE INDEX sidx_barrier_lines_geom ON automated.barrier_lines USING GIST (geom);
ANALYZE automated.barrier_lines;


create table scratch.tmp_i (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid)
);
insert into tmp_i (geom) select st_segmentize(geom,100) from barrier_lines;
