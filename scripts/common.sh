#!/bin/bash


PYTHON_VERSION=3
PYTHON_BIN="$(which python${PYTHON_VERSION})"

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
    ${PYTHON_BIN} ./scripts/parser.py parse_vars --hide-output
    
    [[ $? != 0 ]] && remove_venv rm_build_dir && \
    exit 1
    
    CMD_ARGS="$(${PYTHON_BIN} ./scripts/parser.py parse_vars)"
   
    SET_ENVS="$(echo ${CMD_ARGS} | jq -r '.env')"
    TERRAFORM_CMD_ARGS="$(echo ${CMD_ARGS} | jq -r '.terraform')"
    ANSIBLE_CMD_ARGS="$(echo ${CMD_ARGS} | jq -r '.ansible')"
   
    eval "${SET_ENVS}"

    [[ $TERRAFORM_CMD_ARGS =~ .*(ssh_key=\"?create\"?).* ]] && CREATE_SSH=true || CREATE_SSH=false
    log "OK, i have everything i need!\n" 0
}

function create_build_dir() {
    log "Creating ${BUILD_DIR}.."
    mkdir -p ${BUILD_DIR}
    cd ${BUILD_DIR}
    
    cp -R ${SCRIPT_DIR}/* .
    rm -Rf ./.gitignore ./run.sh

    DESTRUCT_FILE="${BUILD_DIR}/destroy.sh"

    echo "#!/bin/bash" > ${DESTRUCT_FILE}
    echo "source ${BUILD_DIR}/scripts/common.sh" >> ${DESTRUCT_FILE}
    echo "cd ${BUILD_DIR} && destruct" >> ${DESTRUCT_FILE}

    chmod +x ${DESTRUCT_FILE}
}

function create_venv() {
    function verify_module() {
        ${PYTHON_BIN} -c "import $1" &> /dev/null

        if [[ $? != 0 ]]; then
            log "Installing $1.." 0
            sudo apt-get install python${PYTHON_VERSION}-$1 -y &> /dev/null
        fi

        [[ $? != 0 ]] && \
        log "Installation failed; please, install python3-venv manually and try again" 1
        rm -Rf ./venv
    }

    REQUIRED_MODULES=(venv pip)

    for MD in ${REQUIRED_MODULES[@]}; do
        verify_module ${MD}
    done

    # Start virtual environment after ensuring above modules;
    log "Creating virtual environment.."
    ${PYTHON_BIN} -m venv venv && source ./venv/bin/activate

    [[ $? != 0 ]] && log "Could not create a python3 virtual environment!" 1
    VENV=true

    # Ensure required package for the parser;
    ${PYTHON_BIN} -m pip install --upgrade pyyaml &> /dev/null
}

function remove_venv() {
    log "Destroying virtual environment.."
    deactivate
    
    VENV=false
    [[ "$1" == rm_build_dir ]] && rm -Rf ${BUILD_DIR}
}

function install_requirements() {
    VENV_PKGS="ansible boto3 botocore jinja2"

    log "Verifying requirements.."
    ${PYTHON_BIN} -m pip install --upgrade ${VENV_PKGS} &> /dev/null

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
    NEW_SSH_KEY_FILE="${BUILD_DIR}/wp-aws-ssh-private"
    
    echo "$NEW_SSH_KEY" > ${NEW_SSH_KEY_FILE}
    chmod 600 ${NEW_SSH_KEY_FILE}
}

function provision() {
    TERRAFORM_PLAN_CMD="terraform plan -out=tfplan -input=false -no-color ${TERRAFORM_CMD_ARGS}"

    cd ${BUILD_DIR}/terraform
    log "Provisioning infrastructure.."

    log "Initializing terraform modules.." 0
    terraform init -input=false -no-color > /dev/null

    [[ $? != 0 ]] && log "Could not initialize terraform modules!" 1

    # Provision terraform resources with internet access for MariaDB;
    log "Creating ${BUILD_DIR}/terraform/tfplan.." 0
    bash -c "${TERRAFORM_PLAN_CMD} -var enable_db_internet_access=true" > /dev/null
    [[ $? != 0 ]] && log "Could not create terraform plan!" 1

    log "Creating AWS infrastructure..\n" 0

    bash -c 'terraform apply -input=false -no-color -auto-approve tfplan'
    [[ $? != 0 ]] && log "Could not create AWS infrastructure!" 1

    [[ ${CREATE_SSH} == true ]] && create_ssh_file
    log "Done!\n" 0
    
    # Render ansible inventory.yml.j2 with addresses;
    # and key locations;
    log "Creating ansible inventory.." 0
    ${PYTHON_BIN} ${BUILD_DIR}/scripts/create_inventory.py ${CREATE_SSH}

    [[ $? != 0 ]] && log "Could not create ansible inventory!" 1
    
    DNS_LOAD_BALANCER=$(terraform output -raw dns_load_balancer)
    WEB_PRIVATE_IPS=$(terraform output -json web_instances | jq -r '.[].private_ip')
    DB_PRIVATE_IP=$(terraform output -json db_instance | jq -r '.private_ip')

    ANSIBLE_CMD_ARGS="-i ../inventory.ini ${ANSIBLE_CMD_ARGS} -e 'hostname=\"${DNS_LOAD_BALANCER}\"' -e 'web_addresses=\"${WEB_PRIVATE_IPS}\"' -e 'db_address=\"${DB_PRIVATE_IP}\"' main.yml"

    # Install apache2, php, mariadb, wordpress on EC2s;
    cd ${BUILD_DIR}/ansible
    log "Installing web server and database components..\n" 0

    VENV=false

    bash -c "ansible-playbook ${ANSIBLE_CMD_ARGS}"
    [[ $? != 0 ]] && log "Could not verify components installation in ansible!" 1
    log "Done!\n" 0

    cd ${BUILD_DIR}/terraform

    exit

    # Disable internet access for MariaDB;
    log "Updating AWS infrastructure.."
    log "Disabling network access for MariaDB..\n" 0

    bash -c "${TERRAFORM_PLAN_CMD} -var enable_db_internet_access=false" > /dev/null
    [[ $? != 0 ]] && log "Could not create terraform plan for disabling the access!" 1

    bash -c 'terraform apply -input=false -no-color -auto-approve tfplan'
    [[ $? != 0 ]] && log "Could not disable the access properly!" 1
    
    log "Done!\n" 0
}

function destruct() {
    BUILD_DIR=$(
        cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && \
        pwd
    )
    
    REQUIRED_VARS=(AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION)

    for VAR in ${REQUIRED_VARS[@]}; do
        if [[ -z ${!VAR} ]]; then
            log "${VAR}: environment variable missing - it needs to be set in order to destroy the infrastructure" && exit
        fi
    done

    cd ./terraform
    terraform destroy -auto-approve

    [[ $? != 0 ]] && log "Destruction failed! Leftovers might be still available, please verify manually" && exit

    log "Removing ${BUILD_DIR}.."
    cd ${HOME} && rm -Rf ${BUILD_DIR}

    log "Done!\n" 0
}

function show_outputs() {
    function render_instance_data() {
        if [[ $1 == db ]]; then
            data=${DB_INSTANCE}
            node_ssh_line="[DISABLED] DB access only"

        else
            data=$(echo ${INSTANCES} | jq -r ".[${1}]")
            node_ssh_line="ssh -i ${SSH_FILE} ubuntu@$(echo $data | jq -r '.public_ip')"

        fi

        node_name="$(echo ${data} | jq -r '.tags.Name' | tr '[:upper:]' '[:lower:]')"
        node_az="$(echo $data | jq -r '.availability_zone')"
        node_public_ip="$(echo $data | jq -r '.public_ip')"

        log "${node_name}: ${node_ssh_line}" 0
        log "availability zone: ${node_az}" 0
        log "public address: ${node_public_ip}\n" 0
    }

    DB_INSTANCE="$(terraform output -json db_instance)"
    INSTANCES="$(terraform output -json web_instances)"
    INSTANCES_COUNT="$(echo ${INSTANCES} | jq -r '. | length')"
    
    [[ ${CREATE_SSH} == true ]] && SSH_FILE="${NEW_SSH_KEY_FILE}" || \
    SSH_FILE="${HOME}/.ssh/id_rsa"

    log "Completed!"
    log "Destroy everything with /home/skull/.wp-aws/3600/destroy.sh;" 0
    log "Load Balanced URL: http://${DNS_LOAD_BALANCER};\n" 0

    if [[ ${CREATE_SSH} == true ]]; then
        log "You did not provide a public key, so a new private key was;" 0
        log "generated for you - ${NEW_SSH_KEY_FILE}\n" 0

    else
        log "Make sure your ${HOME}/.ssh/id_rsa exists if you SSH;\n" 0

    fi

    log "Provisioned instances:"
    for i in $(seq 0 $((${INSTANCES_COUNT} - 1))); do
        data=$(echo ${INSTANCES} | jq -r ".[${i}]")

        render_instance_data ${i}
    done

    render_instance_data db
}