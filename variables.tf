variable "vpc_id" {
  description = "The ID of the existing VPC"
  type        = string
  default     = "vpc-089ced31f7481c4bd" 
}

variable "subnet_id" {
  description = "The ID of the existing subnet"
  type        = string
  default     = "subnet-0c8b33e2a2265ae98"  
}

variable "subnet2_id" {
  description = "The ID of the existing subnet 2"
  type        = string
  default     = "subnet-07c282a6ad15f5cb2"  
}

variable "ext_cert_arn" {
  description = "ARN of external certificate for API GW custom domain"
  type        = string
  default     = "arn:aws:acm:us-east-1:033302958463:certificate/6ec35a57-6b94-4552-98ea-41122e370937"
}

variable "domain_name" {
  description = "Domain name used for API GW custom domain"
  type        = string
  default     = "api.blvck.ovh"
}