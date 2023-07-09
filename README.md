# wp-aws

###### Create your Wordpress cluster in AWS in just a minute/two

### Requirements
Make sure to have 

### Usage
Clone this project, edit desired values in vars.yml, then
```
$ ./run.sh
```

All values from vars.yml have explanation on the bottom of this file.

### General info
- When you run **__./run.sh__**, a build directory with random ID wil be created for this specific installation of the infrastructure. It will be saved in your home directory **__<sub>~/<build_id></sub>__**.
- 

#### Removing the cluster
You can remove everything created by the automation by going to the build directory mentioned above and removing
```
$ ./destroy.sh
```

##
