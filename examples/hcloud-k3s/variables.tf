variable ssh_key {
  description = "SSH public Key content needed to provision the instances."
  type        = string
  default     = ""
}

variable agents_num {
  description = "Number of agent nodes."
  default     = 3
}

/* hcloud */
variable hcloud_token {
  default = ""
}

variable hcloud_ssh_keys {
  type    = list(string)
  default = [""]
}

variable install_cloud_controller {
  default = true
}

variable install_fip_controller {
  default = true
}