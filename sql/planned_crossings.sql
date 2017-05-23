------------------------------------------------------------
-- Identifies points where a planned facility
-- crosses a barrier.
-- Variables
--   db_srid=26915
------------------------------------------------------------
DROP TABLE IF EXISTS automated.planned_crossings;
CREATE TABLE automated.planned_crossings (
    id SERIAL PRIMARY KEY,
    geom geometry(point,:db_srid)
);

INSERT INTO automated.planned_crossings (geom)
SELECT  (ST_Dump(ST_Intersection(b.geom,p.geom))).geom
FROM    barrier_lines b,
        bike_fac_costs_plan p
WHERE   ST_Intersects(b.geom,p.geom);
