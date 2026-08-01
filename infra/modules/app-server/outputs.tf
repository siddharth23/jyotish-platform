output "ipv4_address" {
  description = "Public IPv4 address of the server."
  value       = hcloud_server.this.ipv4_address
}

output "server_id" {
  value = hcloud_server.this.id
}
