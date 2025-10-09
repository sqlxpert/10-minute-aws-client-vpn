# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin



# Intended for use in the root module or as a child module. You may wish to
# eliminate the variables and refine the data source arguments, or to
# eliminate the data sources as well, and refer directly to a VPC, subnets and
# other resources. I do not want to prescribe a child module whose interface
# might not fit users' approaches to module composition! Instead, I offer an
# example for you to modify.
#
# https://developer.hashicorp.com/terraform/language/modules/develop/structure
#
# https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/structure.html#repo-structure
#
# https://developer.hashicorp.com/terraform/language/modules/develop/composition

# cvpn_ssm_param_path



data "aws_subnet" "cvpn_target" {
  id    = var.cvpn_params["TargetSubnetIds"][0]
  state = "available"
}

data "aws_vpc" "cvpn" {
  id    = data.aws_subnet.cvpn_target.vpc_id
  state = "available"
}

data "aws_subnet" "cvpn_vpc_backup_target" {
  count = length(var.cvpn_params["TargetSubnetIds"]) >= 2 ? 1 : 0

  vpc_id = data.aws_vpc.cvpn.id
  id     = var.cvpn_params["TargetSubnetIds"][1]
  state  = "available"

  lifecycle {
    postcondition {
      condition     = (data.aws_subnet.cvpn_target.availability_zone != self.availability_zone)
      error_message = "1st and optional 2nd (backup) subnets must cover different availability zones."
    }
  }
}

data "aws_security_groups" "cvpn_custom_client" {
  count = length(try(var.cvpn_params["CustomClientSecGrpIds"], [])) == 0 ? 0 : 1

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
  count = contains(keys(acm_certificate.tags), "CVpnClientRootChain") ? 0 : 1

  tags = {
    CVpnClientRootChain = ""
  }
  statuses    = ["ISSUED"]
  most_recent = true
}



data "aws_kms_key" "cvpn_cloudwatch_logs" {
  count = try(var.cvpn_params["CloudWatchLogsKmsKey"], "") == "" ? 0 : 1

  key_id = provider::aws::arn_build(
    local.partition,
    "kms", # service
    local.region,
    split(":", var.cvpn_params["CloudWatchLogsKmsKey"])[0], # account
    split(":", var.cvpn_params["CloudWatchLogsKmsKey"])[1]  # resource (key/KEY_ID)
  )
}



locals {
  cvpn_params = merge(
    {
      SsmParamPath = "/cloudformation"
    },
    var.cvpn_params,
    {
      Enable = tostring(false)
      # Do not associate the virtual private network (VPN) with the virtual
      # private cloud (VPC) when Terraform creates the CloudFormation stack. AWS
      # charges while the association is present, even if no VPN user connects.

      VpcId = data.aws_vpc.cvpn.id
      DestinationIpv4CidrBlock = try(
        var.cvpn_params["DestinationIpv4CidrBlock"],
        data.aws_vpc.cvpn.cidr_block
      )

      TargetSubnetIds = null
      TargetSubnetId  = data.aws_subnet.cvpn_target.id
      BackupTargetSubnetId = try(
        data.aws_subnet.cvpn_vpc_backup_target.id,
        null
      )

      CustomClientSecGrpIds = try(
        # Terraform won't convert an HCL list to List<String> for CloudFormation!
        # Error: Inappropriate value for attribute "parameters": element
        # "CustomClientSecGrpIds": string required, but have list of string.
        join(",", sort(data.aws_security_groups.cvpn_custom_client.ids)),

        null
      )

      ServerCertificateArn = data.aws_acm_certificate.cvpn_server.arn
      ClientRootCertificateChainArn = try(
        data.aws_acm_certificate.cvpn_client_root_chain.arn,
        null
      )

      CloudWatchLogsKmsKey = try(
        join(":", [
          provider::aws::arn_parse(data.aws_kms_key.cvpn_cloudwatch_logs.arn)["account_id"],
          provider::aws::arn_parse(data.aws_kms_key.cvpn_cloudwatch_logs.arn)["resource"],
        ]),
        null
      )
    }
  )
}



resource "aws_cloudformation_stack" "cvpn_prereq" {
  name          = "CVpnPrereq${var.cvpn_stack_name_suffix}"
  template_body = file("${path.module}/../cloudformation/10-minute-aws-client-vpn-prereq.yaml")

  capabilities = ["CAPABILITY_IAM"]
  policy_body  = file("${path.module}/../cloudformation/10-minute-aws-client-vpn-prereq-policy.json")

  tags = local.cvpn_tags
}

data "aws_iam_role" "cvpn_deploy" {
  name = aws_cloudformation_stack.cvpn_prereq.outputs["DeploymentRoleName"]
}



resource "aws_cloudformation_stack" "cvpn" {
  name          = "CVpn${var.cvpn_stack_name_suffix}"
  template_body = file("${path.module}/../cloudformation/10-minute-aws-client-vpn.yaml")

  lifecycle {
    ignore_changes = [
      parameters["Enable"]
      # To turn the VPN on and off, toggle this parameter in CloudFormation,
      # not in Terraform.
    ]
  }

  iam_role_arn = data.aws_iam_role.cvpn_deploy.arn
  policy_body  = file("${path.module}/../cloudformation/10-minute-aws-client-vpn-policy.json")

  tags = local.cvpn_tags

  parameters = local.cvpn_params
}
