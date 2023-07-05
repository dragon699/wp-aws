# resource "aws_security_group" "wp_web_sg" {
#     name = "wp_web_sg"
#     description = "Security group for WordPress web servers"
#     vpc_id = module.network.vpc_id
#     
#     ingress {
#         description = "Allow HTTP from anywhere"
#         from_port = 80
#         to_port = 80
#         protocol = "tcp"
#         cidr_blocks = "splat"
# }