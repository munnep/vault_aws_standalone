resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.tag_prefix}-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = local.az1
  tags = {
    Name = "${var.tag_prefix}-public"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.tag_prefix}-gw"
  }
}

resource "aws_route_table" "publicroutetable" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.tag_prefix}-route-table-gw"
  }
}

resource "aws_route_table_association" "PublicRT1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.publicroutetable.id
}



resource "aws_security_group" "default-sg" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.tag_prefix}-sg"
  description = "${var.tag_prefix}-sg"

  ingress {
    description = "vault public internet"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "netdata listening"
    from_port   = 19999
    to_port     = 19999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh from private ip"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.tag_prefix}-vault_sg"
  }
}

# code idea from https://itnext.io/lets-encrypt-certs-with-terraform-f870def3ce6d
data "aws_route53_zone" "base_domain" {
  name = var.dns_zonename
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.certificate_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = "${var.dns_hostname}.${var.dns_zonename}"

  recursive_nameservers        = ["1.1.1.1:53"]
  disable_complete_propagation = true

  dns_challenge {
    provider = "route53"

    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.base_domain.zone_id
    }
  }

  depends_on = [acme_registration.registration]
}


data "aws_route53_zone" "selected" {
  name         = var.dns_zonename
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.dns_hostname
  type    = "A"
  ttl     = "300"
  records = [aws_eip.vault-eip.public_ip]
  depends_on = [
    aws_eip.vault-eip
  ]
}

resource "aws_network_interface" "vault-priv" {
  subnet_id   = aws_subnet.public1.id
  private_ips = [cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 22)]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_network_interface_sg_attachment" "sg_attachment" {
  security_group_id    = aws_security_group.default-sg.id
  network_interface_id = aws_network_interface.vault-priv.id
}

resource "aws_eip" "vault-eip" {
  vpc = true

  instance                  = aws_instance.vault_server.id
  associate_with_private_ip = aws_network_interface.vault-priv.private_ip
  depends_on                = [aws_internet_gateway.gw]

  tags = {
    Name = "${var.tag_prefix}-eip"
  }
}

resource "aws_ebs_volume" "vault_swap" {
  availability_zone = local.az1
  size              = 32
  type              = "io2"
  iops              = 1000
}

resource "aws_ebs_volume" "vault_storage" {
  availability_zone = local.az1
  size              = 42
  # default is the gp2 disk
  # type              = "gp2"
  # faster disks is the IOPS version
  type = "io2"
  iops = 3000
}

resource "aws_key_pair" "default-key" {
  key_name   = "${var.tag_prefix}-key"
  public_key = var.public_key
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_instance" "vault_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = "${var.tag_prefix}-key"

  network_interface {
    network_interface_id = aws_network_interface.vault-priv.id
    device_index         = 0
  }

  root_block_device {
    volume_size = 50
    volume_type = "io2"
    iops        = 3000
  }

  user_data = templatefile("${path.module}/scripts/cloudinit_vault_server.yaml", {
    tag_prefix             = var.tag_prefix
    dns_hostname           = var.dns_hostname
    vault-private-ip       = cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 22)
    dns_zonename           = var.dns_zonename
    region                 = var.region
    cert_file              = "${base64encode(acme_certificate.certificate.certificate_pem)}"
    key_file               = "${base64encode(nonsensitive(acme_certificate.certificate.private_key_pem))}"
    local_ip_address       = cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 22)
  })

  tags = {
    Name = "${var.tag_prefix}-vault"
  }

  depends_on = [
    aws_network_interface_sg_attachment.sg_attachment
  ]
}

resource "aws_volume_attachment" "ebs_att_vault_swap" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.vault_swap.id
  instance_id = aws_instance.vault_server.id
}

resource "aws_volume_attachment" "ebs_att_vault_storage" {
  device_name = "/dev/sdj"
  volume_id   = aws_ebs_volume.vault_storage.id
  instance_id = aws_instance.vault_server.id
}