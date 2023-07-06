#!/bin/bash

source ${SCRIPT_DIR}/scripts/runner.sh


TERRAFORM_VERSION=1.5.2
TERRAFORM_URL=https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
TERRAFORM_GPG=/usr/share/keyrings/hashicorp-archive-keyring.gpg
TERRAFORM_REPO_LIST=/etc/apt/sources.list.d/hashicorp.list

BUILD_ID=$(shuf -i 1000-$(shuf -i 10-10000 -n 1) -n 1)
BUILD_DIR="${HOME}/.wp-aws/${BUILD_ID}"
IF_OLD_DIR="${HOME}/.wp-aws/$(cat ${SCRIPT_DIR}/.last_build)"


function log() {
    if [[ $2 == 0 ]]; then
        echo "   $1"
    
    elif [[ $2 == 1 ]]; then
        echo " ! Error => $1"
        [[ $VENV == true ]] && remove_venv
        exit 1
    
    else
        echo " > $1"
    fi
}

function create_build_dir() {
    if [[ -f "${SCRIPT_DIR}/.last_build" ]]; then
        log "Previous build detected; do you want to remove its directory?"
        log "=> ${IF_OLD_DIR}" 0
        read -p "   Confirm with y:" -e -s -t 6 -n 1 -r will_remove_dir
        
        case $will_remove_dir in
            [yY])
                log "Removing previous build directory.." 0
                rm -Rf ${IF_OLD_DIR}
                ;;
            *)
                log "Leaving untouched.." 0
                ;;
        esac
    fi

    log "Creating ${BUILD_DIR}.."
    mkdir -p ${BUILD_DIR}
    cd ${BUILD_DIR}
    
    echo ${BUILD_ID} > ${SCRIPT_DIR}/.last_build
}

function install_requirements() {
    log "Initializing.."

    pip3 -v > /dev/null

    [[ $? != 0 ]] && \
    log "Seems like something is wrong with pip3; please, reinstall it manually and try again" 1

    python3 -m venv venv && source venv/bin/activate

    if [[ $? != 0 ]]; then
        log "Installing python3-venv.." 0

        sudo apt-get update > /dev/null
        sudo apt-get install python3-venv -y > /dev/null

        [[ $? != 0 ]] && \
        log "Installation failed; please, install python3-venv manually and try again" 1
    
    else
        deactivate > /dev/null 2>&1
    fi

    terraform -v > /dev/null

    if [[ $? != 0 ]]; then
        log "Installing terraform.." 0

        sudo rm -Rf ${TERRAFORM_GPG}
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o "$TERRAFORM_GPG"
        echo "deb [signed-by=${TERRAFORM_GPG}] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee ${TERRAFORM_REPO_LIST}
        sudo apt-get update > /dev/null
        sudo apt install terraform -y > /dev/null

        [[ $? != 0 ]] && \
        log "Installation failed; please, install terraform manually and try again" 1
    fi
}

function create_venv() {
    VENV_PKGS="ansible boto3 botocore"

    log "Creating virtual environment.."
    python3 -m venv ${BUILD_DIR}/venv && source venv/bin/activate

    [[ $? != 0 ]] && log "Could not create a python3 virtual environment!" 1
    VENV=true

    if [[ ! $(ansible --version) ]]; then
        log "Installing ansible.." 0
        python3 -m pip install --upgrade ${VENV_PKGS} > /dev/null
    fi
}

function provision() {
    python3 -m pip
    log "Provisioning with Terraform.."
}

function remove_venv() {
    log "Destroying virtual environment.."
    deactivate && rm -Rf ${BUILD_DIR}/venv
    
    VENV=false
}