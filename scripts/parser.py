from sys import argv
import os, yaml, json, re


# Values inside ENV_ONLY_VARS will be taken from vars.yaml like others;
# and converted to ENV alternatives, but will not be;
# passed to ansible/terraform CLI;
ENV_ONLY_VARS = ['aws_access_key_id', 'aws_secret_access_key']

SCRIPT_ROOT_DIR = '{}/../'.format(os.path.dirname(os.path.realpath(__file__)))
VARS_CONFIG_FILE = '{}config/vars_config.yml'.format(SCRIPT_ROOT_DIR)
USER_VARS_FILE = '{}vars.yml'.format(SCRIPT_ROOT_DIR)
DOCS_VARS_FILE = '{}README.md'.format(SCRIPT_ROOT_DIR)


def log(msg, cut=False):
    if cut:
        print('   {}'.format(msg))

    else:
        print(' > {}'.format(msg))

def read_yaml(file_path):
    with open(file_path, 'r') as buffer:
        return yaml.load(buffer, Loader = yaml.FullLoader)
    
def read_readme(file_path):
    with open(file_path, 'r') as buffer:
        return buffer.readlines()
    
def get_dict_item(item, k, v):
    for i in item:
        if i.get(k) == v:
            return i


class VarsGenerator:
    def __init__(self):
        self.config_data = read_yaml(VARS_CONFIG_FILE)
        self.docs_data = read_readme(DOCS_VARS_FILE)


    def generate_vars_file(self):
        log('Generating {} file..'.format(USER_VARS_FILE))
        user_data = [
            '# This file is auto-generated by parser.py;\n',
            '# and can be safely re-created anytime;\n',
            '# with python3 ./parser.py update_docs;\n\n'
            '# Simply override the variables you want;\n',
            '# and run ./run.sh in the same directory;\n',
            '# Many of the variables could be used as env variables;\n',
            '# Refer to config/vars_config.yml for complete details for each var;\n\n'
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


    def update_readme(self):
        log('Updating {}..'.format(DOCS_VARS_FILE))

        docs_re = r'^((####).*(Variables in (.*.yml))).*'
        docs_data = [
            '#### Variables in vars.yml',
            'This section was automatically generated by parser.py - please do not edit edit it',
            '',
            '| Name  | Description | Default value | Alternative | Consumed by |',
            '| - | - | - | - | - |'
        ]

        for var in self.config_data:
            var['name'] = '**{}**'.format(var['name'])

            if ('required' in var) and (var['required']):
                var['name'] = '{}<br />_required_'.format(var['name'])

            docs_data += [
                '| {} | {} | {} | {} | {} |'.format(
                    var['name'],
                    var['description'].replace('\n', '<br />'),
                    var['default'] if 'default' in var else '-',
                    var['environment'] if 'environment' in var else "_can't be used as ENV variable_",
                    ', '.join([tag.split('/')[0] for tag in var['tags']])
                )
            ]

        docs_data = ['{}\n'.format(line) for line in docs_data]
        readme_data, section_found = [], False

        for line in self.docs_data:
            if re.search(docs_re, line):
                section_found = True
                readme_data += docs_data

                break

            readme_data += [line]

        if (len(readme_data) == 0) or (not section_found):
            log('Unable to find the section in {}!'.format(DOCS_VARS_FILE), True)
            log('Please, recreate the README.md file manually', True)

            exit(1)

        with open(DOCS_VARS_FILE, 'w') as buffer:
            buffer.writelines(readme_data)


class VarsParser:
    def __init__(self):
        self.script_dir = SCRIPT_ROOT_DIR
        self.params_out = {'ansible': '', 'terraform': '', 'env': ''}
        self.prefixes = {'ansible': '-e', 'terraform': '-var'}
        self.read_vars_files()


    def read_vars_files(self):
        self.config_data = read_yaml(VARS_CONFIG_FILE)

        try:
            self.user_data = read_yaml(USER_VARS_FILE)

        except:
            log('{}: Opps, looks like there is a mistake in the vars file!'.format(USER_VARS_FILE))
            log("Please, make sure it is declared in a valid YAML format", True)
            log("Alternatively, run python3 ./scripts/parser.py update_docs to generate a new copy of the vars file", True)

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
                    log('Please, make sure to provide below variable in your vars.yml file:', True)
                    
                    print(json.dumps(var_doc_data, indent=4))
                    exit(1)
                
                else:
                    log('{}: variable value not provided, skipping..'.format(var), True)
                    continue

            else:
                if 'environment' in var_doc_data:
                    self.params_out['env'] += 'export {}="{}" '.format(var_doc_data['environment'], var_value)

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
    if len(argv) > 1 and (argv[1] == 'update_docs'):
        generator = VarsGenerator()

        generator.generate_vars_file()
        generator.update_readme()

        log('Done!', True)

    else:
        parser = VarsParser()
        parser.parse()

        if (len(argv) > 2) and (argv[2] == '--hide-output'):
            exit(0)

        print(json.dumps(parser.params_out))
        exit(0)
