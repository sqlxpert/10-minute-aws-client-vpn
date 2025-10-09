# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
locals {
  caller_arn_parts = provider::aws::arn_parse(data.aws_caller_identity.current.arn)
  account_id       = local.caller_arn_parts["account_id"]
  region           = data.aws_region.current.region

  cvpn_tags = merge(
    {
      terraform = "1"
      # CloudFormation stack tag values must be at least 1 character long!
      # https://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/API_Tag.html#API_Tag_Contents

      source = "https://github.com/sqlxpert/10-minute-aws-client-vpn/blob/main/terraform-multi"
    },
    var.cvpn_tags,
  )

  cvpn_ssm_param_path = "/cloudformation"
}
