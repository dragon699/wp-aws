#!/bin/bash


DB=${1-"wordpress"}
LOG_FILE=${2-"/var/log/db_optimization.log"}

QUERIES=(
    # Get table names;
    "SHOW TABLES;"

    # Get table names and sizes;
    # Unit: MB
    "SELECT table_name, round(((data_length + index_length) / 1024 / 1024), 2) FROM information_schema.TABLES WHERE table_schema = '${DB}';"

    # Optimize a table;
    "OPTIMIZE TABLE"
)

echo "----> $DB $LOG_FILE"
function run_query() {
    mariadb -D ${DB} -s -e \"${1}\"
}

function log() {
    echo -e " > $1" | tee -a ${LOG_FILE}
}

function optimize_tables() {
    TABLE_NAMES=$(run_query "${QUERIES[0]}")

    for t in ${TABLE_NAMES}; do
        run_query "${QUERIES[2]} ${t};" > /dev/null
    done
}


function run() {
    log "Optimizing ${DB}'s tables.."

    ORIGINAL_SIZE=$(run_query "${QUERIES[1]}" | tail +2)    
    optimize_tables
    RESULTED_SIZE=$(run_query "${QUERIES[1]}" | tail +2)

    log "Optimization completed!\n"

    show_output
}

function show_output() {
    log: "Comparsion:\n"

    log "\t\tTable\t\t|\t\t[MB] Size before\t\t|\t\t[MB] Size after\t\t"
    
    for t in ${TABLE_NAMES}; do
        ORIGINAL_SIZE=$(echo ${ORIGINAL_SIZE} | grep ${t} | awk '{print $2}')
        RESULTED_SIZE=$(echo ${RESULTED_SIZE} | grep ${t} | awk '{print $2}')

        log "\t\t${t}\t\t|\t\t${ORIGINAL_SIZE}\t\t|\t\t${RESULTED_SIZE}\t\t"
    done
}

run