# -----------------------------------------------------------------------------
# variables.tf — Input variables for the multi-AZ production architecture
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into (AZs are looked up dynamically)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used in Name tags and resource prefixes."
  type        = string
  default     = "secure-vpc"
}

variable "environment" {
  description = "Environment label (dev / staging / prod)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the two private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for ASG instances and bastion (t2.micro / t3.micro fit free tier)."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the target region (required for SSH to bastion)."
  type        = string
}

variable "bastion_ssh_cidr" {
  description = "CIDR allowed to SSH into the bastion. Prefer your public IP/32; 0.0.0.0/0 is open to the world."
  type        = string
  default     = "0.0.0.0/0"
}

variable "asg_desired_capacity" {
  description = "Desired number of app instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "Minimum number of app instances in the Auto Scaling Group."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of app instances in the Auto Scaling Group."
  type        = number
  default     = 3
}

variable "app_port" {
  description = "Port the Python HTTP app listens on (ALB target group + SG rules)."
  type        = number
  default     = 8000
}
