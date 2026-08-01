variable "name" {
  description = "Server name, also used to derive related resource names."
  type        = string
}

variable "server_type" {
  description = "Hetzner Cloud server type, e.g. cx23."
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location. Use a German location (fsn1 or nbg1) for data residency."
  type        = string

  validation {
    condition     = contains(["fsn1", "nbg1"], var.location)
    error_message = "Use a German location (fsn1 or nbg1) to keep data residency inside Germany."
  }
}

variable "ssh_public_key" {
  description = "SSH public key installed for the root (first-boot) and deploy users."
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to reach port 22. Never set this to 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = !contains(var.allowed_ssh_cidrs, "0.0.0.0/0") && !contains(var.allowed_ssh_cidrs, "::/0")
    error_message = "allowed_ssh_cidrs must not be open to the whole internet."
  }
}

variable "enable_backups" {
  description = "Enable Hetzner's automatic server backups (+20% of server cost)."
  type        = bool
  default     = true
}
