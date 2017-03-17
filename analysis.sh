#!/bin/bash

#############################################################
## Processing instructions for the Twin Cities Barrier
## Analysis study
#############################################################

function usage() {
    echo -n \
"
Usage: $(basename "$0") [-h] [-v]

Run the Twin Cities Barriers analysis

Additional arguments are:

-h - Display this help
-v - Skip re-creation of the vector cost layer

Optional ENV vars:

DBHOST - Default: 192.168.22.220
DBUSER - Default: gis
DBPASS - Default: gis
DBNAME - Default: twin_cities_barriers
DBSRID - Default: 26915

"
}

# Parse the command line options
while getopts "h?v?" opt; do
    case "$opt" in
    h)  usage
        exit 0
        ;;
    v)  SKIPVECTOR=1
        ;;
    esac
done

# Set up
TEMPDIR=`mktemp -d`
cd `dirname $0`
echo "Saving temporary files to ${TEMPDIR}"
DBHOST="${DBHOST:-192.168.22.220}"
DBUSER="${DBUSER:-gis}"
DBPASS="${DBPASS:-gis}"
DBNAME="${DBNAME:-twin_cities_barriers}"
DBSRID="${DBSRID:-26915}"
SKIPVECTOR=0

# First, create the vector cost layers
if [ ${SKIPVECTOR} -eq 0 ]; then
    psql -h "${DBHOST}" -U "${DBUSER}" -d "${DBNAME}" \
        -v db_srid="${DBSRID}" \
        -f bike_fac_costs.sql
fi

# Rasterize
gdal_rasterize \
    -a cell_cost \
    -ot UInt16 \
    -tr 30 30 \
    -a_nodata 9999 \
    -co COMPRESS=DEFLATE \
    -co PREDICTOR=1 \
    -co ZLEVEL=6 \
    -at \
    -init 30 \
    -te 419967.47 4924223.79 521254.70 5029129.99 \
    -l "generated"."bike_fac_costs_exist" \
    "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
    "${TEMPDIR}/cost_input.tif"
