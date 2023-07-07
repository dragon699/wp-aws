#!/bin/bash


TERRAFORM_VERSION=1.5.2
TERRAFORM_URL=https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
TERRAFORM_GPG=/usr/share/keyrings/hashicorp-archive-keyring.gpg
TERRAFORM_REPO_LIST=/etc/apt/sources.list.d/hashicorp.list

BUILD_ID=$(shuf -i 1000-$(shuf -i 1000-10000 -n 1) -n 1)
BUILD_DIR="${HOME}/.wp-aws/${BUILD_ID}"


function log() {
    if [[ $2 == 0 ]]; then
        echo -e "   $1"
    
    elif [[ $2 == 1 ]]; then
        echo -e " ! Error => $1"

        [[ $VENV == true ]] && remove_venv
        exit 1
    
    else
        echo -e " > $1"
    fi
}

# Takes every defined variable in vars.yml and
# creates a terraform command args string
function parse_vars() {
    log "Validating vars.yml.."

    CMD_ARGS=$(python3 ./scripts/parser.py)
    [[ $? != 0 ]] && log "${CMD_ARGS}" 1

    TERRAFORM_CMD_ARGS=$(echo ${CMD_ARGS} | jq -r '.terraform')
    ANSIBLE_CMD_ARGS=$(echo ${CMD_ARGS} | jq -r '.ansible')
    
    [[ $TERRAFORM_CMD_ARGS =~ .*(ssh_key=\"?create\"?).* ]] && CREATE_SSH=true
    log "OK, i have everything i need!\n" 0
}

function create_build_dir() {
    log "Creating ${BUILD_DIR}.."
    mkdir -p ${BUILD_DIR}
    cd ${BUILD_DIR}
    
    cp -R ${SCRIPT_DIR}/* .
    rm -Rf ./.gitignore
}

function create_venv() {
    python3 -m venv venv && source venv/bin/activate

    if [[ $? != 0 ]]; then
        log "Installing python3-venv.." 0

        sudo apt-get update > /dev/null
        sudo apt-get install jq python3-venv -y > /dev/null

        [[ $? != 0 ]] && \
        log "Installation failed; please, install python3-venv manually and try again" 1
    
    else
        deactivate > /dev/null 2>&1
    fi

    log "Creating virtual environment.."
    python3 -m venv venv && source ./venv/bin/activate

    [[ $? != 0 ]] && log "Could not create a python3 virtual environment!" 1
    VENV=true
}

function install_requirements() {
    VENV_PKGS="ansible boto3 botocore pyyaml jinja2"

    log "Verifying requirements.."
    python3 -m pip install ${VENV_PKGS} > /dev/null

    [[ $? != 0 ]] && \
    log "Seems like something is wrong with pip3; please, reinstall it manually and try again" 1

    terraform -v > /dev/null

    if [[ $? != 0 ]]; then
        log "Installing terraform.." 0

        sudo rm -Rf ${TERRAFORM_GPG}
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o "$TERRAFORM_GPG"
        echo "deb [signed-by=${TERRAFORM_GPG}] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee ${TERRAFORM_REPO_LIST}
        sudo apt-get update > /dev/null
        sudo apt install jq terraform -y > /dev/null

        [[ $? != 0 ]] && \
        log "Installation failed; please, install terraform manually and try again" 1
    fi
}

function get_new_ssh_from_terraform() {
    NEW_SSH_KEY="$(terraform output -json private_key | jq -r '.[0].private_key_openssh')"
    
    echo "$NEW_SSH_KEY" > ${BUILD_DIR}/wp-aws-ssh-private
    chmod 600 ${BUILD_DIR}/wp-aws-ssh-private
}

function remove_venv() {
    log "Destroying virtual environment.."
    deactivate && rm -Rf ${BUILD_DIR}/venv
    
    VENV=false
}

function provision() {
    cd ${BUILD_DIR}/terraform
    log "Provisioning Infrastructure.."

    log "Initializing terraform modules.." 0
    terraform init -input=false -no-color > /dev/null

    [[ $? != 0 ]] && log "Could not initialize terraform modules!" 1

    log "Creating ${BUILD_DIR}/terraform/tfplan.." 0
    bash -c "terraform plan -out=tfplan -input=false -no-color ${TERRAFORM_CMD_ARGS}" > /dev/null

    [[ $? != 0 ]] && log "Could not create terraform plan!" 1

    log "Creating AWS infrastructure..\n" 0
    sleep 2

    bash -c 'terraform apply -input=false -no-color -auto-approve tfplan'
    [[ $? != 0 ]] && log "Could not create AWS infrastructure!" 1

    [[ ${CREATE_SSH} == true ]] && get_new_ssh_from_terraform
    log "Done!\n" 0
    
    log "Creating ansible inventory.."
    python3 ${BUILD_DIR}/scripts/create_inventory.py true

    [[ $? != 0 ]] && log "Could not create ansible inventory!" 1

    DNS_LOAD_BALANCER=$(terraform output -raw dns_load_balancer)
    ANSIBLE_CMD_ARGS="-i ../inventory.ini ${ANSIBLE_CMD_ARGS} -e hostname='${DNS_LOAD_BALANCER}' main.yml"

    log "Installing required components.."
    cd ${BUILD_DIR}/ansible

    echo " ################################### "
    echo " ################################### "
    echo ${ANSIBLE_CMD_ARGS}
    echo " ################################### "
    echo " ################################### "

    bash -c "ansible-playbook ${ANSIBLE_CMD_ARGS}"
    [[ $? != 0 ]] && log "Could not verify components installation in ansible!" 1

    log "Done!\n" 0
}