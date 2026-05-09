# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin



data "aws_subnet" "cvpn_target" {
  count = local.create_target_net_assoc ? 1 : 0

  region = local.region
  id     = var.cvpn_params["TargetSubnetId"]
  state  = "available"
}

data "aws_vpc" "cvpn" {
  region = local.region
  id = (
    local.create_target_net_assoc
    ? data.aws_subnet.cvpn_target[0].vpc_id
    : var.cvpn_params["VpcId"]
  )
  state = "available"
}



data "aws_ssm_parameter" "existing_cvpn_endpoint_id" {
  count = local.reference_endpoint_stack ? 1 : 0

  region = local.region
  name = join("/", [
    var.cvpn_params["SsmParamPath"],
    local.cvpn_endpoint_cloudformation_stack_name,
    "EndpointId"
  ])
}

data "aws_ec2_client_vpn_endpoint" "existing_cvpn" {
  count = local.reference_endpoint ? 1 : 0

  region = local.region
  client_vpn_endpoint_id = (
    local.reference_endpoint_stack
    ? data.aws_ssm_parameter.existing_cvpn_endpoint_id[0].insecure_value
    : var.cvpn_params["ExistingEndpointId"]
  )

  lifecycle {
    postcondition {
      condition = (data.aws_vpc.cvpn.id == self.vpc_id)

      error_message = "The target VPC subnet is not in ${self.vpc_id} , the VPC of the VPN endpoint."
    }
  }
}



data "aws_security_groups" "cvpn_custom_client" {
  count = min(local.custom_client_security_group_count, 1)

  region = local.region
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.cvpn.id]
  }
  filter {
    name   = "group-id"
    values = local.custom_client_security_group_ids_set
  }

  lifecycle {
    postcondition {
      condition = (local.custom_client_security_group_count == length(self.ids))
      # https://registry.terraform.io/providers/hashicorp/aws/6.44.0/docs/data-sources/security_groups#ids-1

      error_message = "Custom client security group ID(s) ${join(", ", setsubtract(local.custom_client_security_group_ids_set, toset(self.ids)))} was/were not found in the Client VPN endpoint's VPC, ${data.aws_vpc.cvpn.id} ."
    }
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

# To use the server certificate, so that a client with any certificate signed
# by the same certificate authority (CA) can connect, tag it with BOTH
# CVpnServer AND CVpnClientRootChain .
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

    local.create_endpoint
    ? {

      VpcId = data.aws_vpc.cvpn.id

      DestinationIpv4CidrBlock = coalesce(
        var.cvpn_params["DestinationIpv4CidrBlock"],
        data.aws_vpc.cvpn.cidr_block
      )

      ServerCertificateArn = data.aws_acm_certificate.cvpn_server.arn

      # Terraform won't automatically convert HCL list(string) to
      # CloudFormation List<String> !
      # Error: Inappropriate value for attribute "parameters": element
      # "CustomClientSecGrpIds": string required, but have list of string.
      CustomClientSecGrpIds = join(",",
        try(sort(data.aws_security_groups.cvpn_custom_client[0].ids), [])
      )
      DnsServerIpv4Addresses = join(",",
        sort(toset(var.cvpn_params["DnsServerIpv4Addresses"]))
      )

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
    : { # !local.create_endpoint

      # Need strings, empty in this case, for CloudFormation; see above.
      CustomClientSecGrpIds  = ""
      DnsServerIpv4Addresses = ""
    },

    local.reference_endpoint_stack ? {
      ExistingEndpointStackName = local.cvpn_endpoint_cloudformation_stack_name
    } : {},

    local.create_target_net_assoc ? {
      Enable = tostring(false)
      # Do not associate the virtual private network (VPN) with the virtual
      # private cloud (VPC) when Terraform creates the CloudFormation stack.
      # AWS charges while the association is present, even if no VPN user
      # connects.

      TargetSubnetId = data.aws_subnet.cvpn_target[0].id
    } : {},
  )
}



resource "aws_cloudformation_stack" "cvpn_prereq" {
  count = local.reference_endpoint_stack ? 0 : 1

  region        = local.region
  name          = local.cvpn_prereq_cloudformation_stack_name
  template_body = file("${local.cloudformation_path}/10-minute-aws-client-vpn-prereq.yaml")

  capabilities = ["CAPABILITY_IAM"]
  policy_body  = file("${local.cloudformation_path}/10-minute-aws-client-vpn-prereq-policy.json")

  tags = local.cvpn_tags
}
data "aws_iam_role" "cvpn_deploy" {
  count = local.reference_endpoint_stack ? 0 : 1

  name = aws_cloudformation_stack.cvpn_prereq[0].outputs[
    local.create_endpoint ? "DeploymentRoleName" : "OperationRoleName"
  ]
}

data "aws_cloudformation_stack" "existing_cvpn_prereq" {
  count = local.reference_endpoint_stack ? 1 : 0

  region = local.region
  name   = local.cvpn_prereq_cloudformation_stack_name
}
data "aws_iam_role" "existing_cvpn_deploy" {
  count = local.reference_endpoint_stack ? 1 : 0

  name = data.aws_cloudformation_stack.existing_cvpn_prereq[0].outputs[
    "OperationRoleName"
  ]
}



resource "aws_cloudformation_stack" "cvpn" {
  region        = local.region
  name          = local.cvpn_cloudformation_stack_name
  template_body = file("${local.cloudformation_path}/10-minute-aws-client-vpn.yaml")

  lifecycle {
    ignore_changes = [
      parameters["Enable"],
      # To turn the VPN on and off, toggle this parameter in CloudFormation,
      # not in Terraform.
    ]
  }

  iam_role_arn = (
    local.reference_endpoint_stack
    ? data.aws_iam_role.existing_cvpn_deploy[0]
    : data.aws_iam_role.cvpn_deploy[0]
  ).arn
  policy_body = (
    local.create_endpoint
    ? file("${local.cloudformation_path}/10-minute-aws-client-vpn-policy.json")
    : null
  )

  tags = merge(
    local.cvpn_tags,
    local.create_target_net_assoc ? var.cvpn_schedule_tags : {},
  )

  parameters = local.cvpn_params
}
