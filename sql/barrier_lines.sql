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
    geom geometry(linestring,:db_srid)
);

DROP TABLE IF EXISTS scratch.commdes_union;
CREATE TABLE scratch.commdes_union (
    id SERIAL PRIMARY KEY,
    geom geometry(multipolygon,:db_srid),
    community_type TEXT,
    spacing INTEGER
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
-- combine community designations into single
-- geometries
----------------------------------------------------
-- urban center
INSERT INTO scratch.commdes_union (geom, community_type, spacing)
SELECT  ST_Multi(ST_Buffer(ST_Union(ST_Buffer(geom,10)),-10)),
        'urban center',
        :spacing_uc
FROM    community_designations cd
WHERE   cd.comdes2040 = 23;

-- urban
INSERT INTO scratch.commdes_union (geom, community_type, spacing)
SELECT  ST_Multi(ST_Buffer(ST_Union(ST_Buffer(geom,10)),-10)),
        'urban',
        :spacing_urb
FROM    community_designations cd
WHERE   cd.comdes2040 = 24;

-- suburban
INSERT INTO scratch.commdes_union (geom, community_type, spacing)
SELECT  ST_Multi(ST_Buffer(ST_Union(ST_Buffer(geom,10)),-10)),
        'suburban',
        :spacing_sub
FROM    community_designations cd
WHERE   cd.comdes2040 > 24
AND     cd.comdes2040 <= 36;

-- rural
INSERT INTO scratch.commdes_union (geom, community_type, spacing)
SELECT  ST_Multi(ST_Buffer(ST_Union(ST_Buffer(geom,10)),-10)),
        'rural',
        :spacing_rur
FROM    community_designations cd
WHERE   cd.comdes2040 > 36;

CREATE INDEX sidx_commdes_union ON scratch.commdes_union USING GIST (geom);
ANALYZE scratch.commdes_union;


----------------------------------------------------
-- break barriers at community designations
----------------------------------------------------
INSERT INTO automated.barrier_lines (geom, community_type, spacing, raster_buffer)
SELECT  bl.geom,
        cd.community_type,
        cd.spacing,
        cd.spacing * 1.2
FROM    scratch.barrier_lines_precut bl,
        commdes_union cd
WHERE   ST_Intersects(bl.geom,cd.geom)
AND     cd.id = (
            SELECT      id
            FROM        commdes_union c2
            WHERE       ST_Intersects(bl.geom,c2.geom)
            ORDER BY    ST_Length(ST_Intersection(bl.geom,c2.geom)) DESC
            LIMIT       1
        );

-- index
CREATE INDEX sidx_barrier_lines ON automated.barrier_lines USING GIST (geom);

-- drop raw tables
DROP TABLE IF EXISTS scratch.barrier_lines_raw;
DROP TABLE IF EXISTS scratch.barrier_lines_precut;
DROP TABLE IF EXISTS scratch.commdes_union;
