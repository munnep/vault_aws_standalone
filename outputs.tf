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


output "TFC_VAULT_BACKED_AWS_RUN_ROLE_ARN" {
  value = aws_iam_role.vault_aws_creds.arn
}