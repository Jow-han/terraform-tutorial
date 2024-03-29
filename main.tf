data "aws_ami" "app_ami" {
    most_recent = true

    filter {
        name  = "name"
        value = [var.ami_filter.name]
    }

    filter {
        name  = "virtualization-type"
        value = ["hvm"]
    }

    owners    = [var.ami_filter.owner]
}

module "nginx_vpc" {
  source      = "terraform-aws-modules/vpc/aws"

  name        = var.environment.name
  cidr        = "${var.environment.network_prefix}.0.0/16"

  azs         = ["ap-southeast-1a","ap-southeast-1b","ap-southeast-1c"]
  public_subnets = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]
  
  tag         = {
    Terraform = true
    Environment = var.environment.name
  }
}

module "nginx_autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "7.4.1"

  name = "${var.environment.name}-nginx"

  min_size            = var.asg_min
  max_size            = var.asg_max
  vpc_zone_identifier = module.nginx_vpc.public_subnets
  target_group_arns   = module.nginx_alb.target_group_arns
  security_groups     = [module.nginx_sg.security_group_id]
  instance_type       = var.instance_type
  image_id            = data.aws_ami.app_ami.id
}

module "nginx_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.8.0"

  name = "${var.environment.name}-nginx-alb"

  load_balancer_type = "application"

  vpc_id             = module.nginx_vpc.vpc_id
  subnets            = module.nginx_vpc.public_subnets
  security_groups    = [module.nginx_sg.security_group_id]

  target_groups = [
    {
      name_prefix      = "${var.environment.name}-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = var.environment.name
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
}


