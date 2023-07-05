variable "region" {
  type        = string
  description = "The AWS region to deploy everything to"
  default     = "eu-west-2"
}


# Networking variables
variable "cidr_public_subnet" {
  type        = string
  description = "The public CIDR that will be used for the web servers"
  default     = "10.0.1.0/24"
}

variable "cidr_private_subnet" {
  type        = string
  description = "The private CIDR that will be used for the database server"
  default     = "10.0.2.0/24"
}


# Infra creation variables
variable "web_instance_count" {
  type        = number
  description = "The number of web servers instances to create"
  default     = 2
}

variable "web_instance_type" {
  type        = string
  description = "The instance type to use for the web servers"
  default     = "t2.micro"
}

variable "db_instance_type" {
  type        = string
  description = "The instance type to use for the database server"
  default     = "t2.micro"
}

variable "ubuntu_version" {
  type            = string
  description     = "The ubuntu version to use for the instances (chaning os type is not supported yet))"
  default         = "22.04"

  validation {
    condition = contains(["20.04", "22.04"], var.ubuntu_version)
    error_message = "Ubuntu version must be either 20.04 or 22.04"
  }
}

variable "os_ami_owner" {
  type        = string
  description = "The AWS AMI owner to use for the instance (ubuntu) images"
  default     = "099720109477"
}

variable "ssh_key" {
  type        = string
  description = "The public ssh key to inject into all instances. If not specified, a new key will be created for all instances."
  default     = "create"
}