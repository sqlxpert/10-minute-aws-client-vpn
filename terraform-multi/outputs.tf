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
  count = try(aws_cloudformation_stack.cvpn.parameters["CustomClientSecGrpIds"], "") == "" ? 1 : 0
  # CustomClientSecGrpIds is a string in HCL, not a list; see above!

  name = join("/", [
    local.cvpn_ssm_param_path,
    aws_cloudformation_stack.cvpn.name,
    "ClientSecGrpId"
  ])
}
data "aws_security_group" "cvpn_client" {
  count = try(aws_cloudformation_stack.cvpn.parameters["CustomClientSecGrpIds"], "") == "" ? 1 : 0

  id = data.aws_ssm_parameter.cvpn_client_sec_grp_id[0].insecure_value
}
output "cvpn_client_sec_grp_id" {
  value       = try(data.aws_security_group.cvpn_client[0].id, null)
  description = "ID of the generic security group for Client VPN clients. Defined only if not custom security groups were supplied (see the CustomClientSecGrpIds CloudFormation stack parameter."
}



data "aws_ec2_client_vpn_endpoint" "cvpn" {
  tags = {
    Name = aws_cloudformation_stack.cvpn.name
    # "aws:cloudformation:stack-name" tag not yet available, as of 2025-10
  }
}
output "cvpn_endpoint_id" {
  value       = data.aws_ec2_client_vpn_endpoint.cvpn.client_vpn_endpoint_id
  description = "ID of the Client VPN endpoint. The self-service portal is not available, due to use of mutual TLS authentication. Download the VPN client configuration file using the AWS Console (VPC service) or the command-line interface: aws ec2 export-client-vpn-client-configuration --output text --client-vpn-endpoint-id 'cvpn-endpoint-00123456789abcdef'"
}
