# 10-Minute AWS Client VPN

## Goals

This CloudFormation template
(+&nbsp;[Terraform option](#terraform-option))
helps you set up an
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

> Before you begin, take a deep breath! Setup is shorter than it looks. It's a good idea to read each step completely before you start it. Unfortunately, you will have to switch back and forth between this ReadMe file and AWS's documentation.
>
> You do not need to be an expert to get started. After your AWS Client VPN is up and running, you can learn more at your own pace, by reading the descriptions of the optional parameters and examining the templates.
>
> [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
might be useful for setup and maintenance, but be aware of
[limitations on persistent storage](https://docs.aws.amazon.com/cloudshell/latest/userguide/limits.html#persistent-storage-limitations)
if you use your free CloudShell home directory to store your certificate authority
(and Terraform state, if you use the
[Terraform option](#terraform-option)).

 1. Follow AWS's
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

    - There is no need to upload the second (client) certificate.

 2. _Optional:_ You can use a
    [CloudFormation service role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-servicerole.html)
    to delegate only the privileges needed to deploy a Client VPN stack.

    This step is required only if you plan to use
    [Lights Off](https://github.com/sqlxpert/lights-off-aws#bonus-delete-and-recreate-expensive-resources-on-a-schedule)
    to turn the VPN on and off on a schedule.

    - Create a stack from a locally-saved copy of
      [cloudformation/10-minute-aws-client-vpn-prereq.yaml](/cloudformation/10-minute-aws-client-vpn-prereq.yaml?raw=true)
      [right-click to save as...].

    - Name the stack `CVpnPrereq` .

    - Under "Additional settings" &rarr; "Stack policy - optional", you can
      "Upload a file" and select a locally-saved copy of
      [10-minute-aws-client-vpn-prereq-policy.json](/10-minute-aws-client-vpn-prereq-policy.json?raw=true)
      [right-click to save as...]. The stack policy prevents inadvertent
      replacement or deletion of the deployment role during stack updates,
      but it cannot prevent deletion of the entire `CVpnPrereq` stack.

 3. Create a CloudFormation stack from a locally-saved copy of
    [cloudformation/10-minute-aws-client-vpn.yaml](/cloudformation/10-minute-aws-client-vpn.yaml?raw=true)
    [right-click to save as...].

    - Name the stack `CVpn` .

    - The parameters are thoroughly documented. Set only the "Essential" ones.

    - Under "Permissions - optional" &rarr; "IAM role - optional", select
      `CVpnPrereq-DeploymentRole` _if_ you created the deployment role in the
      previous step. (If your own privileges are limited, you might
      need explicit permission to pass the role to CloudFormation. See the
      `CVpnPrereq-SampleDeploymentRolePassRolePol` IAM policy for an example.)

    - Under "Additional settings" &rarr; "Stack policy - optional", you can
      "Upload a file" and select a locally-saved copy of
      [cloudformation/10-minute-aws-client-vpn-policy.json](/cloudformation/10-minute-aws-client-vpn-policy.json?raw=true)
      [right-click to save as...]. The stack policy prevents replacement or
      deletion of certain resources during stack updates, producing an error
      if you attempt
      [parameter updates](#parameter-updates)
      that are not possible.

 4. Follow
    [Step 7 of AWS's Getting Started document](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-getting-started.html#cvpn-getting-started-config).

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
      `easy-rsa/easyrsa3/pki` and `downloaded-client-config.ovpn` . All three
      contain copies of your key.

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

 1. Be sure that you completed the optional parts of the
    [Quick Installation](#quick-installation) procedure.

 2. [Install Lights Off](https://github.com/sqlxpert/lights-off-aws#quick-start).

 3. Update your `CVpn` CloudFormation stack, adding the following stack-level
    tags:

    - `sched-set-Enable-true` : `u=1 u=2 u=3 u=4 u=5 H:M=11:00`
    - `sched-set-Enable-false` : `u=2 u=3 u=4 u=5 u=6 H:M=01:00`

    Adjust the weekdays and the times based on your work schedule. This example
    is suitable for the mainland portions of the United States and Canada.

    - `u=1` is Monday and `u=7` is Sunday, per
      [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601#Week_dates).
    - Times are in Universal Coordinated Time (UTC). This converter may be
      helpful:
      [www.timeanddate.com](https://www.timeanddate.com/worldclock/converter.html?iso=20250320T110000&p1=224&p2=250&p3=1440&p4=37&p5=44)
      .
    - UTC has no provision for Daylight Saving Time/Summer Time. Leave a
      buffer at the end of your work day to avoid having to change schedules.

 4. Find your VPN in the list of
    [Client VPN endpoints](https://console.aws.amazon.com/vpc/home#ClientVPNEndpoints:search=ClientVpnEndpoint)
    in the AWS Console and check that its "Target network associations" are
    being created and deleted as scheduled. Check actual costs after a few
    days, and set up alerts with
    [AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html).

## Parameter Updates

You can toggle the `Enable` parameter.

You can add or remove a backup subnet (second Availability Zone) even while
the VPN is enabled. You can also switch between generic and custom VPN client
security groups.

Do not try to change the VPC, the IP address ranges, or the path parameters
after you have created the `CVpn` stack. Instead, create a `CVpn2` stack,
delete your original `CVpn` stack, then update the _remote_ line of your client
configuration file and re-import. The optional
[cloudformation/10-minute-aws-client-vpn-policy.json](/cloudformation/10-minute-aws-client-vpn-policy.json)
stack policy protects against most of these changes.

## Terraform Option

### Terraform Child Module

To create the VPN in a child module, add the following to your Terraform root
module:

```terraform
module "cvpn" {
  source = "git::https://github.com/sqlxpert/10-minute-aws-client-vpn.git//terraform?ref=v4.0.0"
    # Reference a specific version from github.com/sqlxpert/10-minute-aws-client-vpn/releases

  cvpn_params = {
    "TargetSubnetId" = "subnet-10123456789abcdef"
  }
}
```

Edit the subnet&nbsp;ID to match the ID of a subnet in the VPN's primary (or
sole) Availability Zone. The module (not you!) replaces the
`CURRENT_AWS_ACCOUNT` and `CURRENT_AWS_REGION` literals with the AWS account
number and region code.

Before proceeding, have Terraform download the module's source code:

```shell
terraform init
```

### Terraform Root Module

<details>
  <summary>Required files...</summary>

<br/>

To create the VPN in your Terraform root module instead of in a child module,
copy the `terraform/` and `cloudformation/` directories to the directory
containing your root Terraform module.

In a `terraform.tfvars` file in the same directory, set:

```terraform
cvpn_params = {
  "TargetSubnetId" = "subnet-10123456789abcdef"
}
```

Edit the subnet&nbsp;ID.

</details>

### Installing with Terraform

<details>
  <summary>If you run Terraform with least-privilege permissions...</summary>

<br/>

Most people do not need to read this section, because most Terraform users
grant full AWS administrative permissions to Terraform.

If, given the serious security risks associated with the typical approach, you
instead follow the principle of least privilege for Terraform, you must give
Terraform permission to:

- List, describe, create, update and delete CloudFormation stacks
- Set and get CloudFormation stack policies
- List, describe, get tags for, create, tag, update and delete IAM roles and
  their in-line policies
- Pass `CVpnPrereq-DeploymentRole-*` to CloudFormation
- List, describe, and get tags for, all of the `data` sources in
  [10-minute-aws-client-vpn.tf](/10-minute-aws-client-vpn.tf)&nbsp;.
  For a list, run:

  ```shell
  grep 'data "' 10-minute-aws-client-vpn.tf
  ```

Open the
[AWS Service Authorization Reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html#actions_table),
go through the list of services on the left, and consult the "Actions" table
for each of:

- `CloudFormation`
- `AWS Identity and Access Management (IAM)`
- `Amazon EC2`
- `AWS Security Token Service`
- `AWS Certificate Manager`
- `AWS Systems Manager`
- `AWS Key Management Service` (if you encrypt the CloudWatch log group with a
  KMS key)

The deployment role defined in the `CVpnPrereq` stack gives CloudFormation the
permissions it needs to create the `CVpn` stack. Terraform itself does not need
the deployment role's permissions.

</details>

Follow the
[Quick Installation](#quick-installation)
instructions, except that:

- Step&nbsp;2 is handled automatically.
- In place of Step&nbsp;3, you will tag the VPN certificate(s) you've uploaded,
  before using _Terraform_ to install the `CVpnPrereq` and `CVpn`
  CloudFormation stacks.

  If you did not upload a client certificate, apply both tags to the _server_
  certificate.

  ```shell
  aws acm add-tags-to-certificate --tags 'Key=CVpnServer,Value=' --certificate-arn 'SERVER_CERT_ARN'
  aws acm add-tags-to-certificate --tags 'Key=CVpnClientRootChain,Value=' --certificate-arn 'CLIENT_CERT_ARN'

  terraform apply
  ```

Remember to **turn on the VPN** &#9888; by changing the `Enable` parameter of
the `CVpn` stack to `true`, in CloudFormation. The Terraform option leaves the
VPN off at first.

The Terraform option is compatible with
[Automatic Scheduling](#automatic-scheduling).
`terraform plan` will not report unapplied changes when the `Enable` parameter
value is changed in CloudFormation. To have Terraform set the schedule tags,
add

```terraform
      "schedule_tags" = {
        "sched-set-Enable-true"  = "u=1 u=2 u=3 u=4 u=5 H:M=11:00"
        "sched-set-Enable-false" = "u=2 u=3 u=4 u=5 u=6 H:M=01:00"
      }
```

to the inner `accounts_to_regions_to_cvpn_params` map. Edit the tag values.

### Referencing Outputs in Terraform

For the VPN endpoint ID, reference the `module.cvpn.cvpn_endpoint_id` output.
If you chose to create the VPN in your Terraform root module rather than in a
child module, `data.aws_ec2_client_vpn_endpoint.cvpn` is provided for you.

To accept traffic from VPN clients, reference the
`module.cvpn.cvpn_client_sec_grp_id` output in:

- `aws_vpc_security_group.ingress.security_groups` _or_
- `aws_vpc_security_group_ingress_rule.referenced_security_group_id`

when you define security groups for your servers or listeners.

If you chose to create the VPN in your root module,
`data.aws_security_group.cvpn_client[0]` is provided.

The security group output and data source are not available &#9888; if you
supplied `CustomClientSecGrpIds`&nbsp;.

### Customizing the Terraform Option

<details>
  <summary>Customization possibilities...</summary>

<br/>

Up-to-date AWS users reference centrally-defined
[subnets shared through Resource Access Manager](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-sharing.html).
The Terraform option relies on data sources, which are appropriate for this
configuration.

If your subnets happen to be defined in the same Terraform workspace as the
VPN, you may wish to substitute direct resource references.

You may also wish to change the interface
(`accounts_to_regions_to_cvpn_params`) to suit your particular approach to
[Terraform module composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition).

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
