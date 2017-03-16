------------------------------------------------------------
-- Creates the rasterized facility layers that will be
-- combined to create a cost surface for routing.
-- Must be called with the :db_srid, :cell_size, and
-- :tile_size variables set
--   i.e. psql -v db_srid=26915 -v cell_size=30 -v tile_size=50
------------------------------------------------------------
-- drop
DROP TABLE IF EXISTS generated.raster_facilities;

-- create
CREATE TABLE generated.raster_facilities (id SERIAL PRIMARY KEY, rast raster);

-- add facilities
WITH ref AS (
    SELECT ST_MakeEmptyRaster(
        (
            SELECT  CEILING((ST_XMax(e.geom) - ST_XMin(e.geom)) / :cell_size)
            FROM    (SELECT ST_Extent(geom) AS geom FROM community_designations) e
        )::INTEGER,
        (
            SELECT  CEILING((ST_YMax(e.geom) - ST_YMin(e.geom)) / :cell_size)
            FROM    (SELECT ST_Extent(geom) AS geom FROM community_designations) e
        )::INTEGER,
        (SELECT ST_XMin(ST_Extent(geom)) FROM community_designations)::INTEGER,
        (SELECT ST_YMax(ST_Extent(geom)) FROM community_designations)::INTEGER,
        :cell_size,
        -:cell_size,
        0, 0,
        :db_srid
    ) AS rast
),
exist AS (
    SELECT ST_Union(ST_AsRaster(
        geom,
        ref.rast,
        '16BUI',    -- 16 bits allows values up to 65,536
        cell_cost,
        9999,       -- nodata
        TRUE        -- assign value if geom touches the cell
    )) AS rast
    FROM    bike_fac_costs_exist, ref
),
plan AS (
    SELECT ST_Union(ST_AsRaster(
        geom,
        ref.rast,
        '16BUI',    -- 16 bits allows values up to 65,536
        cell_cost,
        9999,       -- nodata
        TRUE        -- assign value if geom touches the cell
    )) AS rast
    FROM    bike_fac_costs_plan, ref
),
locals AS (
    SELECT ST_Union(ST_AsRaster(
        geom,
        ref.rast,
        '16BUI',    -- 16 bits allows values up to 65,536
        cell_cost,
        9999,       -- nodata
        TRUE        -- assign value if geom touches the cell
    )) AS rast
    FROM    bike_fac_costs_locals, ref
),
allrast AS (
    SELECT exist.rast AS rast FROM exist
    UNION ALL
    SELECT plan.rast FROM plan
    UNION ALL
    SELECT locals.rast FROM locals
)
INSERT INTO generated.raster_facilities (rast)
SELECT
    ST_Tile(
        ST_Union(allrast.rast, 'MIN'),
        :tile_size,
        :tile_size,
        TRUE,       --pad with nodata
        9999        --nodata=9999
    )
FROM    allrast;

-- set constraints
SELECT AddRasterConstraints('raster_facilities'::name, 'rast'::name);

-- index
CREATE INDEX sidx_raster_facilities_rast ON generated.raster_facilities USING GIST (rast);
