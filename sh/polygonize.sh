#!/bin/bash

# can source vars from externally via
# source ../project_setup.sh && ./polygonize.sh -s scratch -t barrier_polys -l 11110 ~/gis/twin_cities_barriers/cost_composite.tif

DBHOST="${DBHOST:-localhost}"
DBUSER="${DBUSER:-gis}"
DBPASS="${DBPASS:-gis}"
PGPASSWORD="${DBPASS}"
DBNAME="${DBNAME:-none}"
DBSRID="${DBSRID:-4326}"
DEBUG=0

function usage() {
    echo -n \
"
Usage: $(basename "$0") [-h] [-d] [-u <limit>] [-l <limit>] -s <schema> -t <table> <raster file>

Polygonize a raster and save to PostGIS database.

Additional arguments are:

-h - Display this help
-d - Debug mode (doesn't delete temporary files)
-u <limit> - Upper limit filter for the raster file
-l <limit> - Lower limit filter for the raster file
-s <schema> - Schema to use in the database
-t <table> - Table name

Optional ENV vars:

DBHOST - Default: localhost
DBUSER - Default: gis
DBPASS - Default: gis
DBNAME - Default: none
DBSRID - Default: 4326

"
}

# Parse the command line options
hasT=0
hasL=0
hasU=0
while getopts "h?d?s:?t:u:l:" opt; do
    case "$opt" in
    h)  usage
        exit 0
        ;;
    d)  DEBUG=1
        ;;
    s)  DBSCHEMA=${OPTARG}
        ;;
    t)  DBTABLE=${OPTARG}
        hasT=1
        ;;
    l)  LOWER=${OPTARG}
        hasL=1
        ;;
    u)  UPPER=${OPTARG}
        hasL=1
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
if [ ${hasT} -eq 0 ]; then
    echo "Missing -t option for table name"
    usage
    exit 1
fi
shift $(($OPTIND - 1))

# Set up temp directory
TEMPDIR=`mktemp -d`
if [ ${DEBUG} -eq 1 ]; then
    echo "Saving files to ${TEMPDIR}"
fi

# set mask and polygonize
if [ ${hasU} -eq 1 ] && [ ${hasL} -eq 1 ]; then
    gdal_calc.py -A $1 --outfile="${TEMPDIR}/mask.tif" --calc="A>=${LOWER} AND A<=${UPPER}"
    gdal_polygonize.py $1 -mask "${TEMPDIR}/mask.tif" -f "PGDump" "${TEMPDIR}/o.txt" "${DBSCHEMA}.${DBTABLE}"
elif [ ${hasU} -eq 1 ]; then
    gdal_calc.py -A $1 --outfile="${TEMPDIR}/mask.tif" --calc="A<=${UPPER}"
    gdal_polygonize.py $1 -mask "${TEMPDIR}/mask.tif" -f "PGDump" "${TEMPDIR}/o.txt" "${DBSCHEMA}.${DBTABLE}"
elif [ ${hasL} -eq 1 ]; then
    gdal_calc.py -A $1 --outfile="${TEMPDIR}/mask.tif" --calc="A>=${LOWER}"
    gdal_polygonize.py $1 -mask "${TEMPDIR}/mask.tif" -f "PGDump" "${TEMPDIR}/o.txt" "${DBSCHEMA}.${DBTABLE}"
else
    gdal_polygonize.py $1 -f "PGDump" "${TEMPDIR}/o.txt" "${DBSCHEMA}.${DBTABLE}"
fi

# save to db
psql -h ${DBHOST} -d ${DBNAME} -U ${DBUSER} \
    -c "drop table if exists \"${DBSCHEMA}\".\"${DBTABLE}\";"
psql -h ${DBHOST} -d ${DBNAME} -U ${DBUSER} -f "${TEMPDIR}/o.txt"

# clean up
psql -h ${DBHOST} -d ${DBNAME} -U ${DBUSER} \
    -c "alter table \"${DBSCHEMA}\".\"${DBTABLE}\" add column geom geometry(polygon,${DBSRID});"
psql -h ${DBHOST} -d ${DBNAME} -U ${DBUSER} \
    -c "update \"${DBSCHEMA}\".\"${DBTABLE}\" set geom = st_makepolygon(st_exteriorring(wkb_geometry));"
psql -h ${DBHOST} -d ${DBNAME} -U ${DBUSER} \
    -c "alter table \"${DBSCHEMA}\".\"${DBTABLE}\" drop column wkb_geometry;"

# delete temp dir
if [ ${DEBUG} -eq 0 ]; then
    rm -rf "${TEMPDIR}"
fi
