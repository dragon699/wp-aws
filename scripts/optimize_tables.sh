#!/bin/bash


TODAY=($(date | awk '{print $2,$3}'))

DB=${1-"wordpress"}
LOG_DIR=${2-"/var/lib/mysql/optimization_logs"}
LOG_FILE="${LOG_DIR}/${TODAY[0]}-${TODAY[1]}-${DB}.log"

QUERIES=(
    # Get table names;
    "SHOW TABLES;"

    # Get table names and sizes;
    # Unit: MB
    "SELECT table_name, round(((data_length + index_length) / 1024 / 1024), 2) FROM information_schema.TABLES WHERE table_schema = '${DB}';"

    # Optimize a table;
    "OPTIMIZE TABLE"
)

function run_query() {
    mariadb -D ${DB} -s -e "${1}"
}

function log() {
    echo -e "$1" | tee -a ${LOG_FILE}
}

function optimize_tables() {
    TABLE_NAMES="$(run_query "${QUERIES[0]}")"

    for t in ${TABLE_NAMES}; do
        run_query "${QUERIES[2]} ${t};" > /dev/null
    done
}


function run() {
    log "[$(date)] Optimizing ${DB}'s tables.."

    ORIGINAL_SIZE="$(run_query "${QUERIES[1]}" | tail +2)"
    optimize_tables
    RESULTED_SIZE="$(run_query "${QUERIES[1]}" | tail +2)"

    log "[$(date)] Optimization completed!\n"
    show_output
}

function show_output() {
    log "Comparsion:\n"
    log "\tTable\t\t| [MB] Size before\t\t\t| [MB] Size after"
    log "------------------------------------------------------------------------------"
    
    for t in ${TABLE_NAMES}; do
        ORIGINAL=$(echo "${ORIGINAL_SIZE}" | grep ${t} | awk '{print $2}')
        RESULTED=$(echo "${RESULTED_SIZE}" | grep ${t} | awk '{print $2}')

        log "\t${t}\t\t| ${ORIGINAL}\t\t\t| ${RESULTED}"
    done
}

run