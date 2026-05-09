# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin



variable "cvpn_stack_name_suffix" {
  type        = string
  description = "Optional CloudFormation stack name suffix, for blue/green deployments or other scenarios in which multiple stacks created from the same template are needed in the same region, in the same AWS account."
  default     = ""
}



# You may wish to customize this interface, for example by omitting subnet ID,
# security group IDs, and the KMS key identifier in favor of looking up those
# resources based on tags (if you have permission to tag resources that are not
# dedicated to the VPN).

locals {
  cvpn_scopes_set = toset([
    "BothVpnEndpointAndVpcSubnetAssociation",
    "VpcSubnetAssociationOnly",
    "VpnEndpointOnly",
  ])

  cvpn_scopes_string = join(", ", local.cvpn_scopes_set)
}

variable "cvpn_params" {
  type = object({
    VpnEndpointAndOrVpcSubnetAssociation = optional(string, "BothVpnEndpointAndVpcSubnetAssociation")
    VpcId                                = optional(string, "")
    DestinationIpv4CidrBlock             = optional(string, "")
    ClientIpv4CidrBlock                  = optional(string, "10.255.252.0/22")

    TargetSubnetId = optional(string, "")

    SsmParamPath = optional(string, "/cloudformation")

    ProtocolAndPort        = optional(string, "udp 1194")
    CustomClientSecGrpIds  = optional(list(string), [])
    DnsServerIpv4Addresses = optional(list(string), [])

    RetentionInDays      = optional(number, 7)
    CloudWatchLogsKmsKey = optional(string, "")
    LogGroupPath         = optional(string, "/aws/vpc/clientvpn")

    ExistingEndpointId        = optional(string, "")
    ExistingEndpointStackName = optional(string, "CVpn")

    # Repeat defaults from cloudformation/10-minute-aws-client-vpn.yaml
  })
  description = "VPN CloudFormation stack parameter map. Keys are parameter names from cloudformation/10-minute-aws-client-vpn.yaml ; parameters are described there. Required key: TargetSubnetId , unless you set VpnEndpointAndOrVpcSubnetAssociation to VpnEndpointOnly , in which case VpcId is required. Do not specify VpcId with TargetSubnetId ; the latter determines the VPC. If DestinationIpv4CidrBlock is not specified, the VPC's primary IPv4 CIDR block is used. Not allowed: ServerCertificateArn , ClientRootCertificateChainArn , Enable , ExistingEndpointStackName . Certificates are identified by blank CVpnServer and CVpnClientRootChain tags. Enable is managed in CloudFormation. If VpnEndpointAndOrVpcSubnetAssociation is VpcSubnetAssociationOnly and ExistingEndpointId is blank, set cvpn_stack_name_suffix to the same value for all module instances and declare that each subnet association module instance depends_on the VPN endpoint module instance."

  validation {
    error_message = "The value of the VpnEndpointAndOrVpcSubnetAssociation map key is ${var.cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"]} but it must be one of: ${local.cvpn_scopes_string} ."

    condition = contains(
      local.cvpn_scopes_set,
      var.cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"]
    )
    # validation processing is not ordered, so repeat this condition hereafter
  }

  validation {
    error_message = "If you are creating a VPN endpoint only, specify a value for the VpcId map key, and no value for the TargetSubnetId map key."

    condition = (
      contains(
        local.cvpn_scopes_set,
        var.cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"]
      )
      && (
        (var.cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"] != "VpnEndpointOnly")
        || (
          (var.cvpn_params["VpcId"] != "")
          && (var.cvpn_params["TargetSubnetId"] == "")
        )
    ))
  }

  validation {
    error_message = "If you are creating a VPC subnet association, specify a value for the TargetSubnetId map key, and no value for the VpcId map key. The subnet determines the VPC."

    condition = (
      contains(
        local.cvpn_scopes_set,
        var.cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"]
      )
      && (
        (var.cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"] == "VpnEndpointOnly")
        || (
          (var.cvpn_params["TargetSubnetId"] != "")
          && (var.cvpn_params["VpcId"] == "")
        )
    ))
  }

  validation {
    error_message = "No more than 2 DNS servers may be specified for an AWS Client VPN endpoint."

    condition = (
      contains(
        local.cvpn_scopes_set,
        var.cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"]
      )
      && length(var.cvpn_params["DnsServerIpv4Addresses"]) <= 2
    )
  }
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
      for value in values(var.cvpn_schedule_tags) :
      try(length(value) >= 1, true)
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
  description = "Map of tags for CloudFormation stacks. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module. To remove tags defined by the module, set the terraform , source , and rights tags to null . Do not set the sched-set-Enable-true or sched-set-Enable-false tags here. Warnings: CloudFormation propagates stack tags to stack resources, and each AWS service may have different rules for tag key and tag value lengths, characters, and disallowed tag key or tag value contents. CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed here."

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
