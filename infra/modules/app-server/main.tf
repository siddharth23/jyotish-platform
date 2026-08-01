resource "hcloud_ssh_key" "this" {
  name       = var.name
  public_key = var.ssh_public_key
}

resource "hcloud_firewall" "this" {
  name = var.name

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.allowed_ssh_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "this" {
  name         = var.name
  server_type  = var.server_type
  location     = var.location
  image        = "ubuntu-24.04"
  ssh_keys     = [hcloud_ssh_key.this.id]
  firewall_ids = [hcloud_firewall.this.id]
  backups      = var.enable_backups

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ssh_public_key = var.ssh_public_key
  })

  labels = {
    managed-by = "terraform"
  }
}
