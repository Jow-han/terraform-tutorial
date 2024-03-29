output "environment_url" {
  value = aws_lb.nginx_alb.dns_name
}