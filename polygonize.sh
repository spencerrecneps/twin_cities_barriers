#!/bin/bash

DBHOST="${DBHOST:-192.168.22.220}"
DBUSER="${DBUSER:-gis}"
DBPASS="${DBPASS:-gis}"
DBNAME="${DBNAME:-twin_cities_barriers}"
DBSRID="${DBSRID:-26915}"
set DBSCHEMA
set DBTABLE

function usage() {
    echo -n \
"
Usage: $(basename "$0") [-h] [-s] [-t] <raster file>

Polygonize a raster and then convert the polygons to centerlines.

Additional arguments are:

-h - Display this help
-s - Schema to use in the database
-t - Table name

Optional ENV vars:

DBHOST - Default: 192.168.22.220
DBUSER - Default: gis
DBPASS - Default: gis
DBNAME - Default: twin_cities_barriers
DBSRID - Default: 26915

"
}

# Parse the command line options
hasO=0
while getopts "h?s:?t:" opt; do
    case "$opt" in
    h)  usage
        exit 0
        ;;
    s)  DBSCHEMA=${OPTARG}
        ;;
    t)  DBTABLE=${OPTARG}
        hasO=1
        ;;
    \?)
        usage
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument"
        exit 1
    esac
done
if [ ${hasO} -eq 0 ]; then
    echo "Missing -t option for table name"
    usage
    exit 1
fi

# Set up temp directory
TEMPDIR=`mktemp -d`

gdal_polygonize.py cost_composite.tif -f "PGDump" o.txt "scratch.barrier_polys"

alter table barrier_polys add column geom geometry(polygon,26915);
update barrier_polys set geom = st_makepolygon(st_exteriorring(wkb_geometry));
