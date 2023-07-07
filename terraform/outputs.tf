output "dns_load_balancer" {
    sensitive = true
    value = module.infra.dns_load_balancer
}

output "web_instances" {
    sensitive = true
    value = module.infra.web_instances
}

output "db_instance" {
    sensitive = true
    value = module.infra.db_instance
}

# If an ssh-private-key was created
output "private_key" {
    sensitive = true
    value = module.infra.private_key
}