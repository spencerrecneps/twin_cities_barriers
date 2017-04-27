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
COSTONLY="${COSTONLY:0}"
SKIPVECTOR="${SKIPEVECTOR:-0}"
TEMPDIR="${TEMPDIR:-none}"
OVERWRITE="${OVERWRITE:-0}"

# Analysis inputs
BARRIERDIST="${BARRIERDIST:-300}"
TESTLINELENGTH="${TESTLINELENGTH:-300}"
ROUTESEARCHDIST="${ROUTESEARCHDIST:-1000}"

function usage() {
    echo -n \
"
Usage: $(basename "$0") [-h] [-c] [-v] [-d] [-w] [-f <folder location>] -o <folder location>

Run the Twin Cities Barriers analysis

Additional arguments are:

-h - Display this help
-c - Only run the cost portion of the analysis
-v - Skip re-creation of the vector files in the database
-d - Run in debug mode (doesn't delete temporary files)
-w - Overwrite any existing files
-s - SQL where clause to filter barrier test features (given without WHERE)
-f - Output folder to store intermediate files (if not given a temporary folder is used)
-o - Output folder to store final files

Optional ENV vars:

DBHOST - Default: localhost
DBUSER - Default: gis
DBPASS - Default: gis
DBNAME - Default: none
DBSRID - Default: 4326

"
}

# Parse the command line options
hasO=0
while getopts "h?c?v?d?s:?f:?o:w" opt; do
    case "$opt" in
    h)  usage
        exit 0
        ;;
    c)  COSTONLY=1
        ;;
    v)  SKIPVECTOR=1
        ;;
    d)  DEBUG=1
        ;;
    s)  DBWHERE=${OPTARG}
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

# Create the vector cost layers
if [ ${SKIPVECTOR} -eq 0 -a ${COSTONLY} -eq 0 ]; then
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
if [ ${COSTONLY} -eq 0 ]; then
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
if [ ${COSTONLY} -eq 0 ]; then
    echo 'Making polygons from barriers with polygonize.sh'
    sh/polygonize.sh \
        -s automated \
        -t barrier_polys \
        -l 11110 \
        "${TEMPDIR}/cost_composite.tif"
fi

# Generate lines from the polygons
if [ ${COSTONLY} -eq 0 ]; then
    echo 'Running barrier_lines.sql'
    psql \
        -h ${DBHOST} \
        -d ${DBNAME} \
        -U ${DBUSER} \
        -v db_srid=${DBSRID} \
        -f sql/barrier_lines.sql
fi

# Create test locations
if [ ${COSTONLY} -eq 0 ]; then
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
echo 'Setting least cost distances for features using cost.py'
if [ "${DBWHERE}" = 'none' ]; then
    DBQUERY="select id from barrier_deviation_test_lines"
else
    DBQUERY="select id from barrier_deviation_test_lines where ${DBWHERE}"
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
    | while read FID ; do
        echo "id: ${FID}"
        gdalwarp \
            -of GTiff \
            -overwrite \
            -cutline "PG:host=${DBHOST} user=${DBUSER} dbname=${DBNAME}" \
            -csql "select ST_Envelope(ST_Buffer(geom,1000)) from barrier_deviation_test_lines where id=${FID}" \
            -crop_to_cutline \
            -of GTiff "${TEMPDIR}/cost_composite.tif" \
            -q \
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

# Delete temp dir
if [ ${DEBUG} -ne 1 ]; then
    rm -rf "${TEMPDIR}"
fi
