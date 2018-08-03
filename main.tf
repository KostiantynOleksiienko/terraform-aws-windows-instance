/**
 * AWS Instance
 * ============
 * This is an module to creates a DC/OS AWS Instance.
 *
 * If `ami` variable is not set. This module uses the mesosphere suggested OS
 * which also includes all prerequisites.
 *
 * Using you own AMI
 * -----------------
 * If you choose to use your own AMI please make sure the DC/OS related
 * prerequisites are met. Take a look at https://docs.mesosphere.com/1.11/installing/ent/custom/system-requirements/install-docker-RHEL/
 *
 * EXAMPLE
 * -------
 *
 *```hcl
 * module "dcos-master-instance" {
 *   source  = "terraform-dcos/instance/aws"
 *   version = "~> 0.1"
 *
 *   cluster_name = "production"
 *   subnet_ids = ["subnet-12345678"]
 *   security_group_ids = ["sg-12345678"]
 *   hostname_format = "%[3]s-master%[1]d-%[2]s"
 *   ami = "ami-12345678"
 * }
 *```
 */

provider "aws" {}

resource "aws_instance" "instance" {
  instance_type = "${var.instance_type}"
  ami           = "${var.ami}"

  count                       = "${var.num}"
  key_name                    = "${var.key_name}"
  vpc_security_group_ids      = ["${var.security_group_ids}"]
  associate_public_ip_address = "${var.associate_public_ip_address}"
  iam_instance_profile        = "${var.iam_instance_profile}"

  # availability_zone = "${element(var.availability_zones, count.index % length(var.availability_zones)}"
  subnet_id = "${element(var.subnet_ids, count.index % length(var.subnet_ids))}"

  tags = "${merge(var.tags, map("Name", format(var.hostname_format, (count.index + 1), var.region, var.cluster_name),
                                "Cluster", var.cluster_name,
                                "KubernetesCluster", var.cluster_name))}"

  root_block_device {
    volume_size           = "${var.root_volume_size}"
    volume_type           = "${var.root_volume_type}"
    delete_on_termination = true
  }

  user_data = "${var.user_data}"
}