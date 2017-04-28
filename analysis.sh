#!/bin/bash

#############################################################
## Processing instructions for the Twin Cities Barrier
## Analysis study
#############################################################

cd "$(dirname "$0")"

if [ -e ./project_setup.sh ]; then
    source ./project_setup.sh
fi

# Set up
DEBUG="${DEBUG:-0}"
DBHOST="${DBHOST:-localhost}"
DBUSER="${DBUSER:-gis}"
DBPASS="${DBPASS:-gis}"
PGPASSWORD="${DBPASS}"
DBNAME="${DBNAME:-none}"
DBSRID="${DBSRID:-4326}"
DBWHERE="${DBWHERE:-none}"
SKIPVECTOR="${SKIPVECTOR:-0}"
SKIPCOST="${SKIPCOST:-0}"
SKIPRASTER="${SKIPRASTER:-0}"
TEMPDIR="${TEMPDIR:-none}"
OVERWRITE="${OVERWRITE:-0}"

# Analysis inputs
BARRIERDIST="${BARRIERDIST:-300}"
TESTLINELENGTH="${TESTLINELENGTH:-300}"
ROUTESEARCHDIST="${ROUTESEARCHDIST:-1000}"

function usage() {
    echo -n \
"
Usage: $(basename "$0") [options]

Run the Twin Cities Barriers analysis

Additional arguments are:

-h - Display this help
-v - Skip re-creation of the vector files in the database
-r - Skip raster file creation
-c - Skip the cost portion of the analysis
-d [folder location] - Run in debug mode (doesn't delete temporary files)
-w - Overwrite any existing files
-s [filter statement] - SQL where clause to filter barrier test features (given without WHERE)

Optional ENV vars:

DBHOST - Default: localhost
DBUSER - Default: gis
DBPASS - Default: gis
DBNAME - Default: none
DBSRID - Default: 4326

"
}

# Parse the command line options
while getopts "h?c?v?r?d:?s:?w?" opt; do
    case "$opt" in
    h)  usage
        exit 0
        ;;
    c)  SKIPCOST=1
        ;;
    v)  SKIPVECTOR=1
        ;;
    r)  SKIPRASTER=1
        ;;
    d)  DEBUG=1
        TEMPDIR=${OPTARG}
        ;;
    s)  DBWHERE=${OPTARG}
        ;;
    w)  OVERWRITE=1
        ;;
    \?)
        usage
        exit 1
        ;;
    :)
        echo "Option -$opt requires an argument"
        exit 1
    esac
done

# Create temporary directory if necessary
if [ ${TEMPDIR} = 'none' ]; then
    TEMPDIR=`mktemp -d`
    cd `dirname $0`
    if [ ${DEBUG} -eq 1 ]; then
        echo "Saving temporary files to ${TEMPDIR}"
    fi
fi

# Create the vector cost layers
if [ ${SKIPVECTOR} -eq 0 ]; then
    echo "Running bike_fact_costs.sql"
    psql -h "${DBHOST}" -U "${DBUSER}" -d "${DBNAME}" \
        -v db_srid="${DBSRID}" \
        -f sql/bike_fac_costs.sql
    echo "Running barriers.sql"
    psql -h "${DBHOST}" -U "${DBUSER}" -d "${DBNAME}" \
        -v db_srid="${DBSRID}" \
        -f sql/barriers.sql
fi

# Rasterize
if [ ${SKIPRASTER} -eq 0 ]; then
    if [ ! -e "${TEMPDIR}/cost_exist.tif" ] || [ ${OVERWRITE} -eq 1 ]; then
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
            -init 100000 \
            -te 419967.47 4924223.79 521254.70 5029129.99 \
            -l "automated"."bike_fac_costs_exist" \
            "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
            "${TEMPDIR}/cost_exist.tif" &
        OVERWRITE=1     # ensure new dataset cascades through
    else
        echo "${TEMPDIR}/cost_exist.tif -> skipping"
    fi

    if [ ! -e "${TEMPDIR}/cost_plan.tif" ] || [ ${OVERWRITE} -eq 1 ]; then
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
            -init 100000 \
            -te 419967.47 4924223.79 521254.70 5029129.99 \
            -l "automated"."bike_fac_costs_plan" \
            "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
            "${TEMPDIR}/cost_plan.tif" &
        OVERWRITE=1     # ensure new dataset cascades through
    else
        echo "${TEMPDIR}/cost_plan.tif -> skipping"
    fi

    if [ ! -e "${TEMPDIR}/cost_locals.tif" ] || [ ${OVERWRITE} -eq 1 ]; then
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
            -init 100000 \
            -te 419967.47 4924223.79 521254.70 5029129.99 \
            -l "automated"."bike_fac_costs_locals" \
            "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
            "${TEMPDIR}/cost_locals.tif" &
        OVERWRITE=1     # ensure new dataset cascades through
    else
        echo "${TEMPDIR}/cost_locals.tif -> skipping"
    fi

    if [ ! -e "${TEMPDIR}/cost_expys.tif" ] || [ ${OVERWRITE} -eq 1 ]; then
        echo "Rasterizing expressways"
        gdal_rasterize \
            -a cell_cost \
            -ot UInt16 \
            -tr 30 30 \
            -a_nodata 9999 \
            -co COMPRESS=DEFLATE \
            -co PREDICTOR=1 \
            -co ZLEVEL=6 \
            -at \
            -init 0 \
            -te 419967.47 4924223.79 521254.70 5029129.99 \
            -l "automated"."bike_fac_costs_expys" \
            "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
            "${TEMPDIR}/cost_expys.tif" &
        OVERWRITE=1     # ensure new dataset cascades through
    else
        echo "${TEMPDIR}/cost_expys.tif -> skipping"
    fi

    if [ ! -e "${TEMPDIR}/cost_rails.tif" ] || [ ${OVERWRITE} -eq 1 ]; then
        echo "Rasterizing railroads"
        gdal_rasterize \
            -a cell_cost \
            -ot UInt16 \
            -tr 30 30 \
            -a_nodata 9999 \
            -co COMPRESS=DEFLATE \
            -co PREDICTOR=1 \
            -co ZLEVEL=6 \
            -at \
            -init 0 \
            -te 419967.47 4924223.79 521254.70 5029129.99 \
            -l "automated"."bike_fac_costs_rails" \
            "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
            "${TEMPDIR}/cost_rails.tif" &
        OVERWRITE=1     # ensure new dataset cascades through
    else
        echo "${TEMPDIR}/cost_rails.tif -> skipping"
    fi

    if [ ! -e "${TEMPDIR}/cost_streams.tif" ] || [ ${OVERWRITE} -eq 1 ]; then
        echo "Rasterizing streams"
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
            -l "automated"."bike_fac_costs_streams" \
            "PG:dbname='${DBNAME}' host='${DBHOST}' port=5432 user='${DBUSER}' password='${DBPASS}' sslmode=disable" \
            "${TEMPDIR}/cost_streams.tif" &
        OVERWRITE=1     # ensure new dataset cascades through
    else
        echo "${TEMPDIR}/cost_streams.tif -> skipping"
    fi

    wait

    # Combine costs
    if [ ! -e "${TEMPDIR}/cost_composite.tif" ] || [ ${OVERWRITE} -eq 1 ]; then
        echo "Creating composite cost layer"
        gdal_calc.py \
            --calc "numpy.fmin(numpy.fmax(numpy.fmax(numpy.fmin(numpy.fmin(B,C),D),F),E),A)" \
            --format GTiff \
            --type UInt16 \
            -A "${TEMPDIR}/cost_exist.tif" --A_band 1 \
            -B "${TEMPDIR}/cost_plan.tif" --B_band 1 \
            -C "${TEMPDIR}/cost_locals.tif" --C_band 1 \
            -D "${TEMPDIR}/cost_streams.tif" --D_band 1 \
            -E "${TEMPDIR}/cost_expys.tif" --E_band 1 \
            -F "${TEMPDIR}/cost_rails.tif" --F_band 1 \
            --outfile "${TEMPDIR}/cost_composite.tif"
        OVERWRITE=1     # ensure new dataset cascades through
    else
        echo "${TEMPDIR}/cost_composite.tif -> skipping"
    fi
fi

# Polygonize the cost results
if [ ${SKIPVECTOR} -eq 0 ]; then
    echo 'Making polygons from barriers with polygonize.sh'
    bash sh/polygonize.sh \
        -s automated \
        -t barrier_polys \
        -l 11110 \
        "${TEMPDIR}/cost_composite.tif"
fi

# Generate lines from the polygons
if [ ${SKIPVECTOR} -eq 0 ]; then
    echo 'Running barrier_lines.sql'
    psql \
        -h ${DBHOST} \
        -d ${DBNAME} \
        -U ${DBUSER} \
        -v db_srid=${DBSRID} \
        -f sql/barrier_lines.sql
fi

# Create test locations
if [ ${SKIPVECTOR} -eq 0 ]; then
    echo 'Running barrier_deviation_test_lines.sql'
    psql \
        -h ${DBHOST} \
        -d ${DBNAME} \
        -U ${DBUSER} \
        -v db_srid=${DBSRID} \
        -v max_dist=${BARRIERDIST} \
        -v line_len=${TESTLINELENGTH} \
        -f sql/barrier_deviation_test_lines.sql
fi

# Update the least cost distances for all features
if [ ${SKIPCOST} -eq 0 ]; then
    echo 'Setting least cost distances for features using cost.py'
    if [ "${DBWHERE}" = 'none' ]; then
        DBQUERY="select id,st_xmin(geom),st_xmax(geom),st_ymin(geom),st_ymax(geom) from (select id, ST_Buffer(geom,1000) as geom from barrier_deviation_test_lines) a"
    else
        DBQUERY="select id,st_xmin(geom),st_xmax(geom),st_ymin(geom),st_ymax(geom) from (select id, ST_Buffer(geom,1000) as geom from barrier_deviation_test_lines WHERE ${DBWHERE}) a"
    fi
    psql \
        -h ${DBHOST} \
        -d ${DBNAME} \
        -U ${DBUSER} \
        -c "${DBQUERY}" \
        --single-transaction \
        --set AUTOCOMMIT=off \
        --set ON_ERROR_STOP=on \
        --no-align \
        -t \
        --field-separator ' ' \
        --quiet \
        | while read FID XMIN XMAX YMIN YMAX ; do
            echo "id: ${FID}"
            gdal_translate \
                -of GTiff \
                -projwin ${XMIN} ${YMAX} ${XMAX} ${YMIN} \
                "${TEMPDIR}/cost_composite.tif" \
                "${TEMPDIR}/cost_composite__${FID}.tif"

            python py/cost.py \
                -f "${TEMPDIR}/cost_composite__${FID}.tif" \
                -h ${DBHOST} \
                -d ${DBNAME} \
                -u ${DBUSER} \
                -t barrier_deviation_test_lines \
                -r 5 \
                -w "id=${FID}"

            if [ ${DEBUG} -ne 1 ]; then
                rm "${TEMPDIR}/cost_composite__${FID}.tif"
            fi
        done
fi

# Delete temp dir
if [ ${DEBUG} -ne 1 ]; then
    rm -rf "${TEMPDIR}"
fi
