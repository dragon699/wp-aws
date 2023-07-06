#!/bin/bash

SCRIPT_DIR=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && \
    pwd
)

source ${SCRIPT_DIR}/scripts/common.sh


function run_deployment() {
    create_build_dir
    install_requirements
    create_venv

    remove_venv
}

run_deployment