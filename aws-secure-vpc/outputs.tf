# -----------------------------------------------------------------------------
# outputs.tf — Useful values after terraform apply
# -----------------------------------------------------------------------------

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer. Browse http://<this-value>/"
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Ready-to-open ALB URL."
  value       = "http://${aws_lb.app.dns_name}"
}

output "bastion_public_ip" {
  description = "Public IP of the bastion/jump host (SSH entry point)."
  value       = aws_instance.bastion.public_ip
}

output "bastion_public_dns" {
  description = "Public DNS of the bastion host."
  value       = aws_instance.bastion.public_dns
}

output "vpc_id" {
  description = "ID of the custom VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB, bastion, NAT)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (ASG app instances)."
  value       = aws_subnet.private[*].id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.app.name
}

output "app_security_group_id" {
  description = "Security group ID attached to private app instances."
  value       = aws_security_group.app.id
}

output "nat_gateway_public_ip" {
  description = "Elastic IP attached to the NAT Gateway (outbound IP for private instances)."
  value       = aws_eip.nat.public_ip
}

# Note: private instance IPs change as ASG replaces instances.
# After apply, list them with:
#   aws ec2 describe-instances --filters "Name=tag:Role,Values=app" "Name=instance-state-name,Values=running" \
#     --query "Reservations[].Instances[].PrivateIpAddress" --output text
output "how_to_list_private_ips" {
  description = "Hint for listing current private app instance IPs."
  value       = "aws ec2 describe-instances --region ${var.aws_region} --filters Name=tag:Role,Values=app Name=instance-state-name,Values=running --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,AvailabilityZone]' --output table"
}
