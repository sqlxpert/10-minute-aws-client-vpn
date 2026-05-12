# 10-Minute AWS Client VPN

## Goals

This CloudFormation template (+&nbsp;optional Terraform module) helps you set
up a complete
[AWS-managed VPN](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/what-is.html)
in about 10&nbsp;minutes and operate it for as little as
$1.45&nbsp;per&nbsp;work&nbsp;day.

How the template minimizes costs:

 1. [Split-tunneling](https://en.wikipedia.org/wiki/Split_tunneling).
    Only AWS private network (VPC) traffic uses the VPN.
 2. Reduced redundancy. Access
    [all availability zones in the region through one](https://aws.amazon.com/about-aws/whats-new/2022/04/aws-data-transfer-price-reduction-privatelink-transit-gateway-client-vpn-services).
 3. Optional night and weekend shutdowns with
    [github.com/sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#bonus-delete-and-recreate-expensive-resources-on-a-schedule)&nbsp;.

    <details>
      <summary>Savings...</summary>

    ---

    ||Price|Hours|Hours|Cost|
    |:---|---:|---:|---:|---:|
    |**&darr;&nbsp;Usage / Period&nbsp;&rarr;**|1&nbsp;hour|7&nbsp;days|365&nbsp;days|365&nbsp;days|
    |**Always on:**|||||
    |1&nbsp;VPC&nbsp;subnet&nbsp;associated|10.0¢|168|8,760|$876|
    |1 VPN user connected|5.0¢|40|2,080|$104|
    |1 public IPv4 address|0.5¢|40|2,080|$10|
    |_Total_||||$990|
    |**Work hours only:**|||||
    |1 VPC subnet associated|10.0¢|**50**|**2,607**|**$261**|
    |1 VPN user connected|5.0¢|40|2,080|$104|
    |1 public IPv4 address|0.5¢|40|2,080|$10|
    |_Total_||||**$375**|

    $990 &minus; $375
    = $615
    &thickapprox; $600 **saved** per year.

    $375 &div; (52&nbsp;weeks &times; 5&nbsp;work&nbsp;days)
    = $375 &div; 260&nbsp;work&nbsp;days
    &thickapprox; $1.45&nbsp;**spent**&nbsp;per&nbsp;work&nbsp;day.

    For each additional VPN user who connects full-time, **add** approximately
    $115&nbsp;per&nbsp;year
    or
    $115 &div; 260&nbsp;work&nbsp;days
    = 45¢&nbsp;per&nbsp;work&nbsp;day.

    >[AWS Client VPN prices](https://aws.amazon.com/vpn/pricing/#AWS_Client_VPN_pricing)
    in the `us-east-1` region were checked in May,&nbsp;2026 but can change
    at any time.
    [Public IPv4 address charges](https://aws.amazon.com/vpc/pricing#:~:text=Public%20IPv4%20Address)
    also apply
    [as of February,&nbsp;2024](https://aws.amazon.com/about-aws/whats-new/2024/02/aws-free-tier-750-hours-free-public-ipv4-addresses).
    If a VPC is shared, some charges are billed to the AWS account that owns
    the VPC. NAT gateway, data transfer, CloudWatch, and other charges may also
    apply.

    ---

    </details>

Jump to:
**[Installation](#quick-installation)
&bull;
[Scheduling](#automatic-scheduling)
&bull;
[Terraform](#terraform-details)**

<details>
  <summary>Rationale for connecting to AWS with a VPN</summary>

---

"Zero-trust" proponents correctly discourage relying on the strength of the
perimeter around your private network, but sometimes, perimeter security _is_
the available defense, and a virtual private network connection is necessary.
For example, to access an AWS Elastic File System (EFS) volume from your local
computer, you must use a VPN, so that the Network File System (NFS) client
connection originates _inside_ your AWS Virtual Private Cloud (VPC). NFS server
software was not designed for exposure to the public Internet.

---

</details>

<details>
  <summary>Transit Gateway alternative</summary>

---

Since late April,&nbsp;2026, it's been possible to associate an AWS Client VPN
with a Transit Gateway for easy access to multiple private networks. That's an
exciting
[announcement](https://aws.amazon.com/about-aws/whats-new/2026/04/aws-client-vpn-transit-gateway),
but my 10-minute VPN continues to support direct association with a VPC. Not
only is one VPN, one VPC the right level of complexity for most people, but a
Transit Gateway association and its routes would be long-lived properties,
making nightly VPN shutdowns impractical.

---

</details>

>&#128274; Software supply chain security is on everyone's mind. This solution
contains no executable code. I made GitHub releases immutable as of
`v4.1.2`&nbsp;. For security awareness, I provide links to release notes for
the software you'll use to generate certificates and connect.
>
>The VPN lets clients with the certificate you specify access the private
network you specify. The included security group pair demonstrates a critical
AWS network security practice: allowing traffic from a specific, named security
group rather than from arbitrary private IP addresses. You can supply custom
security groups. For additional security options, you can create the VPN
endpoint separately and integrate it with this solution.

## Quick Installation

>Certificate creation is faster than it looks. To avoid errors, read each step
completely before doing it. You will have to switch between this ReadMe file
and AWS's documentation.
>
>[AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
works well for setup, but move your certificate authority (and your Terraform
state file, if applicable), due to the
[120-day retention limit](https://docs.aws.amazon.com/cloudshell/latest/userguide/limits.html#:~:text=After%20120%20days,automatically%20deleted).

 1. Create the VPN certificate(s) by following AWS's
    [mutual authentication steps](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-auth-mutual-enable.html).

    - &#9888; Check release notes for the version of
      [github.com/OpenVPN/easy-rsa](https://github.com/OpenVPN/easy-rsa/releases)
      that you will use. As of 2026-05-12, the latest release was `v3.2.6`
      (2026-03-13) and OpenVPN had not enabled immutable releases; a careful
      release integrity check is necessary. Also check industry security
      bulletins.

    - Copy the _individual_ Linux/macOS commands and execute them verbatim.

    - Copy and edit the
      [block of commands](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-auth-mutual-enable.html#:~:text=command.-,The%20following,in%20your%20home%20directory.)
      before executing them together. If only AWS's technical writers had
      chosen a plausible folder name instead of a placeholder! Keep
      `custom_folder` for now, but after the `mkdir` line, insert:

      ```shell
      chmod go= ~/custom_folder
      ```

    - After uploading the first (server) certificate, copy the ARN returned by
      AWS Certificate Manager.

    - Uploading the second (client) certificate is completely optional.

 2. &#9888; **Tag the VPN
    [certificate(s)](https://console.aws.amazon.com/acm/certificates/list)
    if you are using Terraform.** If you are not using a separate client
    certificate, apply both tags to the _server_ certificate.

    ```shell
    aws acm add-tags-to-certificate --tags 'Key=CVpnServer,Value=' --certificate-arn 'SERVER_CERT_ARN'
    aws acm add-tags-to-certificate --tags 'Key=CVpnClientRootChain,Value=' --certificate-arn 'CLIENT_CERT_ARN'
    ```

 3. Install the Client VPN CloudFormation stack using CloudFormation or
    Terraform.

    - **CloudFormation**<br/>_Easy_ &check;

      [Create a CloudFormation stack](https://console.aws.amazon.com/cloudformation/home#/stacks/create).

      Select "Upload a template file", then select "Choose file" and navigate
      to a locally-saved copy of
      [cloudformation/10-minute-aws-client-vpn.yaml](/../../blob/v5.0.0/cloudformation/10-minute-aws-client-vpn.yaml?raw=true)
      [right-click to save as...].

      - Name the stack `CVpn`&nbsp;.

      - The parameters are thoroughly documented. Set _all_ "Required" ones.
        For reference, find your VPC in the list of
        [VPCs](https://console.aws.amazon.com/vpcconsole/home#vpcs:).

      - Under "Additional settings" &rarr; "Stack policy - optional", you can
        "Upload a file" and select a locally-saved copy of
        [cloudformation/10-minute-aws-client-vpn-policy.json](/../../blob/v5.0.0/cloudformation/10-minute-aws-client-vpn-policy.json?raw=true)
        [right-click to save as...]. The stack policy prevents replacement or
        deletion of certain resources during stack updates, producing an error
        if you attempt
        [parameter updates](#parameter-updates)
        that are not supported.

    - **Terraform**

      Check that you have at least:

      - [Terraform v1.10.0 (2024-11-27)](https://github.com/hashicorp/terraform/releases/tag/v1.10.0)
      - [Terraform AWS provider v6.0.0 (2025-06-18)](https://github.com/hashicorp/terraform-provider-aws/releases/tag/v6.0.0)

      Add the following child module to your existing root module:

      ```terraform
      module "cvpn" {
        source = "git::https://github.com/sqlxpert/10-minute-aws-client-vpn.git//terraform?ref=v5.0.0"
        # Reference a specific version from github.com/sqlxpert/10-minute-aws-client-vpn/releases
        # Check that the release is immutable!

        cvpn_params = {
          TargetSubnetId = "subnet-10123456789abcdef"
        }
      }
      ```

      Just specify the ID of a subnet in the desired VPC.

      Have Terraform download the module's source code. Review the plan before
      typing `yes` to allow Terraform to proceed with applying the changes.

      ```shell
      terraform init
      terraform apply
      ```

      &#9888; **Turn on the VPN** by changing the `Enable` parameter of the
      `CVpn`
      [CloudFormation stack](https://console.aws.amazon.com/cloudformation/home#/stacks?filteringStatus=active&filteringText=CVpn&viewNested=true)
      to `true`. The Terraform module leaves the VPN off at first and then
      ignores changes to `cvpn_params["Enable"]` so that CloudFormation can
      manage it, potentially
      [unattended](#automatic-scheduling)
      and with
      [limited permissions](#separating-the-vpn-endpoint-from-the-vpc-subnet-associations).

 4. Follow
    [Step&nbsp;8 of AWS's Getting Started document](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-getting-started.html#cvpn-getting-started-config).

    - Find your VPN in the list of
      [Client VPN endpoints](https://console.aws.amazon.com/vpcconsole/home#ClientVPNEndpoints:)
      in the AWS Console and download the configuration file from there.

    - `cd` to the directory where you downloaded the file and:

      ```shell
      chmod go= downloaded-client-config.ovpn
      ```

    - Open the file in your preferred editor, copy the skeleton from
      [AWS's instructions](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-getting-started.html#:~:text=editor.-,Add,to%20the%20file.)
      and paste it at the end of the file, then replace the text between the
      tags with the contents of the
      `~/custom_folder/client1.domain.tld.crt` certificate and
      `~/custom_folder/client1.domain.tld.key` key files.

    - Rename `~/custom_folder` and note that you must also continue to protect
      `easy-rsa/easyrsa3/pki` and `downloaded-client-config.ovpn`&nbsp;. All
      three contain copies of your key.

 5. Download either the
    [OpenVPN](https://openvpn.net)
    client (Resources &rarr; Download OpenVPN)
    or the
    [AWS client](https://aws.amazon.com/vpn/client-vpn-download).

    &#9888; Check
    [OpenVPN Connect release notes](https://openvpn.net/connect-docs/release-notes.html)
    or AWS client
    [Linux](https://docs.aws.amazon.com/vpn/latest/clientvpn-user/client-vpn-connect-linux-release-notes.html),
    [macOS](https://docs.aws.amazon.com/vpn/latest/clientvpn-user/client-vpn-connect-macos-release-notes.html),
    or
    [Windows](https://docs.aws.amazon.com/vpn/latest/clientvpn-user/client-vpn-connect-windows-release-notes.html)
    release notes, plus relevant industry security bulletins.

 6. Import your edited configuration file to the client.

 7. Use the client to connect to the VPN.

 8. Add `FromClientSampleSecGrp` to an
    [EC2 instance](https://console.aws.amazon.com/ec2/home#Instances:).

    If you do not use SSH, create and add a security group that accepts traffic
    from VPN clients on the port of your choice.

 9. Test. On your local computer, run:

    ```shell
    ssh -i PRIVATE_KEY_FILE ec2-user@IP_ADDRESS
    ```

    where _PRIVATE_KEY_FILE_ is the path to the private key for the instance's
    SSH key pair, and _IP_ADDRESS_ is the instance's **private** IPv4 address.

    Different operating system images have different
    [default usernames](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connection-prereqs-general.html#:~:text=Get%20the%20default%20username);
    `ec2-user` is not always correct!

    If you do not use SSH, run a different command to test VPN connectivity.

10. Remove `FromClientSampleSecGrp` (or equivalent) from you EC2 instance.

## Automatic Scheduling

Turning the VPN off at night and on weekends and back on at the start of each
work day saves $600 per year. See the table in Item&nbsp;3 of the
[goals](#goals).
For a VPN needed strictly on-demand, you could schedule a daily end-of-day
shutdown or a weekly end-of-week shutdown but no automatic startup.

<details>
  <summary>To turn the VPN on and off on a schedule...</summary>

<br/>

 1. If you used Terraform above,
    [skip to Automatic Scheduling Step&nbsp;2](#automatic-scheduling-step-2).

    If you used CloudFormation...

    - [Create a stack](https://console.aws.amazon.com/cloudformation/home#/stacks/create)
      from a locally-saved copy of
      [cloudformation/10-minute-aws-client-vpn-prereq.yaml](/../../blob/v5.0.0/cloudformation/10-minute-aws-client-vpn-prereq.yaml?raw=true)
      [right-click to save as...].

    - Name this stack `CVpnPrereq`&nbsp;.

    - Under "Additional settings" &rarr; "Stack policy - optional", you can
      "Upload a file" and select a locally-saved copy of
      [cloudformation/10-minute-aws-client-vpn-prereq-policy.json](/../../blob/v5.0.0/cloudformation/10-minute-aws-client-vpn-prereq-policy.json?raw=true)
      [right-click to save as...]. The stack policy prevents inadvertent
      replacement or deletion of the deployment roles during stack updates,
      but it cannot prevent deletion of the entire `CVpnPrereq` stack.

    - Update your `CVpn`
      [CloudFormation stack](https://console.aws.amazon.com/cloudformation/home#/stacks?filteringStatus=active&filteringText=CVpn&viewNested=true),
      changing nothing until you reach the "Configure stack options" page, on
      which you will set "IAM role - optional" to
      `CVpnPrereq-DeploymentRole`&nbsp;. You are delegating privileges with a
      [CloudFormation service role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-servicerole.html).

      If your own privileges are limited, you might need explicit permission to
      _pass_ the role to CloudFormation. See the
      `CVpnPrereq-SampleDeploymentRolePassRolePol` sample
      [IAM policy](https://console.aws.amazon.com/iam/home#/policies).

 2. <a name="automatic-scheduling-step-2"></a>[Install Lights Off](https://github.com/sqlxpert/lights-off-aws#quick-start).

 3. Update your `CVpn`
    [CloudFormation stack](https://console.aws.amazon.com/cloudformation/home#/stacks?filteringStatus=active&filteringText=CVpn&viewNested=true),
    adding the following stack-level tags:

    - `sched-set-Enable-true` : `u=1 u=2 u=3 u=4 u=5 H:M=11:00`
    - `sched-set-Enable-false` : `u=2 u=3 u=4 u=5 u=6 H:M=01:00`

    In Terraform, set the following variable inside your `module` block:

    ```terraform
      cvpn_schedule_tags = {
        sched-set-Enable-true  = "u=1 u=2 u=3 u=4 u=5 H:M=11:00"
        sched-set-Enable-false = "u=2 u=3 u=4 u=5 u=6 H:M=01:00"
      }
    ```

    Adjust the weekdays and the times based on your work schedule. The example
    is for the mainland portions of the United States and Canada.

    - `u=1` is Monday and `u=5` is Friday, per
      [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601#Week_dates).
    - Times are in Universal Coordinated Time (UTC), which matches the local
      time in London, England during the winter. The
      [timeanddate.com](https://www.timeanddate.com/worldclock/converter.html?iso=20260501T110000&p1=224&p2=250&p3=1440&p4=37&p5=44)
      converter is helpful.
    - UTC has no provision for Daylight Saving Time/Summer Time. Leave a
      buffer at the end of your work day to avoid having to switch schedules.

 4. Find your VPN in the list of
    [Client VPN endpoints](https://console.aws.amazon.com/vpc/home#ClientVPNEndpoints:search=ClientVpnEndpoint)
    in the AWS Console and check that its "Target network associations" are
    being created and deleted as scheduled. Check actual costs after a few
    days, and set up alerts with
    [AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html).
    Keep in mind that if a VPC is shared, some charges are billed to the AWS
    account that owns the VPC.

</details>

## Parameter Updates

You can toggle the `Enable` parameter (always in
[CloudFormation](https://console.aws.amazon.com/cloudformation/home#/stacks?filteringStatus=active&filteringText=CVpn&viewNested=true),
never from Terraform) to turn the VPN on and off. This has no effect if
`VpnEndpointAndOrVpcSubnetAssociation` is `VpnEndpointOnly`&nbsp;.

You can switch from generic _to_ custom VPN client security groups, change (but
not empty) the list of custom security group IDs, and change the connection log
retention period. These settings have no effect if
`VpnEndpointAndOrVpcSubnetAssociation` is `VpcSubnetAssociationOnly`&nbsp;.

Do not try to change the VPC, the IP address ranges, the name paths, or any
other parameters after the `CVpn` stack has been created. Instead, create a
`CVpn2` stack (in Terraform, create a new module instance with
`cvpn_stack_name_suffix = "2"`&nbsp;), then update the _remote_ line of
your client configuration file and re-import the configuration file to your VPN
client utility.

## Separating the VPN Endpoint from the VPC Subnet Associations

You can use the Terraform wrapper module and/or the CloudFormation template to
create a complete AWS Client VPN from scratch, but it's also possible to create
separate Terraform module instances and/or CloudFormation stacks for the VPN
endpoint and each VPC subnet association. Separation increases flexibility and
security.

<details>
  <summary>Separation details...</summary>

<br/>

### VPN Endpoint

Set `VpnEndpointAndOrVpcSubnetAssociation` to `VpnEndpointOnly` for
the first CloudFormation stack or Terraform module instance. The CloudFormation
stack is named `CVpn`&nbsp;. This stack should not have `sched-set-Enable-true`
and `sched-set-Enable-false` tags.

Or, create the VPN endpoint using any CloudFormation template, Terraform
module or other system that you like! Creating your own VPN endpoint gives you
the freedom to customize IPv6 support, authentication, network authorization
rules, the banner message, and other properties.

AWS's
[quick start](https://console.aws.amazon.com/vpcconsole/home#CreateClientVpnEndpoint:createMode=QUICKSTART),
which was
[introduced](https://aws.amazon.com/about-aws/whats-new/2026/01/aws-client-vpn-onboarding-quickstart-setup)
in January,&nbsp;2026, is quite helpful for configuring Client VPN, though it
can't guide you through certificate creation.

### VPC Subnet Association

Set `VpnEndpointAndOrVpcSubnetAssociation` to `VpcSubnetAssociationOnly` for
each additional CloudFormation stack or Terraform module instance. These stacks
are named `CVpn` plus distinguishing suffixes. These stacks may have
`sched-set-Enable-true` and `sched-set-Enable-false` tags. Unless you set
`ExistingEndpointId` directly, each VPC subnet association stack automatically
references the AWS Systems Manager (SSM) Parameter Store parameter created by
the VPN endpoint stack. Change `ExistingEndpointStackName` if that stack's name
is other than `CVpn`&nbsp;. In Terraform, make sure that all module instances
share the same `cvpn_stack_name_suffix` value. There is no stack policy, and
no need for one.

If you configure
[automatic scheduling](#automatic-scheduling),
a very-low-privilege CloudFormation service role is provided for
`VpcSubnetAssociationOnly` stacks. CloudFormation can use this role only to
create and delete associations between a VPN endpoint and VPC subnets. The role
cannot be used to create, tag, modify, or delete the VPN endpoint, security
groups, or any other resource types. In CloudFormation, set
"IAM role - optional" to `CVpnPrereq-OperationRole` instead of
`CVpnPrereq-DeploymentRole` if `VpnEndpointAndOrVpcSubnetAssociation` is
`VpcSubnetAssociationOnly`&nbsp;. The Terraform module selects the appropriate
role automatically.

Keep in mind that one VPC subnet association grants access to network resources
in all of the VPC's availability zones. Additional subnet associations, each of
which must cover a different availability zone, provide network redundancy at
an extra cost. See the table in Item&nbsp;3 of the
[goals](#goals).

### Separation in Terraform

See
[Separate Terraform Module Instances](#separate-terraform-module-instances),
below.

</details>

## Terraform Details

### Terraform Module Outputs

|Output|Original Resource and Attribute|
|:---|:---|
||**Matching Data Source and Argument**|
|`module.cvpn.cvpn_endpoint_id`|[`aws_ec2_client_vpn_endpoint`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_endpoint).[`id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_endpoint#id-1)|
||[`data.aws_ec2_client_vpn_endpoint`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_client_vpn_endpoint).[`client_vpn_endpoint_id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_client_vpn_endpoint#client_vpn_endpoint_id-1)|
|`module.cvpn.cvpn_client_sec_grp_id`|[`aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group.html).[`id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group.html#id-1)|
||[`data.aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group).[`id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group#id-1)|

Neither output is available if
`cvpn_params["VpnEndpointAndOrVpcSubnetAssociation"]` is
`VpcSubnetAssociationOnly`&nbsp;.

The VPN client security group is not available if
`cvpn_params["CustomClientSecGrpIds"]` is set.

To accept traffic from VPN clients, reference
`module.cvpn.cvpn_client_sec_grp_id` in:

- [`aws_vpc_security_group.`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group).[`ingress`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group#ingress).[`security_groups`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group#security_groups-1)
- [`aws_vpc_security_group_ingress_rule`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule).[`referenced_security_group_id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule#referenced_security_group_id-1)

### Separate Terraform Module Instances

<details>
  <summary>Separate VPN endpoint and VPC subnet association module instances...</summary>

<br/>

As explained above in
[Separating the VPN Endpoint from the VPC Subnet Associations](#separating-the-vpn-endpoint-from-the-vpc-subnet-associations),
creating separate module instances for the VPN endpoint and each VPC subnet
association increases flexibility and security.

```terraform
locals {
  cvpn_stack_name_suffix = "" # Set to "2" for a blue/green VPN deployment
}

module "cvpn" {
  source = "git::https://github.com/sqlxpert/10-minute-aws-client-vpn.git//terraform?ref=v5.0.0"
  # Reference a specific version from github.com/sqlxpert/10-minute-aws-client-vpn/releases
  # Check that the release is immutable!

  cvpn_stack_name_suffix = local.cvpn_stack_name_suffix
  cvpn_params = {
    VpnEndpointAndOrVpcSubnetAssociation = "VpnEndpointOnly"
    VpcId                                = "vpc-00123456789abcdef"
    # Specify VpcId for VpnEndpointOnly, TargetSubnetId otherwise!
  }
}

module "cvpn_subnets" {
  source = "git::https://github.com/sqlxpert/10-minute-aws-client-vpn.git//terraform?ref=v5.0.0"
  # Reference a specific version from github.com/sqlxpert/10-minute-aws-client-vpn/releases
  # Check that the release is immutable!

  depends_on = [module.cvpn]

  for_each = {
    # Key: availability zone ID (same physical zone, across all AWS accounts)
    usw2-az1 = {
      TargetSubnetId = "subnet-10123456789abcdef"
    }
    usw2-az2 = {
      TargetSubnetId = "subnet-20123456789abcdef"
      # Optional:
      sched-set-Enable-true  = "u=1 u=2 u=3 u=4 u=5 H:M=11:00"
      sched-set-Enable-false = "u=2 u=3 u=4 u=5 u=6 H:M=01:00"
    }
  }

  cvpn_stack_name_suffix = local.cvpn_stack_name_suffix
  cvpn_params = {
    VpnEndpointAndOrVpcSubnetAssociation = "VpcSubnetAssociationOnly"
    TargetSubnetId                       = each.value["TargetSubnetId"]
  }

  cvpn_schedule_tags = {
    sched-set-Enable-true  = lookup(each.value, "sched-set-Enable-true", null)
    sched-set-Enable-false = lookup(each.value, "sched-set-Enable-false", null)
  } # Optional, and schedules need not be the same for all subnet associations
}
```

</details>

### Creating Certificates in Terraform

To automate certificate creation, consider third-party modules such as:

- [ssm-tls-self-signed-cert](https://registry.terraform.io/modules/cloudposse/ssm-tls-self-signed-cert/aws/latest)
- [serverless-ca](https://registry.terraform.io/modules/serverless-ca/ca/aws/latest)

### Terraform Permissions

<details>
  <summary>If you run Terraform with least-privilege permissions...</summary>

<br/>

If you do not give Terraform full AWS administrative permissions, you must give
it permission to:

- List, describe, get tags for, create, tag, update, untag and delete
  IAM roles, update the "assume role" (role trust or "resource-based")
  policy, and put and delete in-line policies
- List, describe, create, tag, update, untag, and delete CloudFormation
  stacks
- Set and get CloudFormation stack policies
- Pass `CVpnPrereq-DeploymentRole-*` and `CVpnPrereq-OperationRole-*` to
  CloudFormation
- List, describe, and get tags for, all `data` sources. For a list, run:

  ```shell
  grep 'data "' terraform*/*.tf | cut --delimiter=' ' --fields='1,2'
  ```

Open the
[AWS Service Authorization Reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html#actions_table),
go through the list of services on the left, and consult the "Actions" table
for each of:

- `AWS Identity and Access Management (IAM)`
- `CloudFormation`
- `AWS Security Token Service`
- `Amazon EC2`
- `AWS Certificate Manager`
- `AWS Systems Manager`
- `AWS Key Management Service` (if you encrypt the CloudWatch log group with a
  KMS key)

In most cases, you can scope Terraform's permissions to one workload by
regulating resource naming and tagging, and then by using:

- [ARN patterns in `Resource` lists](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_resource.html#reference_policies_elements_resource_wildcards)
- [ARN patterns in `Condition` entries](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition_operators.html#Conditions_ARN)
- [Request tag and then resource tag `Condition` entries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_tags.html)

Check Service and Resource Control Policies (SCPs and RCPs), as well as
resource policies (such as KMS key policies).

The deployment roles defined in the `CVpnPrereq` stack give CloudFormation the
permissions it needs to create the `CVpn` or `CVpnSubnet` stack. Terraform
itself does not need a deployment role's permissions.

</details>

### Why Mix Terraform and CloudFormation?

<details>
  <summary>Getting the best of the two leading IaC systems for AWS...</summary>

<br/>

As an individual open-source developer I get mere seconds of a potential new
user's attention. To reach everybody, I initially distributed my open-source
AWS tools as CloudFormation templates. All AWS users have immediate access,
with no infrastructure-as-code software to install, no Terraform state files to
store, and no extra permissions (see below) and credentials to worry about.

Because most of my software is multi-region and multi-account, writing
templates that also work as
[CloudFormation Stack*Sets*](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-concepts.html#stacksets-concepts-stackset)
makes deployment from a central region and AWS account to many regions and AWS
accounts easy for my users. Terraform gained practical
[multi-region support](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/enhanced-region-support)
only in v6 of the Terraform AWS provider, released mid-2025. It will be _years_
before clumsy provider aliases disappear and existing code and third-party
modules are updated to propagate the `region` attribute so that Terraform users
can deploy a module with `for_each` over a straightforward set of regions.

As of mid-2026, Terraform still lacks a standard mechanism for deploying to
multiple AWS accounts. People have been talking about this
[since at least 2019](https://discuss.hashicorp.com/t/structuring-terraform-for-multi-account-aws-modular-resource-management-with-cross-account-access/77271).
I could not well expect my users to install Terraform plus third-party
Terraform tooling, and to adopt a complex file layout, just to install my
lightweight software in multiple AWS accounts! Instead,
[I accomplished it](https://github.com/sqlxpert/aws-tag-sched-ops/blob/101efe7/cloudformation/aws_tag_sched_ops_pre_install.yaml)
with CloudFormation StackSets right after the feature was released,
[in 2017](https://aws.amazon.com/blogs/mt/aws-cloudformation-2017-in-review)!

Last but not least,
[CloudFormation service roles](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-servicerole.html)
allow for delegation of fine-grained permissions. A property of each
CloudFormation stack, the service role is recognized by CloudFormation. In this
VPN solution, a CloudFormation service role makes it possible for cost-bearing
VPC subnet associations to be deleted and recreated unattended, with no
infrastructure-as-code software installed.

I added Terraform support to all of my open-source software tools from 2025 to
2026, to increase adoption. I usually wrap either a CloudFormation stack or
StackSet in HashiCorp Configuration Language. Where the basis is a third
language, such as the IAM policy language, I can provide native Terraform
alongside CloudFormation without too much duplication of effort.

Where Terraform shines is dynamic resource lookups. _My_ CloudFormation wrapper
modules aren't passive; the Terraform code isn't an afterthought. I add data
sources to reduce the number of required inputs and to validate the inputs, in
ways that are not possible out-of-the-box with CloudFormation. (Defining
[custom CloudFormation resources](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-custom-resources.html#how-custom-resources-work)
should be a last resort. It's a gravy train for unscrupulous consultants. I
avoid even
[CloudFormation language transforms](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/transform-aws-languageextensions.html),
which are AWS's cheap way of grafting-on features that belong in the core
language. Because they work like pre-processors,
[CloudFormation language transforms would wreck](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/transform-aws-languageextensions.html#aws-languageextensions-considerations)
the unattended, low-privilege, low-code, "use existing template" CloudFormation
stack updates that turn the VPN off and on.)

The Terraform module for the VPN finds certificates by tag and requires only a
subnet ID, whereas the underlying CloudFormation stack requires many inputs,
and some of the inputs contain overlapping detail. If we put necessary
CloudFormation parameters into a database, it would be thoroughly
de-normalized!

My eventual goal is to call a third-party open-source Terraform module to
generate self-signed VPN certificates with the correct options -- and perhaps
to supply the complete VPN client configuration file. (The
[VPN self-service portal isn't available](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-self-service-portal.html#:~:text=apply:-,The%20self%2Dservice,mutual%20authentication.),
because I use mutual TLS authentication.) Generating VPN certificates would
never be possible in CloudFormation, without recourse to an AWS Lambda
function.

But Terraform is a mismatch for labor-saving AWS capabilities like gradual
updates in Lambda and Elastic Container Service (ECS), and RDS/Aurora
blue/green database upgrades. Supporting these kinds of native AWS features
"would require multiple iterations of editing the Terraform configuration,
applying the configuration, or importing resources. _A separate tool_ [emphasis
added] that can manage the orchestration steps would be a better fit"
([AWS Aurora Blue/Green Update, November&nbsp;24,&nbsp;2023](https://github.com/hashicorp/terraform-provider-aws/issues/28956#issuecomment-1826174309)).
Why make other people solve the same problem over and over again?

No single tool does everything well. AWS infrastructure-as-code enthusiasts
should learn both CloudFormation and Terraform/OpenTofu. Take advantage of the
best of what each of these leading IaC systems has to offer!

</details>

## Feedback

To help improve the 10-minute AWS Client VPN template, please
[report bugs](https://github.com/sqlxpert/10-minute-aws-client-vpn/issues).

## Licenses

|Scope|Link|Included Copy|
|:---|:---:|:---:|
|Source code files, and source code embedded in documentation files|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation files (including this readme file)|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
