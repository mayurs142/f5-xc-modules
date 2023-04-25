variable "butane_ami_owner_id" {
  type    = string
  default = "125523088429"
}

variable "butane_variant" {
  type = string
}

variable "butane_version" {
  type = string
}

variable "k0s_version" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "f5xc_site_token" {
  type = string
}

variable "f5xc_site_name" {
  type = string
}

variable "f5xc_cluster_labels" {
  type = list(string)
}