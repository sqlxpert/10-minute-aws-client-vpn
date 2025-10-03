# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin



# Intended for use in the root module or as a child module. You may wish to
# eliminate the variables and refine the data source arguments, or to
# eliminate the data sources as well, and refer directly to a VPC, subnets and
# other resources. I do not want to prescribe a child module whose interface
# might not fit users' approaches to module composition! Instead, I offer an
# example for you to modify. For the same reason, I have not split this into
# main.tf and other separate files. To guide you:
#
# https://developer.hashicorp.com/terraform/language/modules/develop/structure
#
# https://developer.hashicorp.com/terraform/language/modules/develop/composition



# A CloudFormation StackSet, rather than for_each on aws_cloudformation_stack
# or multiple instances of a module, would be the easy, AWS-idiomatic way to
# deploy VPNs in multiple AWS accounts and regions. Version 6 of the Terraform
# AWS Provider, released in 2025-06, supports using a single provider reference
# for resources in multiple regions, but existing Terraform HCL code will have
# to be refactored, and you are still on your own for multiple accounts.
# Although you will likely rely on VPC Peering, Transit Gateway or VPC Lattice
# instead of creating VPNs in multiple accounts and regions, I do loop over
# accounts (in locals) and regions (in data sources), to demonstrate a
# structure that might be useful for setting
# aws_cloudformation_stack_set_instance.parameter_overrides .
#
# https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-concepts.html#stacksets-concepts-stackset



terraform {
  required_version = "~> 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14.0"
    }
  }
}



# Reference resources not specific to the VPN by ID, because you might not have
# permission to tag shared, multi-purpose resources...



variable "accounts_to_regions_to_cvpn_params" {
  type        = map(any)
  description = "Nested map. Outer keys: account number strings, or CURRENT_AWS_ACCOUNT for any one. Intermediate keys: region code strings such as us-west-2 , or CURRENT_AWS_REGION for any one. Required inner key: TargetSubnetIds , a list with 1 to 2 elements. The 1st subnet determines the VPC, and any other inputs must be in that VPC. Optional inner keys: DestinationIpv4CidrBlock , DnsServerIpv4Addr , ClientIpv4CidrBlock , CustomClientSecGrpIds , and schedule_tags . If DestinationIpv4CidrBlock is not specified, the VPC's primary IPv4 CIDR block is used. Keys mentioned above correspond to CloudFormation stack parameters. If automatic scheduling is configured, set schedule expressions by adding schedule_tags , a map with keys sched-set-Enable-true and sched-set-Enable-false ."

  default = {
    "CURRENT_AWS_ACCOUNT" = {
      "CURRENT_AWS_REGION" = {
        "TargetSubnetIds" = [
          # 1st required, 2nd optional
          "subnet-10123456789abcdef",
        ],

        # Optional:
        "DestinationIpv4CidrBlock" = ""
        "DnsServerIpv4Addr"        = ""
        "ClientIpv4CidrBlock"      = ""
        "CustomClientSecGrpIds" = [
          # "sg-10123456789abcdef",
        ]
        "schedule_tags" = {
          "sched-set-Enable-true"  = ""
          "sched-set-Enable-false" = ""
        }
      }
    }
  }
}
variable "cvpn_cloudwatch_logs_kms_key" {
  type        = string
  description = "If not set, default non-KMS CloudWatch Logs encryption applies. See the CloudWatchLogsKmsKey CloudFormation stack parameter."

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

  cvpn_ssm_param_path = "/cloudformation"
}



data "aws_subnet" "cvpn_target" {
  for_each = {
    for region, cvpn_params in local.regions_to_cvpn_params :
    region => cvpn_params["TargetSubnetIds"][0]
  }

  region = each.key
  id     = each.value
  state  = "available"
}

data "aws_vpc" "cvpn" {
  for_each = local.cvpn_regions_set

  region = each.key
  id     = data.aws_subnet.cvpn_target[each.key].vpc_id
  state  = "available"
}

data "aws_subnet" "cvpn_vpc_backup_target" {
  for_each = {
    for region, cvpn_params in local.regions_to_cvpn_params :
    region => cvpn_params["TargetSubnetIds"][1]
    if length(cvpn_params["TargetSubnetIds"]) >= 2
  }

  region = each.key
  vpc_id = data.aws_vpc.cvpn[each.key].id
  id     = each.value
  state  = "available"

  lifecycle {
    postcondition {
      condition     = (data.aws_subnet.cvpn_target[each.key].availability_zone != self.availability_zone)
      error_message = "1st and optional 2nd (backup) subnets must cover different availability zones."
    }
  }
}

data "aws_security_groups" "cvpn_custom_client" {
  for_each = {
    for region, cvpn_params in local.regions_to_cvpn_params :
    region => cvpn_params["CustomClientSecGrpIds"]
    if length(try(cvpn_params["CustomClientSecGrpIds"], [])) >= 1
  }

  region = each.key
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.cvpn[each.key].id]
  }
  filter {
    name   = "group-id"
    values = each.value # Already a list
  }
}



# Reference certificates by tag, because you imported them specifically for the
# VPN and presumably have permission to tag them.

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
# same certificate authority (CA) can connect, tag it with BOTH CVpnServer AND
# CVpnClientRootChain .
data "aws_acm_certificate" "cvpn_client_root_chain" {
  for_each = toset([
    for region, acm_certificate in data.aws_acm_certificate.cvpn_server :
    region
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
    var.cvpn_cloudwatch_logs_kms_key == null ? toset([]) : local.cvpn_regions_set
  )

  region = each.key
  key_id = provider::aws::arn_build(
    local.caller_arn_parts["partition"],
    "kms", # service
    each.key,
    split(":", var.cvpn_cloudwatch_logs_kms_key)[0], # account
    split(":", var.cvpn_cloudwatch_logs_kms_key)[1]  # resource (key/KEY_ID)
  )
}



resource "aws_cloudformation_stack" "cvpn_prereq" {
  name          = "CVpnPrereq"
  template_body = file("${path.module}/10-minute-aws-client-vpn-prereq.yaml")

  capabilities = ["CAPABILITY_IAM"]

  policy_body = file(
    "${path.module}/10-minute-aws-client-vpn-prereq-policy.json"
  )
}



data "aws_iam_role" "cvpn_deploy" {
  name = aws_cloudformation_stack.cvpn_prereq.outputs["DeploymentRoleName"]
}



resource "aws_cloudformation_stack" "cvpn" {
  name          = "CVpn"
  template_body = file("${path.module}/10-minute-aws-client-vpn.yaml")

  lifecycle {
    ignore_changes = [
      parameters["Enable"]
      # To turn the VPN on and off, toggle this parameter in CloudFormation,
      # not in Terraform.
    ]
  }

  policy_body = file("${path.module}/10-minute-aws-client-vpn-policy.json")

  tags = {
    sched-set-Enable-true = try(
      local.cvpn_params.schedule_tags["sched-set-Enable-true"],
      null
    )
    sched-set-Enable-false = try(
      local.cvpn_params.schedule_tags["sched-set-Enable-false"],
      null
    )
  }

  iam_role_arn = data.aws_iam_role.cvpn_deploy.arn

  parameters = {
    Enable = tostring(false)
    # Do not associate the virtual private network (VPN) with the virtual
    # private cloud (VPC) when Terraform creates the CloudFormation stack. AWS
    # charges while the association is present, even if no VPN user connects.

    VpcId = data.aws_vpc.cvpn[local.region].id
    DestinationIpv4CidrBlock = try(
      local.cvpn_params["DestinationIpv4CidrBlock"],
      data.aws_vpc.cvpn[local.region].cidr_block
    )
    DnsServerIpv4Addr = try(
      local.cvpn_params["DnsServerIpv4Addr"],
      null
    )

    TargetSubnetId = data.aws_subnet.cvpn_target[local.region].id
    BackupTargetSubnetId = try(
      data.aws_subnet.cvpn_vpc_backup_target[local.region].id,
      null
    )

    ClientIpv4CidrBlock = try(
      local.cvpn_params["ClientIpv4CidrBlock"],
      null
    )

    SsmParamPath = local.cvpn_ssm_param_path
    CustomClientSecGrpIds = try(
      # Terraform won't convert an HCL list to List<String> for CloudFormation!
      # Error: Inappropriate value for attribute "parameters": element
      # "CustomClientSecGrpIds": string required, but have list of string.
      join(",",
        sort(data.aws_security_groups.cvpn_custom_client[local.region].ids)
      ),
      null
    )

    ServerCertificateArn = data.aws_acm_certificate.cvpn_server[local.region].arn
    ClientRootCertificateChainArn = try(
      data.aws_acm_certificate.cvpn_client_root_chain[local.region].arn,
      null
    )

    CloudWatchLogsKmsKey = try(
      join(":", [
        provider::aws::arn_parse(data.aws_kms_key.cvpn_cloudwatch_logs[local.region].arn)["account_id"],
        provider::aws::arn_parse(data.aws_kms_key.cvpn_cloudwatch_logs[local.region].arn)["resource"],
      ]),
      null
    )
  }
}



# The CloudFormation template is self-contained. Resources that you might need
# to reference can be resolved from inputs that you provided; no stack outputs
# are needed.



# If you did not supply your own security group(s) for VPN clients, an AWS
# Systems Manager (SSM) Parameter Store parameter with a known name identifies
# the generic VPN client security group created for you. Unnecessary dependence
# on module outputs leaves Terraform configurations brittle; pre-defining
# security group(s) and passing them in lets you refer to them at any stage,
# dependency-free.
data "aws_ssm_parameter" "cvpn_client_sec_grp_id" {
  count = try(aws_cloudformation_stack.cvpn.parameters["CustomClientSecGrpIds"], "") == "" ? 1 : 0
  # CustomClientSecGrpIds is a string in HCL, not a list; see above!

  name = join("/", [
    local.cvpn_ssm_param_path,
    aws_cloudformation_stack.cvpn.name,
    "ClientSecGrpId"
  ])
}
data "aws_security_group" "cvpn_client" {
  count = try(aws_cloudformation_stack.cvpn.parameters["CustomClientSecGrpIds"], "") == "" ? 1 : 0

  id = data.aws_ssm_parameter.cvpn_client_sec_grp_id[0].insecure_value
}
output "cvpn_client_sec_grp_id" {
  value       = try(data.aws_security_group.cvpn_client[0].id, null)
  description = "ID of the generic security group for Client VPN clients. Defined only if not custom security groups were supplied (see the CustomClientSecGrpIds CloudFormation stack parameter."
}



data "aws_ec2_client_vpn_endpoint" "cvpn" {
  tags = {
    Name = aws_cloudformation_stack.cvpn.name
    # "aws:cloudformation:stack-name" tag not yet available, as of 2025-10
  }
}
output "cvpn_endpoint_id" {
  value       = data.aws_ec2_client_vpn_endpoint.cvpn.client_vpn_endpoint_id
  description = "ID of the Client VPN endpoint. The self-service portal is not available, due to use of mutual TLS authentication. Download the VPN client configuration file using the AWS Console (VPC service) or the command-line interface: aws ec2 export-client-vpn-client-configuration --output text --client-vpn-endpoint-id 'cvpn-endpoint-00123456789abcdef'"
}
