------------------------------------------------------------
-- Layer of all combined barriers for identifying
-- potential crossings in barrier_lines.sql
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS barriers;
CREATE TABLE automated.barriers (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid),
    source TEXT
);

-- bike_fac_costs_expys
INSERT INTO automated.barriers (geom, source)
SELECT geom, 'Expressways'
FROM bike_fac_costs_expys;

-- bike_fac_costs_rails
INSERT INTO automated.barriers (geom, source)
SELECT geom, 'Railroads'
FROM bike_fac_costs_rails;

-- bike_fac_costs_streams
INSERT INTO automated.barriers (geom, source)
SELECT geom, 'Streams'
FROM bike_fac_costs_streams;

-- index
CREATE INDEX sidx_barriers_geom ON automated.barriers USING GIST (geom);
ANALYZE automated.barriers;
