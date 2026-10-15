# Marck Enterprise web server image: Amazon Linux 2023 + Apache + PHP + CodeDeploy agent.
# Built in us-east-1 and copied to us-west-2 so both regions launch the same server.
#   packer init packer && packer build packer

packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "copy_regions" {
  type    = list(string)
  default = ["us-west-2"]
}

variable "ami_prefix" {
  description = "Must match golden_ami_name in infra/stacks/50-compute."
  type        = string
  default     = "marck-enterprise-web"
}

variable "subnet_id" {
  description = "Optional public subnet for the build instance. Empty uses the default VPC."
  type        = string
  default     = ""
}

locals {
  stamp = formatdate("YYYYMMDD-hhmm", timestamp())
}

source "amazon-ebs" "web" {
  region        = var.region
  instance_type = "t3.micro"
  subnet_id     = var.subnet_id == "" ? null : var.subnet_id

  associate_public_ip_address = true
  ssh_username                = "ec2-user"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-kernel-*-x86_64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  ami_name     = "${var.ami_prefix}-${local.stamp}"
  ami_regions  = var.copy_regions
  encrypt_boot = true
  imds_support = "v2.0"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name      = "${var.ami_prefix}-${local.stamp}"
    Project   = "Marck Enterprise"
    Role      = "web"
    BaseAMI   = "{{ .SourceAMIName }}"
    ManagedBy = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.web"]

  provisioner "shell" {
    script          = "${path.root}/scripts/install-web.sh"
    execute_command = "sudo -E bash '{{ .Path }}'"
    env = {
      AWS_REGION = var.region
    }
  }
}
