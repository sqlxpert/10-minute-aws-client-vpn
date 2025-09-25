# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin



# These resources are intended for the root module, or for your own complete
# child module. You may wish to eliminate the variables and refine the data
# source arguments, or to eliminate the data sources as well, and refer
# directly to a VPC, subnets, etc. that you have defined. I did not want to
# define a complete child module that might not match your approach to
# module composition.
#
# A CloudFormation StackSet would be the easy, AWS-idiomatic, way to deploy
# to multiple AWS accounts and/or regions.
#
# Although you will likely rely on VPC Peering, Transit Gateway or VPC Lattice
# instead of creating VPNs in multiple accounts and regions, I loop over
# accounts and regions for the data sources, to demonstrate a structure that
# might be useful for setting
# aws_cloudformation_stack_set_instance.parameter_overrides .



# Tested with the specific versions listed.
terraform {
  required_version = "1.13.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.14.1"
    }
  }
}



# Reference resources not specific to the VPN by ID, because it might not be
# possible to tag shared, multi-purpose resources.



variable "accounts_to_regions_to_cvpn_params" {
  type        = map(any)
  description = "Nested map. Outer keys: account number strings, or CURRENT_AWS_ACCOUNT for any one. Intermediate keys: regions such as us-west-2 , or CURRENT_AWS_REGION for any one. Required inner key: target_subnet_ids , a list with 1 to 2 elements. 1st subnet determines VPC. Optional inner keys: destination_ipv4_cidr_block , dns_server_ipv4_addr , client_ipv4_cidr_block and custom_client_sec_grp_ids . If destination_ipv4_cidr_block is not specified, VPC's primary IPv4 CIDR block is used. See corresponding CloudFormation stack parameters."
}
variable "cvpn_cloudwatch_logs_kms_key" {
  type        = string
  description = "If not set, default non-KMS CloudWatch Logs encryption applies. See CloudWatchLogsKmsKey CloudFormation parameter."

  default = null
}



data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
locals {
  caller_arn_parts = provider::aws::arn_parse(data.aws_caller_identity.current.arn)
  account_id       = local.caller_arn_parts["account_id"]
  region           = data.aws_region.current.region

  accounts_to_regions_to_cvpn_params = {
    for account_id, regions_to_cvpn_params in var.accounts_to_regions_to_cvpn_params :
    replace(account_id, "/^CURRENT_AWS_ACCOUNT$/", local.account_id) => regions_to_cvpn_params
  }

  regions_to_cvpn_params = {
    for region, cvpn_params in local.accounts_to_regions_to_cvpn_params[local.account_id] :
    replace(region, "/^CURRENT_AWS_REGION$/", local.region) => cvpn_params
  }
  cvpn_regions_set = toset(keys(local.regions_to_cvpn_params))

  cvpn_params = local.regions_to_cvpn_params[local.region]
}



data "aws_subnet" "cvpn_target" {
  for_each = {
    for region, cvpn_params in local.regions_to_cvpn_params :
    region => cvpn_params["target_subnet_ids"][0]
  }

  region = each.key
  id     = each.value
  state  = "available"
}

data "aws_subnet" "cvpn_vpc_backup_target" {
  for_each = {
    for region, cvpn_params in local.regions_to_cvpn_params :
    region => cvpn_params["target_subnet_ids"][1]
    if length(cvpn_params["target_subnet_ids"]) >= 2
  }

  region = each.key
  id     = each.value
  state  = "available"

  lifecycle {
    postcondition {
      condition     = (data.aws_subnet.cvpn_target[each.key].vpc_id == self.vpc_id)
      error_message = "1st and optional 2nd (backup) subnets must be in same VPC."
    }
    postcondition {
      condition     = (data.aws_subnet.cvpn_target[each.key].availability_zone != self.availability_zone)
      error_message = "1st and optional 2nd (backup) subnets must cover different availability zones."
    }
  }
}



data "aws_vpc" "cvpn" {
  for_each = local.cvpn_regions_set

  region = each.key
  id     = data.aws_subnet.cvpn_target[each.key].vpc_id
  state  = "available"
}



data "aws_security_groups" "cvpn_custom_client" {
  for_each = {
    for region, cvpn_params in local.regions_to_cvpn_params :
    region => cvpn_params["custom_client_sec_grp_ids"]
    if contains(keys(cvpn_params), "custom_client_sec_grp_ids")
  }

  region = each.key
  filter {
    name   = "group-id"
    values = each.value
  }

  lifecycle {
    postcondition {
      condition     = (data.aws_vpc.cvpn[each.key].id == one(toset(self.vpc_ids)))
      error_message = "All custom VPN client security groups must be in the VPN's target VPC."
    }
  }
}



# Reference certificates by tag, because they have been created specifically
# for the VPN.

data "aws_acm_certificate" "cvpn_server" {
  for_each = local.cvpn_regions_set

  region = each.key
  tags = {
    CVpnServer = ""
  }
  statuses    = ["ISSUED"]
  most_recent = true
}

# To use the server certificate, so that a client with any certificate from the
# same certificate authority (CA) can connect, tag it with CVpnServer AND
# CVpnClientRootChain .
data "aws_acm_certificate" "cvpn_client_root_chain" {
  for_each = toset([
    for acm_certificate in data.aws_acm_certificate.cvpn_server :
    acm_certificate.region
    if !contains(keys(acm_certificate.tags), "CVpnClientRootChain")
  ])

  region = each.key
  tags = {
    CVpnClientRootChain = ""
  }
  statuses    = ["ISSUED"]
  most_recent = true
}



data "aws_kms_key" "cvpn_cloudwatch_logs" {
  for_each = (
    (var.cvpn_cloudwatch_logs_kms_key == null) ? toset([]) : local.cvpn_regions_set
  )

  region = each.key
  key_id = provider::aws::arn_build(
    local.caller_arn_parts["partition"],
    "kms", # service
    local.region,
    split(":", var.cvpn_cloudwatch_logs_kms_key)[0], # account
    split(":", var.cvpn_cloudwatch_logs_kms_key)[1]  # resource (key/KEY_ID)
  )
}



resource "aws_cloudformation_stack" "cvpn" {
  name          = "CVpn"
  template_body = file("${path.module}/10-minute-aws-client-vpn.yaml")

  lifecycle {
    ignore_changes = [
      parameters["Enable"]
      # To turn the VPN on and off, toggle this parameter from CloudFormation,
      # not in Terraform.
    ]
  }

  parameters = {
    Enable = tostring(false)
    # Do not associate the virtual private network (VPN) with the virtual
    # private cloud (VPC) when Terraform creates the CloudFormation stack. AWS
    # charges while the association is present, even if no VPN user connects.

    VpcId = data.aws_vpc.cvpn[local.region].id
    DestinationIpv4CidrBlock = try(
      local.cvpn_params["destination_ipv4_cidr_block"],
      data.aws_vpc.cvpn[local.region].cidr_block
    )
    DnsServerIpv4Addr = try(
      local.cvpn_params["dns_server_ipv4_addr"],
      null
    )

    TargetSubnetId = data.aws_subnet.cvpn_target[local.region].id
    BackupTargetSubnetId = try(
      data.aws_subnet.cvpn_vpc_backup_target[local.region].id,
      null
    )

    ClientIpv4CidrBlock = try(
      local.cvpn_params["client_ipv4_cidr_block"],
      null
    )

    CustomClientSecGrpIds = try(
      sort(data.aws_security_groups.cvpn_custom_client[local.region].ids),
      null
    )

    ServerCertificateArn = data.aws_acm_certificate.cvpn_server[local.region].arn
    ClientRootCertificateChainArn = try(
      data.aws_acm_certificate.cvpn_client_root_chain[local.region].arn,
      null
    )

    CloudWatchLogsKmsKey = try(
      join(
        ":",
        [
          provider::aws::arn_parse(data.aws_kms_key.cvpn_cloudwatch_logs[local.region].arn)["account_id"],
          provider::aws::arn_parse(data.aws_kms_key.cvpn_cloudwatch_logs[local.region].arn)["resource"],
        ]
      ),
      null
    )
  }
}
