output "ssh_vault_server" {
  value = "ssh ubuntu@${var.dns_hostname}.${var.dns_zonename}"
}

output "vault_dashboard" {
  value = "https://${var.dns_hostname}.${var.dns_zonename}:8200"
}

output "vault_address" {
  value = "export VAULT_ADDR='https://${var.dns_hostname}.${var.dns_zonename}:8200'"
}

output "vault_ip" {
  value = aws_eip.vault-eip.public_ip
}
