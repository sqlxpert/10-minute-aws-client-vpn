# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin



data "aws_subnet" "cvpn_target" {
  region = local.region
  id     = var.cvpn_params["TargetSubnetId"]
  state  = "available"
}

data "aws_vpc" "cvpn" {
  region = local.region
  id     = data.aws_subnet.cvpn_target.vpc_id
  state  = "available"
}

data "aws_subnet" "cvpn_vpc_backup_target" {
  count = var.cvpn_params["BackupTargetSubnetId"] == "" ? 0 : 1

  region = local.region
  vpc_id = data.aws_vpc.cvpn.id
  id     = var.cvpn_params["BackupTargetSubnetId"]
  state  = "available"

  lifecycle {
    postcondition {
      condition = (
        data.aws_subnet.cvpn_target.availability_zone != self.availability_zone
      )
      error_message = "1st and optional 2nd (backup) subnets must cover different availability zones."
    }
  }
}

data "aws_security_groups" "cvpn_custom_client" {
  count = min(length(var.cvpn_params["CustomClientSecGrpIds"]), 1)

  region = local.region
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.cvpn.id]
  }
  filter {
    name   = "group-id"
    values = var.cvpn_params["CustomClientSecGrpIds"] # Already a list
  }
}



# Reference certificates by tag, because you imported them specifically for the
# VPN and presumably have permission to tag them.

data "aws_acm_certificate" "cvpn_server" {
  region = local.region
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
  count = contains(
    keys(data.aws_acm_certificate.cvpn_server.tags),
    "CVpnClientRootChain"
  ) ? 0 : 1

  region = local.region
  tags = {
    CVpnClientRootChain = ""
  }
  statuses    = ["ISSUED"]
  most_recent = true
}



data "aws_kms_key" "cvpn_cloudwatch_logs" {
  count = var.cvpn_params["CloudWatchLogsKmsKey"] == "" ? 0 : 1

  region = local.region
  key_id = provider::aws::arn_build(
    local.partition,
    "kms", # service
    local.region,
    split(":", var.cvpn_params["CloudWatchLogsKmsKey"])[0], # account
    split(":", var.cvpn_params["CloudWatchLogsKmsKey"])[1]  # resource (key/KEY_ID)
  )
  # Provider functions added in Terraform v1.8.0
  # arn_build added in Terraform AWS provider v5.40.0
}



locals {
  cvpn_params = merge(
    var.cvpn_params,
    {
      Enable = tostring(false)
      # Do not associate the virtual private network (VPN) with the virtual
      # private cloud (VPC) when Terraform creates the CloudFormation stack. AWS
      # charges while the association is present, even if no VPN user connects.

      VpcId = data.aws_vpc.cvpn.id

      TargetSubnetId = data.aws_subnet.cvpn_target.id
      BackupTargetSubnetId = try(
        data.aws_subnet.cvpn_vpc_backup_target[0].id,
        ""
      )

      # Terraform won't automatically convert HCL list(string) to
      # CloudFormation List<String> !
      # Error: Inappropriate value for attribute "parameters": element
      # "CustomClientSecGrpIds": string required, but have list of string.
      CustomClientSecGrpIds = join(",",
        try(sort(data.aws_security_groups.cvpn_custom_client[0].ids), [])
      )

      DestinationIpv4CidrBlock = coalesce(
        var.cvpn_params["DestinationIpv4CidrBlock"],
        data.aws_vpc.cvpn.cidr_block
      )

      ServerCertificateArn = data.aws_acm_certificate.cvpn_server.arn
      ClientRootCertificateChainArn = try(
        data.aws_acm_certificate.cvpn_client_root_chain[0].arn,
        ""
      )

      CloudWatchLogsKmsKey = try(
        join(":", [
          provider::aws::arn_parse(data.aws_kms_key.cvpn_cloudwatch_logs[0].arn)["account_id"],
          provider::aws::arn_parse(data.aws_kms_key.cvpn_cloudwatch_logs[0].arn)["resource"],
        ]),
        ""
      )
    }
  )
}



resource "aws_cloudformation_stack" "cvpn_prereq" {
  name          = "CVpnPrereq${var.cvpn_stack_name_suffix}"
  template_body = file("${local.cloudformation_path}/10-minute-aws-client-vpn-prereq.yaml")

  region = local.region

  capabilities = ["CAPABILITY_IAM"]
  policy_body  = file("${local.cloudformation_path}/10-minute-aws-client-vpn-prereq-policy.json")

  tags = local.cvpn_tags
}

data "aws_iam_role" "cvpn_deploy" {
  name = aws_cloudformation_stack.cvpn_prereq.outputs["DeploymentRoleName"]
}



resource "aws_cloudformation_stack" "cvpn" {
  name          = "CVpn${var.cvpn_stack_name_suffix}"
  template_body = file("${local.cloudformation_path}/10-minute-aws-client-vpn.yaml")

  region = local.region

  lifecycle {
    ignore_changes = [
      parameters["Enable"],
      # To turn the VPN on and off, toggle this parameter in CloudFormation,
      # not in Terraform.
    ]
  }

  iam_role_arn = data.aws_iam_role.cvpn_deploy.arn
  policy_body  = file("${local.cloudformation_path}/10-minute-aws-client-vpn-policy.json")

  tags = merge(
    local.cvpn_tags,
    var.cvpn_schedule_tags,
  )

  parameters = local.cvpn_params
}
