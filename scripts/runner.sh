#!/bin/bash


function run_provisioner() {
    executable="$1"

    if [[ ${executable} == "terraform" ]]; then
        sleep 1

        terraform plan -out=plan.out
        

        sleep 1

    elif [[ ${executable} == "ansible" ]]; then
        ansible

    fi
}