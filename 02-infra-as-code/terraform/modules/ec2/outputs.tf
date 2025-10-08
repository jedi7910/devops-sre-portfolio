output "instance_ids" {
  description = "List of instance IDs"
  value       = aws_instance.main[*].id
}

output "instance_public_ips" {
  description = "List of public IPs"
  value       = aws_instance.main[*].public_ip
}

output "instance_private_ips" {
  description = "List of private IPs"
  value       = aws_instance.main[*].private_ip
}