SELECT  1,
        ST_CostDistance(
            ST_MakeEmptyRaster(
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
            ),
            '16BUI',
            raster_facilities.rast,
            'scratch',
            'raster_test',
            'geom',
            11000
        )
INTO    scratch.cost_test
FROM    raster_facilities


--
--
-- CREATE OR REPLACE FUNCTION ST_CostDistance(refrast raster,
--                                                                                                 pixeltype text,
--                                                                                                 costrast raster,
--                                                                                                 sourceschema text,
--                                                                                                 sourcetable text,
--                                                                                                 sourcegeomcolumn text,
--                                                                                                 double precision = -1)
