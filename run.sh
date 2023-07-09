#!/bin/bash

SCRIPT_DIR=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && \
    pwd
)

source ${SCRIPT_DIR}/scripts/common.sh


function run_deployment() {
    create_venv
    create_build_dir
    install_requirements
    parse_vars
    provision
    show_outputs
    remove_venv
}

run_deployment