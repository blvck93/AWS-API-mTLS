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

variable "r53zone_id" {
  description = "The ID of the existing R53 zone"
  type        = string
  default     = "Z052570039KEMOWJVBXUV"  
}
