# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
locals {
  caller_arn_parts = provider::aws::arn_parse(data.aws_caller_identity.current.arn)
  # Provider functions added in Terraform v1.8.0
  # arn_parse added in Terraform AWS provider v5.40.0

  partition = local.caller_arn_parts["partition"]

  region = coalesce(
    var.cvpn_region,
    data.aws_region.current.region
  )
  # data.aws_region.region added,
  # data.aws_region.name marked deprecated
  # in Terraform AWS provider v6.0.0

  cloudformation_path = "${path.module}/cloudformation"

  module_directory = basename(path.module)
  cvpn_tags = merge(
    {
      terraform = "1"
      source    = "github.com/sqlxpert/10-minute-aws-client-vpn/blob/main/${local.module_directory}"
      rights    = "GPLv3. Copyright Paul Marcelin."
      # CloudFormation stack tag values must be at least 1 character long!
      # https://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/API_Tag.html#API_Tag_Contents
    },
    var.cvpn_tags,
  )

  cvpn_scope              = var.cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"]
  create_target_net_assoc = ("VpnEndpointOnly" != local.cvpn_scope)
  create_endpoint         = ("VpcSubnetAssociationOnly" != local.cvpn_scope)
  reference_endpoint      = ("VpcSubnetAssociationOnly" == local.cvpn_scope)
  reference_endpoint_stack = (
    local.reference_endpoint && (var.cvpn_params["ExistingEndpointId"] == "")
  )

  cvpn_endpoint_cloudformation_stack_name = "CVpn${var.cvpn_stack_name_suffix}"

  cvpn_prereq_cloudformation_stack_name = "${local.cvpn_endpoint_cloudformation_stack_name}Prereq"

  subnet_id_number = trimprefix(var.cvpn_params["TargetSubnetId"], "subnet-")
  cvpn_cloudformation_stack_name = join("", [
    local.cvpn_endpoint_cloudformation_stack_name,
    local.reference_endpoint ? "Subnet${local.subnet_id_number}" : ""
  ])

  custom_client_security_group_ids_set = toset(
    local.create_endpoint
    ? var.cvpn_params["CustomClientSecGrpIds"]
    : []
  )
  custom_client_security_group_count = length(
    local.custom_client_security_group_ids_set
  )
}
