variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "secure-b2b-api"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "germanywestcentral"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-secure-b2b-api"
}