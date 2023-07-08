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
        echo -e " ! $1"

        [[ $VENV == true ]] && remove_venv rm_build_dir
        exit 1
    
    else
        echo -e " > $1"
    fi
}

# Takes every defined variable in vars.yml and
# creates a terraform command args string
function parse_vars() {
    log "Validating vars.yml.."
    python3 ./scripts/parser.py parse_vars --hide-output
    
    [[ $? != 0 ]] && remove_venv rm_build_dir && \
    exit 1
    
    CMD_ARGS="$(python3 ./scripts/parser.py parse_vars)"
    
    TERRAFORM_CMD_ARGS=$(echo ${CMD_ARGS} | jq -r '.terraform')
    ANSIBLE_CMD_ARGS=$(echo ${CMD_ARGS} | jq -r '.ansible')
    
    [[ $TERRAFORM_CMD_ARGS =~ .*(ssh_key=\"?create\"?).* ]] && CREATE_SSH=true || CREATE_SSH=false
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

        sudo apt-get update &> /dev/null
        sudo apt-get install python3-venv -y &> /dev/null

        [[ $? != 0 ]] && \
        log "Installation failed; please, install python3-venv manually and try again" 1
    
    else
        deactivate > /dev/null 2>&1
    fi

    log "Creating virtual environment.."
    python3 -m venv venv && source ./venv/bin/activate
    python3 -m pip install --upgrade pyyaml &> /dev/null

    [[ $? != 0 ]] && log "Could not create a python3 virtual environment!" 1
    VENV=true
}

function install_requirements() {
    VENV_PKGS="ansible boto3 botocore jinja2"

    log "Verifying requirements.."
    python3 -m pip install --upgrade ${VENV_PKGS} &> /dev/null

    terraform -v > /dev/null

    if [[ $? != 0 ]]; then
        log "Installing terraform.." 0

        sudo rm -Rf ${TERRAFORM_GPG}
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o "$TERRAFORM_GPG"
        echo "deb [signed-by=${TERRAFORM_GPG}] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee ${TERRAFORM_REPO_LIST}
        sudo apt-get update &> /dev/null
        sudo apt install jq terraform -y &> /dev/null

        [[ $? != 0 ]] && \
        log "Installation failed; please, install terraform manually and try again" 1
    fi
}

function create_ssh_file() {
    NEW_SSH_KEY="$(terraform output -json private_key | jq -r '.[0].private_key_openssh')"
    
    echo "$NEW_SSH_KEY" > ${BUILD_DIR}/wp-aws-ssh-private
    chmod 600 ${BUILD_DIR}/wp-aws-ssh-private
}

function remove_venv() {
    log "Destroying virtual environment.."
    deactivate && rm -Rf ${BUILD_DIR}/venv
    
    VENV=false
    [[ "$1" == rm_build_dir ]] && rm -Rf ${BUILD_DIR}
}

function provision() {
    cd ${BUILD_DIR}/terraform
    log "Provisioning infrastructure.."

    log "Initializing terraform modules.." 0
    terraform init -input=false -no-color > /dev/null

    [[ $? != 0 ]] && log "Could not initialize terraform modules!" 1

    # Deploy initially with -var enable_db_internet_access=true;
    # which allows the database to be accessed from SSH and the internet;
    # necessary during initial setup;
    # and is then disabled with enable_db_internet_access set to false;
    echo ${TERRAFORM_CMD_ARGS}
    log "Creating ${BUILD_DIR}/terraform/tfplan.." 0
    bash -c "terraform plan -out=tfplan -input=false -no-color ${TERRAFORM_CMD_ARGS} -var enable_db_internet_access=true" > /dev/null

    [[ $? != 0 ]] && log "Could not create terraform plan!" 1

    log "Creating AWS infrastructure..\n" 0
    sleep 2

    bash -c 'terraform apply -input=false -no-color -auto-approve tfplan'
    [[ $? != 0 ]] && log "Could not create AWS infrastructure!" 1

    [[ ${CREATE_SSH} == true ]] && create_ssh_file
    log "Done!\n" 0
    
    log "Creating ansible inventory.." 0
    python3 ${BUILD_DIR}/scripts/create_inventory.py ${CREATE_SSH}

    [[ $? != 0 ]] && log "Could not create ansible inventory!" 1

    log "Running playbook on AWS infrastructure.." 0
    
    DNS_LOAD_BALANCER=$(terraform output -raw dns_load_balancer)
    WEB_PRIVATE_IPS=$(terraform output -json web_instances | jq -r '.[].private_ip')
    DB_PRIVATE_IP=$(terraform output -json db_instance | jq -r '.private_ip')

    ANSIBLE_CMD_EXTRA_ARGS="-e hostname='${DNS_LOAD_BALANCER}' -e web_addresses='${WEB_PRIVATE_IPS}' -e db_address='${DB_PRIVATE_IP}'"
    ANSIBLE_CMD="-i ../inventory.ini ${ANSIBLE_CMD_ARGS} ${ANSIBLE_CMD_EXTRA_ARGS} main.yml"

    cd ${BUILD_DIR}/ansible
    log "Installing web server and database components.." 0

    echo $ANSIBLE_CMD
    bash -c "ansible-playbook -v ${ANSIBLE_CMD}"
    #[[ $? != 0 ]] && log "Could not verify components installation in ansible!" 1

    log "Done!\n" 0
}
