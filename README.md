# wp-aws

###### Create your Wordpress cluster in AWS in just a minute/two

### Requirements
- **Python 3**
  - ~~**venv**~~ - will be installed automatically
- ~~**Ansible, Terraform**~~ - will be installed automatically

### Usage
Clone this project, edit desired values in **vars.yml**, then
```
$ ./run.sh
```

If you want to be able to SSH into the created VMs using your key, make sure to change **ssh-key** variable from "**_create_**" to **_your_public_key_**

### General info
- The script first deploys the network resources and the VMs with enabled internet access. After the configuration management part is done, the database internet access gets completely disabled and remains open only on the database port defined in **vars.yml** and allows connections only from the created web servers
- When you run **./run.sh**, a build directory with random ID wil be created for this specific installation of the infrastructure. It will be saved in your home directory **~/<build_id>**, see also steps for destroying below
- The scheduled database optimization script for the tables: **scripts/optimize_tables.sh**
- In addition to the main idea, I've also decided to create those helper scripts
  - **parser.py** - Used to pass variables from vars.yaml as ansible, terraform and bash CLI args as **./python3 parser.py parse_vars**. There's also another file - **config/vars_config.yml** which contains all manual documentation and destination of each variable and tells the parser which variable should go where by using the **tags** key for each. The script can also be used manually like this **python3 ./parser.py update_docs** to update both this file on the bottom and the **vars.yml** file itself, whenever there is a new variable introduced.
  - **create_inventory.py** - I've decided to rely on a script that creates an ansible inventory to do the configuration management part, instead of using the ec2 inventory script. This script takes output values from terraform and creates the inventory.
  

#### Removing the cluster
You can remove everything created by the automation by going to the build directory and running
```
$ ./destroy.sh
```

#### Variables in vars.yml
This section was automatically generated by parser.py - please do not edit edit it

| Name  | Description | Default value | Alternative | Consumed by |
| - | - | - | - | - |
| **region**<br />_required_ | AWS Region to deploy the cluster to;<br />Env AWS_REGION could also be used instead | eu-west-2 | AWS_REGION | terraform |
| **aws_access_key_id**<br />_required_ | AWS Access Key ID from your AWS account;<br />export AWS_ACCESS_KEY_ID=<secret> could also be used instead | - | AWS_ACCESS_KEY_ID | terraform |
| **aws_secret_access_key**<br />_required_ | AWS Secret Access Key;<br />export AWS_SECRET_ACCESS_KEY=<secret> could also be used instead | - | AWS_SECRET_ACCESS_KEY | terraform |
| **public_subnet_cidrs** | CIDR blocks for the public subnets | ['10.0.1.0/24', '10.0.2.0/24'] | _can't be used as ENV variable_ | terraform |
| **web_servers_count** | How many web servers to deploy behind the load balancer | 2 | _can't be used as ENV variable_ | terraform |
| **web_servers_type** | EC2 type for the web servers | t2.micro | _can't be used as ENV variable_ | terraform |
| **db_server_type** | EC2 type for the database server | t2.micro | _can't be used as ENV variable_ | terraform |
| **os_ami_owner** | Ubuntu only - AMI owner ID to use for all servers | 099720109477 | _can't be used as ENV variable_ | terraform |
| **os_version** | Ubuntu only - OS version to use for all servers | 22.04 | _can't be used as ENV variable_ | terraform |
| **ssh-key** | SSH key to use for all servers;<br />With "create" a new SSH-key will be generated for you;<br />Change "create" to your public key text in order to use your own key;<br />Env SSH_KEY could also be used instead | create | SSH_KEY | terraform |
| **port_ssh** | SSH port to use and allow in security groups | 22 | _can't be used as ENV variable_ | terraform, ansible |
| **port_web** | HTTP port to use for the web servers | 80 | _can't be used as ENV variable_ | terraform, ansible |
| **port_db** | MariaDB port to use for the database server | 3306 | _can't be used as ENV variable_ | terraform, ansible |
| **wp_db_user**<br />_required_ | User to create for the Wordpress database;<br />env WP_DB_USER could also be used instead | wordpress | WP_DB_USER | ansible |
| **wp_db_passwd**<br />_required_ | Password to assign to the Wordpress database user;<br />env WP_DB_PASSWD could also be used instead | - | WP_DB_PASSWD | ansible |
| **wp_db_name**<br />_required_ | Database name for Wordpress;<br />env WP_DB_NAME could also be used instead | wordpress | WP_DB_NAME | ansible |
| **wp_web_title** | Title to assign to the Wordpress site template;<br />Will appear on top of home page | Linux | _can't be used as ENV variable_ | ansible |
| **wp_admin_email**<br />_required_ | Email to assign to the Wordpress admin panel user;<br />env WP_ADMIN_EMAIL could also be used instead | - | WP_ADMIN_EMAIL | ansible |
| **wp_admin_user**<br />_required_ | Admin panel user for Wordpress;<br />env WP_ADMIN_USER could also be used instead | admin | WP_ADMIN_USER | ansible |
| **wp_admin_passwd**<br />_required_ | Password to assign to the Wordpress admin panel user;<br />env WP_ADMIN_PASSWD could also be used instead | - | WP_ADMIN_PASSWD | ansible |
