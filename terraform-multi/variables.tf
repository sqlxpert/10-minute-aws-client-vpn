# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin

# Reference resources not specific to the VPN by ID, because you might not have
# permission to tag shared, multi-purpose resources...

variable "accounts_to_regions_to_cvpn_params" {
  type        = map(any)
  description = "Nested map. Outer keys: account number strings, or CURRENT_AWS_ACCOUNT for any one. Intermediate keys: region code strings such as us-west-2 , or CURRENT_AWS_REGION for any one. Required inner key: TargetSubnetIds , a list with 1 to 2 elements. The 1st subnet determines the VPC, and any other inputs must be in that VPC. Optional inner keys: DestinationIpv4CidrBlock , DnsServerIpv4Addr , ClientIpv4CidrBlock , CustomClientSecGrpIds (groups not in the same VPC as the 1st subnet will be ignored, potentially leading to an empty list and creation of the generic security groups), and schedule_tags . If DestinationIpv4CidrBlock is not specified, the VPC's primary IPv4 CIDR block is used. Keys mentioned above correspond to CloudFormation stack parameters. If automatic scheduling is configured, set schedule expressions by adding schedule_tags , a map with keys sched-set-Enable-true and sched-set-Enable-false ."

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

variable "cvpn_tags" {
  type        = map(any)
  description = "CloudFormation stack tag map. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module, if the same tag key appears here. To remove tags defined by the module, set the terraform and source tags to null . If automatic scheduling is configured, set the sched-set-Enable-true and sched-set-Enable-false tags to schedule expressions that will apply in all regions and all AWS accounts (otherwise, see the accounts_to_regions_to_cvpn_params variable). Warning: CloudFormation propagates stack tags to stack resources, and each AWS service may have different rules for tag key and tag value lengths, characters, and disallowed tag key or tag value contents. CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

  default = {}
}

variable "cvpn_cloudwatch_logs_kms_key" {
  type        = string
  description = "If not set, default non-KMS CloudWatch Logs encryption applies. See the CloudWatchLogsKmsKey CloudFormation stack parameter."

  default = null
}

variable "cvpn_stack_name_suffix" {
  type        = string
  description = "Optional CloudFormation stack name suffix, for blue/green deployments or other scenarios in which multiple stacks created from the same template are needed in the same region, in the same AWS account."

  default = ""
}
