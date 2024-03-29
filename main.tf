data "aws_ami" "app_ami" {
    most_recent = true

    filter {
        name  = "name"
        values = [var.ami_filter.name]
    }

    filter {
        name  = "virtualization-type"
        values = ["hvm"]
    }

    owners    = [var.ami_filter.owner]
}

module "nginx_vpc" {
  source      = "terraform-aws-modules/vpc/aws"

  name        = var.environment.name
  cidr        = "${var.environment.network_prefix}.0.0/16"

  azs         = ["ap-southeast-1a","ap-southeast-1b","ap-southeast-1c"]
  public_subnets = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]
  
  tags         = {
    Terraform = true
    Environment = var.environment.name
  }
}

resource "aws_lb" "nginx_alb" {
  name               = "${var.environment.name}-nginx-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.nginx_sg.security_group_id]
  subnets            = module.nginx_vpc.public_subnets

  tags = {
    Environment = var.environment.name
  }
}

resource "aws_lb_target_group" "nginx_target_group" {
  name     = "${var.environment.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.nginx_vpc.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.nginx_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
}


module "nginx_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  vpc_id  = module.nginx_vpc.vpc_id
  name    = "${var.environment.name}-nginx"
  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}



