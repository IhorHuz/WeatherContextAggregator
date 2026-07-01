variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "Path to the local SSH public key to register with EC2"
  type        = string
  default     = "~/.ssh/ips-ec2.pub"
}