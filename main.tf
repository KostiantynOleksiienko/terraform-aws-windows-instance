/**
 * AWS DC/OS Windows Instances
 * ============
 * This module creates typical windows instances.
 * _Beaware that this feature is in EXPERIMENTAL state_
 *
 * EXAMPLE
 * -------
 *
 *```hcl
 * module "dcos-windows-instances" {
 *   source  = "dcos-terraform/windows-instance/aws"
 *   version = "~> 0.2.0"
 *
 *   cluster_name = "production"
 *   aws_subnet_ids = ["subnet-12345678"]
 *   aws_security_group_ids = ["sg-12345678"]"
 *
 *   num = "2"
 * }
 *```
 */

provider "aws" {}

data "aws_ami" "windows_ami" {
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-1809-English-Core-ContainersLatest-2019.09.11"]
  }
}

resource "tls_private_key" "private_key" {
  count     = "${var.num > 0 ? 1 : 0}"
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "windowskey" {
  count      = "${var.num > 0 ? 1 : 0}"
  key_name   = "${var.cluster_name}-windowskey-python"
  public_key = "${element(tls_private_key.private_key.*.public_key_openssh, 0)}"
}

// Instances is spawning the VMs to be used with DC/OS (bootstrap)
module "dcos-windows-instances" {
  source  = "dcos-terraform/instance/aws"
  version = "~> 0.2.1"

  providers = {
    aws = "aws"
  }

  cluster_name       = "${var.cluster_name}"
  hostname_format    = "${var.hostname_format}"
  num                = "${var.num}"
  ami                = "${coalesce(var.aws_ami, data.aws_ami.windows_ami.id)}"
  user_data          = "${coalesce(var.user_data, file("${path.module}/user-data.tmpl"))}"
  instance_type      = "${var.aws_instance_type}"
  subnet_ids         = ["${var.aws_subnet_ids}"]
  security_group_ids = ["${var.aws_security_group_ids}"]

  # we need the private key to support a given key.
  # This feature should then be properly designed.
  key_name = "${var.num > 0 ? element(coalescelist(aws_key_pair.windowskey.*.key_name, list("")), 0) : var.aws_key_name}"

  root_volume_size            = "${var.aws_root_volume_size}"
  root_volume_type            = "${var.aws_root_volume_type}"
  extra_volumes               = ["${var.aws_extra_volumes}"]
  associate_public_ip_address = "${var.aws_associate_public_ip_address}"
  tags                        = "${var.tags}"
  dcos_instance_os            = "${var.dcos_instance_os}"
  iam_instance_profile        = "${var.aws_iam_instance_profile}"
  get_password_data           = true
  name_prefix                 = "${var.name_prefix}"
}

data "template_file" "decrypt" {
  count    = "${var.num}"
  template = "$${password}"

  vars {
    password = "${rsadecrypt(element(coalescelist(module.dcos-windows-instances.password_data, list("")), count.index), element(tls_private_key.private_key.*.private_key_pem,0))}"
  }
}
