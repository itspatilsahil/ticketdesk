output "alb_dns_name" {
  description = "Load balancer URL - hit this to reach the app"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "nat_instance_id" {
  value = aws_instance.nat.id
}
