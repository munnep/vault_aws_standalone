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
      }
    ]
  })
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