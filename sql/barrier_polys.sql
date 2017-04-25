------------------------------------------------------------
-- Takes raw barrier polygons and combines adjacent
-- features for a continuous barrier.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS scratch.barrier_polys;
CREATE TABLE scratch.barrier_polys (
    id SERIAL PRIMARY KEY,
    geom geometry(polygon,:db_srid)
);

INSERT INTO scratch.barrier_polys (geom)
SELECT  (ST_Dump(ST_Union(ST_Buffer(geom,5)))).geom
FROM    scratch.barrier_polys_raw;

CREATE INDEX sidx_barrier_polys_geom ON scratch.barrier_polys USING GIST (geom);
ANALYZE scratch.barrier_polys;
