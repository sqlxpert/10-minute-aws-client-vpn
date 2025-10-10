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
  type        = map(any)
  description = "CloudFormation stack parameter map. Keys are parameter names from ../cloudformation/10-minute-aws-client-vpn.yaml ; parameters are described there. Required key: TargetSubnetIds , a list with 1 to 2 elements corresponding to TargetSubnetId and BackupTargetSubnetId . The 1st subnet determines the VPC. The 2nd subnet, if any, must be in that VPC. Ignored keys: Enable , VpcId , TargetSubnetId , BackupTargetSubnetId , ServerCertificateArn , ClientRootCertificateChainArn . If DestinationIpv4CidrBlock is not specified, the VPC's primary IPv4 CIDR block is used. For CustomClientSecGrpIds , groups not in the VPC will be ignored, potentially leading to an empty list and creation of the generic security groups. Do not set any values to null ."
}

variable "cvpn_schedule_tags" {
  type        = map(any)
  description = "Tag map specifically for the Client VPN CloudFormation stack. Keys, all optional, are tag keys. Values are tag values. This takes precedence over all other sources of tag information. If automatic scheduling is configured, set the sched-set-Enable-true and sched-set-Enable-false tags to schedule expressions. CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

  default = {
    "sched-set-Enable-true"  = "NA"
    "sched-set-Enable-false" = "NA"
  }
}

variable "cvpn_tags" {
  type        = map(any)
  description = "Map of tags for CloudFormation stacks and other AWS resources. Keys, all optional, are tag keys. Values are tag values. This takes precedence over the Terraform AWS provider's default_tags and over tags attributes defined by the module, if the same tag key appears here. To remove tags defined by the module, set the terraform and source tags to null . Do not set the sched-set-Enable-true or sched-set-Enable-false tags here. Warning: CloudFormation propagates stack tags to stack resources, and each AWS service may have different rules for tag key and tag value lengths, characters, and disallowed tag key or tag value contents. CloudFormation requires stack tag values to be at least 1 character long; empty tag values are not allowed."

  default = {}
}

variable "cvpn_region" {
  type        = string
  description = "Region code for the region in which to create CloudFormation stacks and other AWS resources. The empty string causes the module to use the default region configured for the Terraform AWS provider."

  default = ""
}
