# The script takes output values from terraform;
# and creates an ansible inventory
import subprocess, json
import os.path
from sys import argv
from jinja2 import Environment


tfstate_file = '.'
project_dir = os.path.dirname(os.path.abspath(argv[0]))
inventory_template = '../ansible/inventory.ini.j2'
inventory_file = '../inventory.ini'



def open_template(path):
    with open(path, 'r') as buffer:
        return buffer.read()

def apply_j2(template, vars={}):
    env = Environment(lstrip_blocks=True)

    template = env.from_string(template)
    template = template.render(vars)
        
    return template


if not os.path.exists(tfstate_file):
    print(' > Error: No terraform state file found in current dir')

    exit(1)

try:
    with_ssh = True if argv[1] == 'true' else False

except:
    print('Usage: {} <true/false> - whether to include path to your private ssh key in the inventories'.format(argv[0]))

    exit(1)

try:
    terraform_cmd = 'terraform output -json {}'
    data = {
        'CREATE_SSH': with_ssh,
        'KEY_FILE': '{}/../wp-aws-ssh-private'.format(project_dir)
    }

    os.chdir('{}/../terraform'.format(project_dir))

    for item in ['web_instances', 'db_instance']:
        data[item] = json.loads(
            subprocess.check_output(terraform_cmd.format(item).split())
        )

except:
    print(' > Error: Failed to read necessary terraform output')
    exit(1)

source_template = open_template(inventory_template)
ini_inventory = apply_j2(source_template, data)

with open(inventory_file, 'w') as buffer:
    buffer.write(ini_inventory)