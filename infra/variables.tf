variable "allowed_ingress_ip" {
  description = "Public IP allowed for resource access"
  type        = string
  sensitive   = true # This avoid to show this on any terraform log. 
}

variable "region" {
  description = "AWS REgion"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project Name for tagging"
  type        = string
  default     = "DevSecOps-Lab"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.micro"
}