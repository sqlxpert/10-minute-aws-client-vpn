# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin

# Reference resources not specific to the VPN by ID, because you might not have
# permission to tag shared, multi-purpose resources...



variable "cvpn_stack_name_suffix" {
  type        = string
  description = "Optional CloudFormation stack name suffix, for blue/green deployments or other scenarios in which multiple stacks created from the same template are needed in the same region, in the same AWS account."

  default = ""
}



locals {
  empty_set = toset([])

  cvpn_params_required_key_set = toset(
    [
      "TargetSubnetId",
    ]
  )

  cvpn_params_allowed_key_set = setunion(
    local.cvpn_params_required_key_set,
    toset([
      "BackupTargetSubnetId",
      "ClientIpv4CidrBlock",
      "ProtocolAndPort",
      "DestinationIpv4CidrBlock",
      "DnsServerIpv4Addr",
      "CustomClientSecGrpIds",
      "LogGroupPath",
      "CloudWatchLogsKmsKey",
      "LogsRetainDays",
      "SsmParamPath",
    ])
  )
}

variable "cvpn_params" {
  type = object({
    TargetSubnetId           = string
    BackupTargetSubnetId     = optional(string)
    ClientIpv4CidrBlock      = optional(string)
    ProtocolAndPort          = optional(string)
    DestinationIpv4CidrBlock = optional(string)
    DnsServerIpv4Addr        = optional(string)
    CustomClientSecGrpIds    = optional(list(string))
    LogGroupPath             = optional(string)
    CloudWatchLogsKmsKey     = optional(string)
    LogsRetainDays           = optional(string)
    SsmParamPath             = optional(string, "/cloudformation")
  })
  description = "VPN CloudFormation stack parameter map. Keys are parameter names from ../cloudformation/10-minute-aws-client-vpn.yaml ; parameters are described there. All values are strings unless otherwise noted. Required key: TargetSubnetId . Because the main subnet determines the VPC, VpcId is not allowed. If BackupTargetSubnetId is specified but the backup subnet is in a different VPC, it will be ignored. For CustomClientSecGrpIds , which in Terraform is a list of strings, custom security groups not in the VPC will be ignored, potentially leading to an empty list and creation of the generic security groups. If DestinationIpv4CidrBlock is not specified, the VPC's primary IPv4 CIDR block is used. Other optional keys: ClientIpv4CidrBlock , ProtocolAndPort , DnsServerIpv4Addr , LogGroupPath , CloudWatchLogsKmsKey and LogsRetainDays . Because certificates are identified by tag, ServerCertificateArn and ClientRootCertificateChainArn are not allowed."

  validation {
    error_message = join("", [

      "One or more required keys is missing: ",

      join(" , ", setsubtract(
        local.cvpn_params_required_key_set,
        toset(keys(var.cvpn_params))
      )),

      " ."
    ])

    condition = setsubtract(
      local.cvpn_params_required_key_set,
      toset(keys(var.cvpn_params))
    ) == local.empty_set
  }

  validation {
    error_message = join("", [

      "One or more extra keys is present: ",

      join(" , ", setsubtract(
        toset(keys(var.cvpn_params)),
        local.cvpn_params_allowed_key_set
      )),

      " . Review the variable's description."
    ])

    condition = setsubtract(
      toset(keys(var.cvpn_params)),
      local.cvpn_params_allowed_key_set
    ) == local.empty_set
  }
}



locals {
  cvpn_schedule_tags_key_set = toset([
    "sched-set-Enable-true",
    "sched-set-Enable-false"
  ])

  cvpn_schedule_tags_string = join(" and ", local.cvpn_schedule_tags_key_set)
}

variable "cvpn_schedule_tags" {
  type        = map(any)
  description = "Tag map specifically for the Client VPN CloudFormation stack. Keys, both optional, are tag keys. Values are tag values. This takes precedence over all other sources of tag information. If automatic scheduling is configured, set the sched-set-Enable-true and sched-set-Enable-false tags to schedule expressions. No other keys are allowed. Warning: CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed here."

  default = {
    "sched-set-Enable-true"  = "NA"
    "sched-set-Enable-false" = "NA"
  }

  validation {
    error_message = "CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

    condition = alltrue(
      [for value in values(var.cvpn_schedule_tags) : length(value) >= 1]
    )
  }

  validation {
    error_message = "Only the ${local.cvpn_schedule_tags_string} tags are allowed."

    condition = setsubtract(
      toset(keys(var.cvpn_schedule_tags)),
      local.cvpn_schedule_tags_key_set
    ) == local.empty_set
  }
}



variable "cvpn_tags" {
  type        = map(any)
  description = "Map of tags for CloudFormation stacks. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module. To remove tags defined by the module, set the terraform and source tags to null . Do not set the sched-set-Enable-true or sched-set-Enable-false tags here. Warnings: CloudFormation propagates stack tags to stack resources, and each AWS service may have different rules for tag key and tag value lengths, characters, and disallowed tag key or tag value contents. CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed here."

  default = {}

  validation {
    error_message = "CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

    condition = alltrue(
      [for value in values(var.cvpn_tags) : length(value) >= 1]
    )
  }

  validation {
    condition = setintersection(
      toset(keys(var.cvpn_tags)),
      local.cvpn_schedule_tags_key_set
    ) == local.empty_set

    error_message = "The ${local.cvpn_schedule_tags_string} tags must be set in cvpn_schedule_tags instead."
  }
}



variable "cvpn_region" {
  type        = string
  description = "Region code for the region in which to create CloudFormation stacks. The empty string causes the module to use the default region configured for the Terraform AWS provider."

  default = ""
}
