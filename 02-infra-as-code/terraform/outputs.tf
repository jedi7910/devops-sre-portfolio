output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.security.security_group_id
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = module.ec2.instance_ids
}

output "instance_public_ips" {
  description = "EC2 instance public IPs"
  value       = module.ec2.instance_public_ips
}

output "web_urls" {
  description = "URLs to access web servers"
  value       = [for ip in module.ec2.instance_public_ips : "http://${ip}"]
}