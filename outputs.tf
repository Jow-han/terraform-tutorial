output "environment_url" {
  value = module.nginx_alb.lb_dns_name
}