from sys import argv
import os, yaml, json


ENV_ONLY_VARS = ['aws_access_key_id', 'aws_secret_access_key']

SCRIPT_ROOT_DIR = '{}/../'.format(os.path.dirname(os.path.realpath(__file__)))
CONFIG_VARS_FILE = '{}/config/config_vars.yml'.format(SCRIPT_ROOT_DIR)
USER_VARS_FILE = '{}/vars.yml'.format(SCRIPT_ROOT_DIR)
DOCS_VARS_FILE = '{}/README.md'.format(SCRIPT_ROOT_DIR)


def log(msg, cut=False):
    if cut:
        print('   {}'.format(msg))

    else:
        print(' > {}'.format(msg))

def read_yaml(file_path):
    with open(file_path, 'r') as buffer:
        return yaml.load(buffer, Loader = yaml.FullLoader)
    
def get_dict_item(item, k, v):
    for i in item:
        if i.get(k) == v:
            return i


class VarsGenerator:
    def __init__(self):
        self.config_data = read_yaml(CONFIG_VARS_FILE)

    def generate_vars_file(self):
        log('Generating variables file..')

        user_data = [
            '# This file is auto-generated by parser.py;\n',
            '# and can be safely re-created anytime;\n',
            '# with python3 ./parser.py generate_docs;\n\n'
            '# To use this file, simply override the variables you want;\n',
            '# and run ./run.sh in the same directory;\n',
            '# Many of the variables could be used as env variables;\n',
            '# Refer to config/config_vars.yml for complete details for each var;\n\n'
            '# After completion, a new copy of the file will be generated;\n\n\n'
        ]

        for var in self.config_data:
            desc_lines = []

            for line in var['description'].split('\n'):
                desc_lines += ['# {}'.format(line), '\n']

            commented_description = ''.join(desc_lines)[:-1]
            var_item = '{}\n{}: '.format(commented_description, var['name'])

            if 'default' in var:
                var_item += '{}\n\n'.format(var['default'])
            
            else:
                var_item += '\n\n'

            user_data += [var_item]

        with open(USER_VARS_FILE, 'w') as buffer:
            buffer.writelines(user_data)

        log('Done', True)


class VarsParser:
    def __init__(self):
        self.script_dir = SCRIPT_ROOT_DIR
        self.params_out = {'ansible': '', 'terraform': ''}
        self.prefixes = {'ansible': '-e', 'terraform': '-var'}
        self.read_vars_files()

    def read_vars_files(self):
        self.config_data = read_yaml(CONFIG_VARS_FILE)

        try:
            self.user_data = read_yaml(USER_VARS_FILE)

        except:
            log('{}: Opps, looks like there is a mistake in the vars file!'.format(USER_VARS_FILE))
            log("Please, make sure it is declared in a valid YAML format", True)
            log("Alternatively, run python3 ./scripts/parser.py generate_docs to generate a new copy of the vars file", True)

            exit(1)

    def parse(self):
        doc_vars = [var['name'] for var in self.config_data]

        for var in self.user_data:
            if not var in doc_vars:
                log('{}: unrecognized variable, skipping..'.format(var), True)
                continue

            var_value = None
            var_doc_data = get_dict_item(self.config_data, 'name', var)

            if 'default' in var_doc_data:
                var_value = var_doc_data['default']

            if ('environment' in var_doc_data) and (os.environ.get(var_doc_data['environment'])):
                var_value = os.environ.get(var_doc_data['environment'])

            if self.user_data[var]:
                var_value = self.user_data[var]

            if not var_value:
                if ('required' in var_doc_data) and (var_doc_data['required']):
                    log('{}: required variable not provided!'.format(var), True)
                    log('Please, make sure to provide below variable in your vars.yml file:\n', True)
                    
                    print(json.dumps(var_doc_data, indent=4))
                    exit(1)
                
                else:
                    log('{}: variable value not provided, skipping..'.format(var), True)
                    continue

            else:
                if var in ENV_ONLY_VARS:
                    continue

            var_value = json.dumps(var_value)

            if var_value.startswith('[') and var_value.endswith(']'):
                var_value = "'{}'".format(var_value)

            for tag in var_doc_data['tags']:
                dest_var = tag.split('/')[1]

                for prefix in self.prefixes:
                    if tag.startswith(prefix):
                        self.params_out[prefix] += '{} {}={} '.format(self.prefixes[prefix], dest_var, var_value)

                    
if __name__ == '__main__':
    if len(argv) > 1 and (argv[1] == 'generate_docs'):
        generator = VarsGenerator()
        generator.generate_vars_file()

    else:
        try:
            parser = VarsParser()

        except:
            log('Usage: python3 ./parser.py parse_vars')
            log(' => Transforms parameters from the vars.yml file to terraform/ansible CLI args', True)
            log('Second-scenario Usage: python3 ./parser.py generate_docs', True)
            log(' => Updates README.md and generates the vars file, sourced from {}'.format(CONFIG_VARS_FILE), True)
            exit(1)

        parser.parse()

        if (len(argv) > 2) and (argv[2] == '--hide-output'):
            exit(0)

        print(json.dumps(parser.params_out))
        exit(0)