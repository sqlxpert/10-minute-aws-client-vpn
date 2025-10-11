# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}
