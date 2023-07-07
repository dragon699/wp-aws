output "dns_load_balancer" {
    value = aws_lb.wp_web_lb.dns_name
}

output "web_instances" {
    value = aws_instance.wp_web_instances
}

output "db_instance" {
    value = aws_instance.wp_db_instance
}

# If an ssh-private-key was created
output "private_key" {
    sensitive = true
    value = tls_private_key.new_ssh_key
}