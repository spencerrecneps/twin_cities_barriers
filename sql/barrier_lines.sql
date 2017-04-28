------------------------------------------------------------
-- Creates barrier lines from polygons extracted from
-- the cost raster.
-- Variables:
--      db_srid -> SRID
--      spacing_uc -> Spacing for urban centers (in CRS units)
--      spacing_urb -> Spacing for urban (in CRS units)
--      spacing_sub -> Spacing for suburban (in CRS units)
--      spacing_rur -> Spacing for rural (in CRS units)
------------------------------------------------------------
-- create tables
DROP TABLE IF EXISTS scratch.barrier_lines_raw;
CREATE TABLE scratch.barrier_lines_raw (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid)
);

DROP TABLE IF EXISTS scratch.barrier_lines_precut;
CREATE TABLE scratch.barrier_lines_precut (
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,:db_srid)
);

DROP TABLE IF EXISTS automated.barrier_lines;
CREATE TABLE automated.barrier_lines (
    id SERIAL PRIMARY KEY,
    geom geometry(linestring,:db_srid),
    community_type TEXT,
    spacing INTEGER,
    raster_buffer INTEGER
);

-- read barrier polys
INSERT INTO scratch.barrier_lines_raw (geom)
SELECT ST_ApproximateMedialAxis(geom)
FROM automated.barrier_polys;

-- index
CREATE INDEX sidx_barrier_lines_geom ON scratch.barrier_lines_raw USING GIST (geom);
ANALYZE scratch.barrier_lines_raw;

-- connect diagonals of single cells
INSERT INTO scratch.barrier_lines_raw (geom)
SELECT  ST_Multi(ST_MakeLine(
            ST_Centroid(a.geom),
            ST_Centroid(b.geom)
        ))
FROM    automated.barrier_polys a, automated.barrier_polys b
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
FROM    automated.barrier_polys a, scratch.barrier_lines_raw b
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

-- break up at intersections and stitch together adjacent lines
INSERT INTO scratch.barrier_lines_precut (geom)
SELECT  (ST_Dump(ST_LineMerge(ST_Node(geom)))).geom
FROM    (SELECT ST_Union(geom) AS geom FROM scratch.barrier_lines_raw) a;

-- index
CREATE INDEX sidx_barrier_lines_precut ON scratch.barrier_lines_precut USING GIST (geom);
ANALYZE scratch.barrier_lines_precut;

----------------------------------------------------
-- break barriers at community designations
----------------------------------------------------
-- urban center
INSERT INTO automated.barrier_lines (geom, community_type, spacing, raster_buffer)
SELECT  ST_Intersection(bl.geom,cd.geom),
        'urban center',
        :spacing_uc,
        :spacing_uc * 1.2
FROM    scratch.barrier_lines_precut bl,
        community_designations cd
WHERE   cd.comdes2040 = 23
AND     ST_Intersects(bl.geom,cd.geom);

-- urban
INSERT INTO automated.barrier_lines (geom, community_type, spacing, raster_buffer)
SELECT  ST_Intersection(bl.geom,cd.geom),
        'urban',
        :spacing_urb,
        :spacing_urb * 1.2
FROM    scratch.barrier_lines_precut bl,
        community_designations cd
WHERE   cd.comdes2040 = 24
AND     ST_Intersects(bl.geom,cd.geom);

-- suburban
INSERT INTO automated.barrier_lines (geom, community_type, spacing, raster_buffer)
SELECT  ST_Intersection(bl.geom,cd.geom),
        'suburban',
        :spacing_sub,
        :spacing_sub * 1.2
FROM    scratch.barrier_lines_precut bl,
        community_designations cd
WHERE   cd.comdes2040 > 24
AND     cd.comdes2040 <= 36
AND     ST_Intersects(bl.geom,cd.geom);

-- rural
INSERT INTO automated.barrier_lines (geom, community_type, spacing, raster_buffer)
SELECT  ST_Intersection(bl.geom,cd.geom),
        'rural',
        :spacing_rur,
        :spacing_rur * 1.2
FROM    scratch.barrier_lines_precut bl,
        community_designations cd
WHERE   cd.comdes2040 > 36
AND     ST_Intersects(bl.geom,cd.geom);

-- index
CREATE INDEX sidx_barrier_lines ON automated.barrier_lines USING GIST (geom);

-- drop raw tables
DROP TABLE IF EXISTS scratch.barrier_lines_raw;
DROP TABLE IF EXISTS scratch.barrier_lines_precut;
VACUUM ANALYZE;
