variable "environment" {
  description = "The environment for the EC2 instance (e.g., dev, staging, prod)"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 instance to launch"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "The number of EC2 instances to launch"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "The IDs of the subnets to launch the EC2 instances in"
  type        = list(string)
}

variable "key_name" {
  description = "The name of the key pair to associate with the EC2 instances"
  type        = string
  default     = null
}

variable "user_data" {
  description = "The user data script to run when the EC2 instance is launched"
  type        = string
  default     = null
}

variable "security_group_id" {
  description = "The ID of the security group to associate with the EC2 instances"
  type        = string
}


variable "tags" {
  description = "Tags to apply to the EC2 instances"
  type        = map(string)
  default     = {}
}