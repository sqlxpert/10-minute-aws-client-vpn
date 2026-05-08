# AWS Client VPN
# github.com/sqlxpert/10-minute-aws-client-vpn  GPLv3  Copyright Paul Marcelin



# The CloudFormation template is self-contained. Resources that you might need
# to reference can be resolved from inputs that you provided; no stack outputs
# are needed.



# If you did not supply your own security group(s) for VPN clients, an AWS
# Systems Manager (SSM) Parameter Store parameter with a known name identifies
# the generic VPN client security group created for you. Unnecessary dependence
# on module outputs leaves Terraform configurations brittle; pre-defining
# security group(s) and passing them in lets you refer to them at any stage,
# dependency-free.

data "aws_ssm_parameter" "cvpn_client_sec_grp_id" {
  count = min(custom_client_security_group_count, 1)

  region = local.region
  name = join("/", [
    aws_cloudformation_stack.cvpn.parameters["SsmParamPath"],
    aws_cloudformation_stack.cvpn.name,
    "ClientSecGrpId"
  ])
}

data "aws_security_group" "cvpn_client" {
  count = min(custom_client_security_group_count, 1)

  region = local.region
  id     = data.aws_ssm_parameter.cvpn_client_sec_grp_id[0].insecure_value
}

output "cvpn_client_sec_grp_id" {
  value = try(data.aws_security_group.cvpn_client[0].id, null)

  description = "ID of the generic VPN client security group. Defined if no custom security groups (CustomClientSecGrpIds) were supplied and VpnEndpointAndOrVpcSubnetAssociation is not VpcSubnetAssociationOnly."
}



data "aws_ssm_parameter" "cvpn_client_vpn_endpoint_id" {
  count = local.create_endpoint ? 1 : 0

  region = local.region
  name = join("/", [
    aws_cloudformation_stack.cvpn.parameters["SsmParamPath"],
    aws_cloudformation_stack.cvpn.name,
    "EndpointId"
  ])
}

data "aws_ec2_client_vpn_endpoint" "cvpn" {
  count = local.create_endpoint ? 1 : 0

  region = local.region
  client_vpn_endpoint_id = (
    data.aws_ssm_parameter.cvpn_client_vpn_endpoint_id[0].insecure_value
  )
}

output "cvpn_endpoint_id" {
  value = try(
    data.aws_ec2_client_vpn_endpoint.cvpn[0].client_vpn_endpoint_id,
    null
  )

  description = "ID of Client VPN endpoint. Self-service portal is not available, due to use of mutual TLS authentication. AWS CLI: aws ec2 export-client-vpn-client-configuration --output text --client-vpn-endpoint-id 'cvpn-endpoint-00123456789abcdef'"
}
