terraform {
  required_version = ">= 1.9"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.48"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

module "app_server" {
  source = "../../modules/app-server"

  name              = "jyotish-single"
  server_type       = var.server_type
  location          = var.location
  ssh_public_key    = var.ssh_public_key
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  enable_backups    = var.enable_backups
}
