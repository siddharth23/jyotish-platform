output "server_ip" {
  description = "Public IPv4 address of the single environment server."
  value       = module.app_server.ipv4_address
}
