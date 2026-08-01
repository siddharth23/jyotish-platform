variable "hcloud_token" {
  description = "Hetzner Cloud API token (project-scoped, Read & Write). Set via TF_VAR_hcloud_token or -backend-config, never committed."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for server access."
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to reach port 22. Never set this to 0.0.0.0/0."
  type        = list(string)
}

variable "server_type" {
  description = "Hetzner Cloud server type."
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Hetzner Cloud location (fsn1 or nbg1, for German data residency)."
  type        = string
  default     = "fsn1"
}

variable "enable_backups" {
  description = "Enable Hetzner's automatic server backups."
  type        = bool
  default     = true
}
