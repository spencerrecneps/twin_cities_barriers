------------------------------------------------------------
-- Searches od_points for connections that cross barriers
-- for generating a least-cost distance matrix.
-- Must be called with the :db_srid variable set
--   i.e. psql -v db_srid=26915
------------------------------------------------------------
-- create table
DROP TABLE IF EXISTS barrier_lines;
CREATE TABLE generated.barrier_lines (
    id SERIAL PRIMARY KEY,
    geom geometry(linestring,:db_srid),
    id_od_points1 INTEGER,
    id_od_points2 INTEGER
);

-- urban centers
INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,1000)      --only make connections within 1/2 mile
AND     od1.community = 'Urban center'
AND     od2.community = 'Urban center';

-- urban
INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,1500)      --only make connections within 3/4 mile
AND     od1.community = 'Urban'
AND     od2.community = 'Urban';

-- suburban
INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,2000)      --only make connections within 1 mile
AND     od1.community = 'Suburban'
AND     od2.community = 'Suburban';

-- rural
INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,3500)      --only make connections within 2 mile
AND     od1.community = 'Rural'
AND     od2.community = 'Rural';

------------------------
-- fill gaps
------------------------
-- urban centers
INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,1000)      --only make connections within 1/2 mile
AND     od1.community = 'Urban center'
AND     od2.community != 'Urban center';

INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,1500)      --only make connections within 1/2 mile
AND     od1.community = 'Urban center'
AND     od2.community != 'Urban center'
AND     NOT EXISTS (
            SELECT  1
            FROM    barrier_lines b
            WHERE   (od1.id = b.id_od_points1 AND od2.id = b.id_od_points2)
            OR      (od1.id = b.id_od_points2 AND od2.id = b.id_od_points1)
        )
AND     (
            SELECT  COUNT(o.id)
            FROM    od_points o
            WHERE   ST_DWithin(od1.geom,o.geom,1000)
            AND     o.id != od1.id
        ) < 6;

-- urban
INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,1500)      --only make connections within 3/4 mile
AND     od1.community = 'Urban'
AND     od2.community NOT IN ('Urban center','Urban');

INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,2000)      --only make connections within 1 mile
AND     od1.community = 'Urban'
AND     od2.community NOT IN ('Urban center','Urban')
AND     NOT EXISTS (
            SELECT  1
            FROM    barrier_lines b
            WHERE   (od1.id = b.id_od_points1 AND od2.id = b.id_od_points2)
            OR      (od1.id = b.id_od_points2 AND od2.id = b.id_od_points1)
        )
AND     (
            SELECT  COUNT(o.id)
            FROM    od_points o
            WHERE   ST_DWithin(od1.geom,o.geom,1000)
            AND     o.id != od1.id
        ) < 6;

-- suburban
INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,2000)      --only make connections within 1 mile
AND     od1.community = 'Suburban'
AND     od2.community NOT IN ('Urban center','Urban','Suburban');

INSERT INTO barrier_lines (geom, id_od_points1, id_od_points2)
SELECT  ST_MakeLine(od1.geom,od2.geom),
        od1.id,
        od2.id
FROM    od_points od1,
        od_points od2
WHERE   od1.id < od2.id
AND     ST_DWithin(od1.geom,od2.geom,3000)      --only make connections within 2 miles
AND     od1.community = 'Suburban'
AND     od2.community NOT IN ('Urban center','Urban','Suburban')
AND     NOT EXISTS (
            SELECT  1
            FROM    barrier_lines b
            WHERE   (od1.id = b.id_od_points1 AND od2.id = b.id_od_points2)
            OR      (od1.id = b.id_od_points2 AND od2.id = b.id_od_points1)
        )
AND     (
            SELECT  COUNT(o.id)
            FROM    od_points o
            WHERE   ST_DWithin(od1.geom,o.geom,1000)
            AND     o.id != od1.id
        ) < 6;



-- index
CREATE INDEX sidx_barrier_lines_geom ON generated.barrier_lines USING GIST (geom);
CREATE INDEX idx_barrier_lines_ids ON generated.barrier_lines (id_od_points1,id_od_points2);
ANALYZE generated.barrier_lines;

-- delete non-crossings
DELETE FROM generated.barrier_lines
WHERE NOT EXISTS (
    SELECT  1
    FROM    generated.barriers b
    WHERE   ST_Intersects(barrier_lines.geom,b.geom)
);
