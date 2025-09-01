variable "tag_prefix" {
  description = "default prefix of names"
}

variable "region" {
  description = "region to create the environment"
}

variable "license" {
  description = "vault license to use for the vault server"
}

variable "vpc_cidr" {
  description = "which private subnet do you want to use for the VPC. Subnet mask of /16"
}

variable "public_key" {
  type        = string
  description = "public to use on the instances"
}

variable "dns_hostname" {
  description = "DNS hostname first server"
}

variable "dns_zonename" {
  description = "DNS zonename"
}

variable "certificate_email" {
  description = "email address to register the certificate"
}