#!/bin/bash

#############################################################
## Processing instructions for the Twin Cities Barrier
## Analysis study
#############################################################


cd `dirname $0`

# Vars
DBHOST="${DBHOST:-192.168.22.220}"
DBUSER="${DBUSER:-gis}"
DBNAME="${DBNAME:-twin_cities_barriers}"
DBSRID="${DBSRID:-26915}"

# First, set up the cost layers
psql -h "${DBHOST}" -U "${DBUSER}" -d "${DBNAME}" \
    -v db_srid="${DBSRID}"
    -f bike_fac_costs.sql

# Rasterize
