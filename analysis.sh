#!/bin/bash

#############################################################
## Processing instructions for the Twin Cities Barrier
## Analysis study
#############################################################

# Set up
DEBUG="${DEBUG:-0}"
DBHOST="${DBHOST:-192.168.22.220}"
DBUSER="${DBUSER:-gis}"
DBPASS="${DBPASS:-gis}"
DBNAME="${DBNAME:-twin_cities_barriers}"
DBSRID="${DBSRID:-26915}"
SKIPVECTOR="${SKIPEVECTOR:-0}"
TEMPDIR="${TEMPDIR:-none}"
OVERWRITE="${OVERWRITE:-0}"

function usage() {
    echo -n \
"
Usage: $(basename "$0") [-h] [-v] [-d] [-w] [-f <folder location>] -o <folder location>

Run the Twin Cities Barriers analysis

Additional arguments are:

-h - Display this help
-v - Skip re-creation of the vector files in the database
-d - Run in debug mode (doesn't delete temporary files)
-w - Overwrite any existing files
-f - Output folder to store intermediate files (if not given a temporary folder is used)
-o - Output folder to store final files

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
while getopts "h?v?d?f:?o:" opt; do
    case "$opt" in
    h)  usage
        exit 0
        ;;
    v)  SKIPVECTOR=1
        ;;
    d)  DEBUG=1
        ;;
    w)  OVERWRITE=1
        ;;
    f)  TEMPDIR=${OPTARG}
        ;;
    o)  OUTDIR=${OPTARG}
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
    echo "Missing -o option for output directory"
    usage
    exit 1
fi

# Create temporary directory if necessary
if [ ${TEMPDIR} = 'none' ]; then
    TEMPDIR=`mktemp -d`
    cd `dirname $0`
    if [ ${DEBUG} -eq 1 ]; then
        echo "Saving temporary files to ${TEMPDIR}"
    fi
fi

# First, create the vector cost layers and od_points
if [ ${SKIPVECTOR} -eq 0 ]; then
    psql -h "${DBHOST}" -U "${DBUSER}" -d "${DBNAME}" \
        -v db_srid="${DBSRID}" \
        -f bike_fac_costs.sql
    psql -h "${DBHOST}" -U "${DBUSER}" -d "${DBNAME}" \
        -v db_srid="${DBSRID}" \
        -f od_points.sql
fi

# Rasterize
echo "Rasterizing existing facilities"
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
    "${TEMPDIR}/cost_exist.tif" &

echo "Rasterizing planned facilities"
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
    -l "generated"."bike_fac_costs_plan" \
    "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
    "${TEMPDIR}/cost_plan.tif" &

echo "Rasterizing local roads"
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
    -l "generated"."bike_fac_costs_locals" \
    "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
    "${TEMPDIR}/cost_locals.tif" &

wait

# Combine costs
echo "Creating composite cost layer"
gdal_calc.py \
    --calc "numpy.fmin(numpy.fmin(A,B),C)" \
    --format GTiff \
    --type UInt16 \
    -A "${TEMPDIR}/cost_exist.tif" --A_band 1 \
    -B "${TEMPDIR}/cost_plan.tif" --B_band 1 \
    -C "${TEMPDIR}/cost_locals.tif" --C_band 1 \
    --outfile "${TEMPDIR}/cost_composite.tif"

# Create least-distance cost matrix for each point
# first, we need to grab the data from the OD points
IFS=' ' read -r -a XVALS <<< `psql -d twin_cities_barriers -h 192.168.22.220 -U gis -c "SELECT ST_X(geom) FROM od_points ORDER BY id" -t`
IFS=' ' read -r -a YVALS <<< `psql -d twin_cities_barriers -h 192.168.22.220 -U gis -c "SELECT ST_Y(geom) FROM od_points ORDER BY id" -t`
IFS=' ' read -r -a TRACTIDS <<< `psql -d twin_cities_barriers -h 192.168.22.220 -U gis -c "SELECT geoid FROM od_points ORDER BY id" -t`

for index in "${!XVALS[@]}"
do
    if [ ! -e "${TEMPDIR}/${TRACTIDS[index]}.tif" ] || [ ${OVERWRITE} -eq 1 ]; then
        echo "Creating ${TEMPDIR}/${TRACTIDS[index]}.tif"
        python cost.py \
            -i "${TEMPDIR}/cost_composite.tif" \
            -o "${TEMPDIR}/${TRACTIDS[index]}.tif" \
            -x "${XVALS[index]}" \
            -y "${YVALS[index]}" &
    else
        echo "Found ${TEMPDIR}/${TRACTIDS[index]}.tif -> skipping"
    fi

    echo "$index ${array[index]}"
done

wait

# Delete temp dir
if [ ${DEBUG} -ne 1 ]; then
    rm -rf "${TEMPDIR}"
fi
