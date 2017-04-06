#!/bin/bash

gdal_polygonize.py cost_composite.tif -f "PGDump" o.txt "scratch.barrier_polys"

alter table barrier_polys add column geom geometry(polygon,26915);
update barrier_polys set geom = st_makepolygon(st_exteriorring(wkb_geometry));
