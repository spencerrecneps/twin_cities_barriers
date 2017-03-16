------------------------------------------------------------
-- Creates the cost layers that will be rasterized
-- and combined to create a cost surface for routing.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create tables (we have to do separate tables for each input
--   due to issue with the GDAL tool that we use)
DROP TABLE IF EXISTS generated.bike_fac_costs_exist;
DROP TABLE IF EXISTS generated.bike_fac_costs_plan;
DROP TABLE IF EXISTS generated.bike_fac_costs_locals;
CREATE TABLE generated.bike_fac_costs_exist (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid),
    cell_cost INTEGER
);
CREATE TABLE generated.bike_fac_costs_plan (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid),
    cell_cost INTEGER
);
CREATE TABLE generated.bike_fac_costs_locals (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid),
    cell_cost INTEGER
);

-- insert existing
INSERT INTO generated.bike_fac_costs_exist (
    geom, cell_cost
)
--SELECT  ST_Multi(ST_Buffer(ST_Buffer(geom,7,'endcap=flat'),1)),
SELECT  ST_Force2D(geom),
        1
FROM    bikeways_rbtn
WHERE   regstat = 1;

-- insert planned
INSERT INTO generated.bike_fac_costs_plan (
    geom, cell_cost
)
SELECT  ST_Force2D(geom),
        2
FROM    bikeways_rbtn
WHERE   regstat IN (2,3);

-- insert locals
INSERT INTO generated.bike_fac_costs_locals (
    geom, cell_cost
)
SELECT  ST_Force2D(geom),
        4
FROM    roads_metro
WHERE   f_class = 'A40';        -- need to determine how to define "local" road, assume A40 for now

-- indexes
CREATE INDEX sidx_bkfaccostex_geom ON generated.bike_fac_costs_exist USING GIST (geom);
ANALYZE generated.bike_fac_costs_exist;
CREATE INDEX sidx_bkfaccostpl_geom ON generated.bike_fac_costs_plan USING GIST (geom);
ANALYZE generated.bike_fac_costs_plan;
CREATE INDEX sidx_bkfaccostlo_geom ON generated.bike_fac_costs_locals USING GIST (geom);
ANALYZE generated.bike_fac_costs_locals;
--
--
--
-- -- insert all linework into a temporary holding table
-- CREATE TEMPORARY TABLE tmp_alllines (
--     id SERIAL PRIMARY KEY,
--     geom geometry(multilinestring,:db_srid),
--     fac_type TEXT
-- ) ON COMMIT DROP;
--
-- INSERT INTO tmp_alllines (geom, fac_type)
-- SELECT  ST_Force2D(geom),
--         CASE    WHEN regstat IN (2,3) THEN 'planned'
--                 WHEN regstat = 1 THEN 'existing'
--                 END
-- FROM    bikeways_rbtn
--
--
-- -- add polygons
-- INSERT INTO generated.bike_fac_costs (geom, fac_type, cell_cost)
-- SELECT  ST_Buffer(ST_Union(ST_Buffer(geom,5,'endcap=flat')),3),
--
--
--
-- -- (inspired by
-- -- http://gis.stackexchange.com/questions/83/separate-polygons-based-on-intersection-using-postgis )
-- INSERT INTO generated.bike_fac_costs (geom)
-- SELECT  geom
-- FROM    ST_Dump(
--             (
--                 SELECT  ST_Polygonize(geom) AS geom
--                 FROM    (
--                             SELECT  ST_Union(geom) AS geom
--                             FROM    (
--                                         SELECT  ST_ExteriorRing(geom) AS geom
--                                         FROM
--                                     )
--                         )
--             )
--         )
--         'planned facility',
--         5
-- FROM    bikeways_rbtn
-- WHERE   regstat IN (2,3);
--
--
--
--
-- SELECT geom FROM ST_Dump((
--     SELECT ST_Polygonize(the_geom) AS the_geom FROM (
--         SELECT ST_Union(the_geom) AS the_geom FROM (
--             SELECT ST_ExteriorRing(polygon_col) AS the_geom FROM my_table) AS lines
--         ) AS noded_lines
--     )
-- )
--
--
-- gdal merge
