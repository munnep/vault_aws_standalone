resource "aws_iam_role" "role" {
  name = "${var.tag_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.tag_prefix}-instance"
  role = aws_iam_role.role.name
}

resource "aws_iam_role_policy" "policy" {
  name = "${var.tag_prefix}-bucket"
  role = aws_iam_role.role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncrypt*"
        ]
        Resource = "${aws_kms_key.vault.arn}"
      },
      {
        Sid      = "AllowAssumeVaultAwsCreds"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.vault_aws_creds.arn
      }
    ]
  })
}

# IAM role that Vault will assume to vend AWS credentials via the AWS secrets engine
resource "aws_iam_role" "vault_aws_creds" {
  name = "vault-aws-creds"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowVaultEC2RoleToAssume"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.role.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "vault_aws_creds_policy" {
  name   = "vault-aws-creds-permissions"
  role   = aws_iam_role.vault_aws_creds.id
  policy = file("${path.module}/vault-aws-creds-permissions.json")
}

resource "aws_kms_key" "vault" {
  description             = "Vault unseal key"
  deletion_window_in_days = 7

  tags = {
    Name = "${var.tag_prefix}-vault-kms-unseal-key"
  }
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${var.tag_prefix}-vault-kms-unseal-key"
  target_key_id = aws_kms_key.vault.key_id
}