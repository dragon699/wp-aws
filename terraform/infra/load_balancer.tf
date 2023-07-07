resource "aws_lb" "wp_web_lb" {
    name = "wp-web-lb-${local.build_id}"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.wp_web_sg.id]
    subnets = aws_subnet.wp_subnets[*].id
}

resource "aws_lb_target_group" "wp_web_lb_tg" {
    name = "wp-web-lb-target-group-${local.build_id}"
    protocol = "HTTP"
    port = var.port_web
    vpc_id = aws_vpc.wp_vpc.id
}

resource "aws_lb_target_group_attachment" "attach_instances" {
    count = length(aws_instance.wp_web_instances)
    target_group_arn = aws_lb_target_group.wp_web_lb_tg.arn
    target_id = aws_instance.wp_web_instances[count.index].id
}

resource "aws_lb_listener" "wp_web_lb_listener" {
  load_balancer_arn = aws_lb.wp_web_lb.arn
  port              = var.port_web
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp_web_lb_tg.arn
  }
}