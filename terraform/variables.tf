# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin

# Reference resources not specific to the VPN by ID, because you might not have
# permission to tag shared, multi-purpose resources...



variable "cvpn_stack_name_suffix" {
  type        = string
  description = "Optional CloudFormation stack name suffix, for blue/green deployments or other scenarios in which multiple stacks created from the same template are needed in the same region, in the same AWS account."

  default = ""
}



variable "cvpn_params" {
  type = object({
    TargetSubnetId           = string
    BackupTargetSubnetId     = optional(string, "")
    ClientIpv4CidrBlock      = optional(string, "10.255.252.0/22")
    ProtocolAndPort          = optional(string, "udp 1194")
    DestinationIpv4CidrBlock = optional(string, "")
    DnsServerIpv4Addr        = optional(string, "")
    CustomClientSecGrpIds    = optional(list(string), [])
    LogGroupPath             = optional(string, "/aws/vpc/clientvpn")
    CloudWatchLogsKmsKey     = optional(string, "")
    LogsRetainDays           = optional(number, 7)
    SsmParamPath             = optional(string, "/cloudformation")

    # Repeat defaults from ../cloudformation/10-minute-aws-client-vpn.yaml
  })
  description = "VPN CloudFormation stack parameter map. Keys are parameter names from ../cloudformation/10-minute-aws-client-vpn.yaml ; parameters are described there. Required key: TargetSubnetId . Because in Terraform the main subnet determines the VPC, VpcId is not allowed. If BackupTargetSubnetId is specified but that subnet is in a different VPC, no matching subnet will be found and an error will occur. For CustomClientSecGrpIds , custom security groups not in the VPC will be ignored, potentially leading to an empty list and creation of the generic security groups. If DestinationIpv4CidrBlock is not specified, the VPC's primary IPv4 CIDR block is used. Other optional keys: ClientIpv4CidrBlock , ProtocolAndPort , DnsServerIpv4Addr , LogGroupPath , CloudWatchLogsKmsKey , LogsRetainDays and SsmParamPath . Because certificates are identified by tag, ServerCertificateArn and ClientRootCertificateChainArn are not allowed."
}



variable "cvpn_schedule_tags" {
  type = object({
    sched-set-Enable-true  = optional(string)
    sched-set-Enable-false = optional(string)
  })
  description = "Tag map specifically for the VPN CloudFormation stack. Keys, both optional, are tag keys. Values are tag values. This takes precedence over all other sources of tag information. If automatic scheduling is configured, set the sched-set-Enable-true and sched-set-Enable-false tags to schedule expressions. No other keys are allowed. Warning: CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed here."

  default = {}

  validation {
    error_message = "CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

    condition = alltrue([
      for value in values(var.cvpn_tags) : try(length(value) >= 1, true)
    ])
    # Use try to guard against length(null) . Allowing null is necessary here
    # as a means of preventing the setting of a given tag. The more explicit:
    #   (value == null) || (length(value) >= 1)
    # does not work with versions of Terraform released before 2024-12-16.
    # Error: Invalid value for "value" parameter: argument must not be null.
    # https://github.com/hashicorp/hcl/pull/713
  }
}



locals {
  cvpn_schedule_tags_key_set = toset([
    "sched-set-Enable-true",
    "sched-set-Enable-false"
  ])

  cvpn_schedule_tags_string = join(" and ", local.cvpn_schedule_tags_key_set)
}

variable "cvpn_tags" {
  type        = map(string)
  description = "Map of tags for CloudFormation stacks. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module. To remove tags defined by the module, set the terraform and source tags to null . Do not set the sched-set-Enable-true or sched-set-Enable-false tags here. Warnings: CloudFormation propagates stack tags to stack resources, and each AWS service may have different rules for tag key and tag value lengths, characters, and disallowed tag key or tag value contents. CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed here."

  default = {}

  validation {
    error_message = "CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

    condition = alltrue([
      for value in values(var.cvpn_tags) : try(length(value) >= 1, true)
    ])
    # See length(null) comment, above
  }

  validation {
    condition = length(setintersection(
      toset(keys(var.cvpn_tags)),
      local.cvpn_schedule_tags_key_set
    )) == 0

    error_message = "The ${local.cvpn_schedule_tags_string} tags must be set in cvpn_schedule_tags instead."
  }
}



variable "cvpn_region" {
  type        = string
  description = "Region code for the region in which to create CloudFormation stacks. The empty string causes the module to use the default region configured for the Terraform AWS provider."

  default = ""
}
