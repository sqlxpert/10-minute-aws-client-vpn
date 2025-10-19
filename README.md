# 10-Minute AWS Client VPN

## Goals

This CloudFormation template (+&nbsp;optional Terraform module) helps you set
up an
[AWS-managed VPN](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/what-is.html)
in about 10&nbsp;minutes and operate it for as little as $1.41 per work day!

[AWS Client VPN is expensive](https://aws.amazon.com/vpn/pricing/#AWS_Client_VPN_pricing).
How this template minimizes costs:

 1. [Split-tunneling](https://en.wikipedia.org/wiki/Split_tunneling).
    Only AWS private network (VPC) traffic uses the VPN.

 2. Single Availability Zone, by default.
    [VPN clients can access VPC resources in any Availability Zone in the same
    region at no extra charge](https://aws.amazon.com/about-aws/whats-new/2022/04/aws-data-transfer-price-reduction-privatelink-transit-gateway-client-vpn-services/).

 3. Optional on/off scheduling with
    [github.com/sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#bonus-delete-and-recreate-expensive-resources-on-a-schedule)&nbsp;.

    <details>
      <summary>Cost savings...</summary>

    <br/>

    |VPN usage|Price (1&nbsp;hour)|Hours (7&nbsp;days)|Hours (365&nbsp;days)|Cost (365&nbsp;days)|
    |:---|:---:|:---:|:---:|:---:|
    |_Always&nbsp;on:_|||||
    |Endpoint associated|10¢|168|8,760|$876|
    |1&nbsp;client connected|5¢|40|2,080|$104|
    |Total||||$980|
    |_Work&nbsp;hours&nbsp;only:_|||||
    |Endpoint associated|10¢|**50**|**2,607**|**$261**|
    |1&nbsp;client connected|5¢|40|2,080|$104|
    |Total||||**$365**|

    $365 per year divided by 260&nbsp;work days gives $1.41&nbsp;per work day.

    > Prices in the `us-east-1` region were checked in October,&nbsp;2025 but
    can change at any time.<br/>
    NAT gateway, data transfer, and other charges may
    also apply.

    </details>

<details>
  <summary>Rationale for connecting to AWS with a VPN...</summary>

<br/>

Experts discourage relying on the strength of the perimeter around your private
network, but sometimes, perimeter security _is_ the available defense, and a
virtual private network connection is necessary. For example, to access an AWS
Elastic File System (EFS) volume from your local computer, you must use a VPN,
so that the Network File System (NFS) client connection originates _inside_
your AWS Virtual Private Cloud (VPC). NFS server software was not designed for
exposure to the public Internet.

</details>

## Quick Installation

> Before you begin, take a deep breath! Certificate setup is shorter than it
looks. To avoid errors, read each step completely before doing it. You will
have to switch between this ReadMe file and AWS's documentation.

> [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
might be useful for setup and maintenance, but be aware of
[limitations on persistent storage](https://docs.aws.amazon.com/cloudshell/latest/userguide/limits.html#persistent-storage-limitations)
if you use your free CloudShell home directory to store your certificate
authority (and Terraform state, if you are using Terraform).

 1. Create the VPN certificate(s) by following AWS's
    [mutual authentication steps](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-auth-mutual-enable.html).

    - Copy the _individual_ Linux/macOS commands and execute them verbatim.

    - Copy and edit the _block_ of commands before executing those. Not
      replacing `custom_folder` is actually fine for now (if only AWS's
      technical writers had picked a meaningful folder name instead of a
      placeholder!), but after the `mkdir` line, please insert:

      ```shell
      chmod go= ~/custom_folder
      ```

    - After uploading the first (server) certificate, copy the ARN returned by
      AWS Certificate Manager.

    - Uploading the second (client) certificate is completely optional.

 2. &#9888; **Tag the VPN certificate(s) if you are using Terraform.**
    If you are not using a separate client certificate, apply both tags to
    the _server_ certificate.

    ```shell
    aws acm add-tags-to-certificate --tags 'Key=CVpnServer,Value=' --certificate-arn 'SERVER_CERT_ARN'
    aws acm add-tags-to-certificate --tags 'Key=CVpnClientRootChain,Value=' --certificate-arn 'CLIENT_CERT_ARN'
    ```

 3. Install the Client VPN CloudFormation stack using CloudFormation or
    Terraform.

    - **CloudFormation**<br/>_Easy_ &check;

      Create a stack "With new resources (standard)" from a locally-saved copy
      of
      [cloudformation/10-minute-aws-client-vpn.yaml](/cloudformation/10-minute-aws-client-vpn.yaml?raw=true)
      [right-click to save as...].

      - Name the stack `CVpn`&nbsp;.

      - The parameters are thoroughly documented. Set only the "Essential"
        ones.

      - Under "Additional settings" &rarr; "Stack policy - optional", you can
        "Upload a file" and select a locally-saved copy of
        [cloudformation/10-minute-aws-client-vpn-policy.json](/cloudformation/10-minute-aws-client-vpn-policy.json?raw=true)
        [right-click to save as...]. The stack policy prevents replacement or
        deletion of certain resources during stack updates, producing an error
        if you attempt
        [parameter updates](#parameter-updates)
        that are not possible.

    - **Terraform**

      Check that you have at least:

      - [Terraform v1.10.0 (2024-11-27)](https://github.com/hashicorp/terraform/releases/tag/v1.10.0)
      - [Terraform AWS provider v6.0.0 (2025-06-18)](https://github.com/hashicorp/terraform-provider-aws/releases/tag/v6.0.0)

      Add the following child module to your existing root module:

      ```terraform
      module "cvpn" {
        source = "git::https://github.com/sqlxpert/10-minute-aws-client-vpn.git//terraform?ref=v4.0.1"
          # Reference a specific version from github.com/sqlxpert/10-minute-aws-client-vpn/releases

        cvpn_params = {
          TargetSubnetId = "subnet-10123456789abcdef"
        }
      }
      ```

      Edit the subnet&nbsp;ID to match the ID of a subnet in the VPN's
      primary (or sole) Availability Zone.

      Have Terraform download the module's source code. Review the plan
      before typing `yes` to allow Terraform to proceed with applying the
      changes.

      ```shell
      terraform init
      terraform apply
      ```

      &#9888; **Turn on the VPN** by changing the `Enable` parameter of the
      `CVpn` stack to `true` in CloudFormation. The Terraform module leaves
      the VPN off at first and then deliberately ignores changes to
      `cvpn_params["Enable"]` so that CloudFormation can manage that
      parameter.

 4. Follow
    [Step&nbsp;7 of AWS's Getting Started document](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-getting-started.html#cvpn-getting-started-config).

    - Find your VPN in the list of
      [Client VPN endpoints](https://console.aws.amazon.com/vpc/home#ClientVPNEndpoints:search=ClientVpnEndpoint)
      in the AWS Console and download the configuration file from there.

    - `cd` to the directory where you downloaded the file and:

      ```shell
      chmod go= downloaded-client-config.ovpn
      ```

    - Open the file in your preferred editor, copy the skeleton from AWS's
      instructions and paste it at the end of the file, then replace the text
      between the tags with the contents of the
      `~/custom_folder/client1.domain.tld.crt` certificate file and the
      `~/custom_folder/client1.domain.tld.key` key file.

    - Rename `~/custom_folder` and note that you must also continue to protect
      `easy-rsa/easyrsa3/pki` and `downloaded-client-config.ovpn`&nbsp;. All
      three contain copies of your key.

 5. Download either the latest
    [OpenVPN](https://openvpn.net) client (Resources &rarr; Connect Client
    &rarr; Download) or
    [AWS client](https://aws.amazon.com/vpn/client-vpn-download/).

 6. Import your edited configuration file to the client.

 7. Use the client to connect to the VPN.

 8. Add `FromClientSampleSecGrp` to an EC2 instance or, if you do not use SSH,
    create and add a security group that accepts traffic from VPN clients on
    the port of your choice.

 9. Test. On your local computer, run:

    ```shell
    ssh -i PRIVATE_KEY_FILE ec2-user@IP_ADDRESS
    ```

    where _PRIVATE_KEY_FILE_ is the path to the private key for the instance's
    SSH key pair, and _IP_ADDRESS_ is the **private** address of the instance.

    Different operating system images have different
    [default usernames](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connection-prereqs-general.html#connection-prereqs-get-info-about-instance);
    `ec2-user` is not always correct!

    If you do not use SSH, run a different command to test VPN connectivity.

10. Remove `FromClientSampleSecGrp` (or equivalent) from you EC2 instance.

## Automatic Scheduling

<details>
  <summary>To turn the VPN on and off on a schedule...</summary>

 1. If you used Terraform above,
    [skip to Automatic Scheduling Step&nbsp;2](#automatic-scheduling-step-2).

    If you used CloudFormation...

    - Create a stack "With new resources (standard)" from a locally-saved copy
      of
      [cloudformation/10-minute-aws-client-vpn-prereq.yaml](/cloudformation/10-minute-aws-client-vpn-prereq.yaml?raw=true)
      [right-click to save as...].

    - Name this stack `CVpnPrereq`&nbsp;.

    - Under "Additional settings" &rarr; "Stack policy - optional", you can
      "Upload a file" and select a locally-saved copy of
      [10-minute-aws-client-vpn-prereq-policy.json](/10-minute-aws-client-vpn-prereq-policy.json?raw=true)
      [right-click to save as...]. The stack policy prevents inadvertent
      replacement or deletion of the deployment role during stack updates,
      but it cannot prevent deletion of the entire `CVpnPrereq` stack.

    - Update your initial `CVpn` stack, changing nothing until the "Configure
      stack options" page, on which you will set "IAM role - optional" to
      `CVpnPrereq-DeploymentRole`&nbsp;. You are using a
      [CloudFormation service role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-servicerole.html)
      to delegate update privileges.

      If your own privileges are limited, you might need explicit permission to
      _pass_ the role to CloudFormation. See the
      `CVpnPrereq-SampleDeploymentRolePassRolePol` IAM policy for an example.

 2. <a name="automatic-scheduling-step-2"></a>[Install Lights Off](https://github.com/sqlxpert/lights-off-aws#quick-start).

 3. Update your `CVpn` CloudFormation stack, adding the following stack-level
    tags:

    - `sched-set-Enable-true` : `u=1 u=2 u=3 u=4 u=5 H:M=11:00`
    - `sched-set-Enable-false` : `u=2 u=3 u=4 u=5 u=6 H:M=01:00`

    In Terraform, set the following variable inside your `module` block:

    ```terraform
        cvpn_schedule_tags = {
          sched-set-Enable-true  = "u=1 u=2 u=3 u=4 u=5 H:M=11:00"
          sched-set-Enable-false = "u=2 u=3 u=4 u=5 u=6 H:M=01:00"
        }
    ```

    Adjust the weekdays and the times based on your work schedule. This example
    is suitable for the mainland portions of the United States and Canada.

    - `u=1` is Monday and `u=7` is Sunday, per
      [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601#Week_dates).
    - Times are in Universal Coordinated Time (UTC). This converter may be
      helpful:
      [www.timeanddate.com](https://www.timeanddate.com/worldclock/converter.html?iso=20250320T110000&p1=224&p2=250&p3=1440&p4=37&p5=44)&nbsp;.
    - UTC has no provision for Daylight Saving Time/Summer Time. Leave a
      buffer at the end of your work day to avoid having to change schedules.

 4. Find your VPN in the list of
    [Client VPN endpoints](https://console.aws.amazon.com/vpc/home#ClientVPNEndpoints:search=ClientVpnEndpoint)
    in the AWS Console and check that its "Target network associations" are
    being created and deleted as scheduled. Check actual costs after a few
    days, and set up alerts with
    [AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html).

</details>

## Parameter Updates

You can toggle the `Enable` parameter (always in CloudFormation, never from
Terraform).

You can add or remove a backup subnet (in a second Availability Zone), but you
must do it while the VPN is enabled, or the change won't register.

You can also switch between generic and custom VPN client security groups.

Do not try to change the VPC, the IP address ranges, or the path parameters
after the `CVpn` stack has been created. Instead, create a `CVpn2` stack (in
Terraform, create a new module instance with
`cvpn_stack_name_suffix = "2"`&nbsp;), then update the _remote_ line of
your client configuration file and re-import the configuration file to your VPN
client utility.

## Terraform Details

### Terraform Module Outputs

|Output|Original Resource and Attribute|
|:---|:---|
||**Matching Data Source and Argument**|
|`module.cvpn.cvpn_endpoint_id`|[`aws_ec2_client_vpn_endpoint`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_endpoint).[`id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_client_vpn_endpoint#id-1)|
||[`data.aws_ec2_client_vpn_endpoint`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_client_vpn_endpoint).[`client_vpn_endpoint_id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_client_vpn_endpoint#client_vpn_endpoint_id-1)|
|`module.cvpn.cvpn_client_sec_grp_id`|[`aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group.html).[`id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group.html#id-1)|
||[`data.aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group).[`id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group#id-1)|

To accept traffic from VPN clients, reference `module.cvpn.cvpn_client_sec_grp_id` in:

- [`aws_vpc_security_group.`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group).[`ingress`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group#ingress).[`security_groups`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group#security_groups-1) or
- [`aws_vpc_security_group_ingress_rule`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule).[`referenced_security_group_id`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule#referenced_security_group_id-1)

of server or listener security groups. &#9888; The security group output is not
available if `cvpn_params["CustomClientSecGrpIds"]` was set.

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
- Pass `CVpnPrereq-DeploymentRole-*` to CloudFormation
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

The deployment role defined in the `CVpnPrereq` stack gives CloudFormation the
permissions it needs to create the `CVpn` stack. Terraform itself does not need
the deployment role's permissions.

</details>

## Feedback

To help improve the 10-minute AWS Client VPN template, please
[report bugs](https://github.com/sqlxpert/10-minute-aws-client-vpn/issues)
and
[propose changes](https://github.com/sqlxpert/10-minute-aws-client-vpn/pulls).

## Licenses

|Scope|Link|Included Copy|
|:---|:---:|:---:|
|Source code files, and source code embedded in documentation files|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation files (including this readme file)|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
