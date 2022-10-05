# 10-Minute AWS Client VPN

## Goals

This CloudFormation template will help you set up an AWS-managed VPN in about
10 minutes and operate it for as little as $1 per day!

Security experts discourage relying mainly on the strength of the perimeter
around your private network, but sometimes, perimeter security _is_ the
available defense, and a virtual private network connection is necessary. For
example, to access an AWS Elastic File System (EFS) volume from your local
computer, you must use a VPN, so that the Network File System (NFS) client
connection originates _inside_ your AWS Virtual Private Cloud (VPC). NFS
server software was not designed for full exposure to the public Internet.

Client VPN is convenient because AWS manages it for you. It's
[well-documented](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/what-is.html),
but there are pitfalls for new users.
[Client VPN is also expensive](https://aws.amazon.com/vpn/pricing/#AWS_Client_VPN_pricing).
The baseline charge of 10¢ per hour per associated Availability Zone amounts
to $876 per year. Add 5¢ per hour per connection. Assuming a 40-hour work week,
that's $104 per year per person, for a minimum total cost of $876 + $104 = $980
per year. At least AWS now throws in
[free Client VPN data transfer between Availability Zones](https://aws.amazon.com/about-aws/whats-new/2022/04/aws-data-transfer-price-reduction-privatelink-transit-gateway-client-vpn-services/)!

The template minimizes costs by:

1. Associating the VPN with one Availability Zone. (Clients can access
   resources in any zone.) Failure of the designated zone would temporarily
   disable the VPN. You can associate a second zone for redundancy, if you
   don't mind the extra cost.

2. Configuring a "split-tunnel" VPN, which carries only private network (VPC)
   traffic. A client's regular network connection handles public Internet
   traffic. For simplicity, the template does not support a "full tunnel"
   configuration.

3. Optionally supporting
   [Lights Off](https://github.com/sqlxpert/lights-off-aws),
   which can turn the VPN on and off automatically. For example, leaving the
   VPN on 10 hours every weekday but shutting it off overnight and on weekends
   reduces the baseline cost from $876 to $261. With one person working 8
   hours per weekday, the minimum total cost drops to $261 + $104 = $365 per
   year.

Prices for the US East 1 (Northern Virginia) region were checked October 1,
2022. Prices and pricing rules can change at any time. NAT gateway, data
transfer, and other types of charges may also apply.

## Quick Installation

 1. Follow AWS's
    [mutual authentication](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-authentication.html#mutual)
    steps, which help you create TLS certificates for the VPN server and for
    clients, and to upload the server certificate to AWS Certificate Manager.

    Copy the Linux/macOS commands and execute them verbatim.

    If you don't mind storing your certificates in `~/custom_folder/` and
    renaming the folder later, even those commands can be executed verbatim. I
    do, however, recommend inserting

    ```bash
    chmod go= ~/custom_folder/
    ```

    immediately after the `mkdir` line.

    Copy the ARN that ACM assigns when you upload the server certificate.
    There is no need to upload the client certificate to ACM.

 2. Optional: You can use a
    [CloudFormation service role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-servicerole.html)
    to give CloudFormation only the privileges it needs to create a Client VPN
    stack. Create a stack named `CVpnPrereq` from
    [10-minute-aws-client-vpn-prereq.yaml](/10-minute-aws-client-vpn-prereq.yaml)
    . You _must_ do this if you plan to use Lights Off to turn the VPN on and
    off automatically.

 3. Create a CloudFormation stack from
    [10-minute-aws-client-vpn.yaml](/10-minute-aws-client-vpn.yaml)

    Name the stack `CVpn` .

    The parameters are thoroughly documented. Set only the ones in the
    Essentials section. Make no changes under Advanced Options.

    Optional: If you created the deployment role in the previous step, set IAM
    role - optional to `CVpnPrereq-DeploymentRole` during the `CVpn` stack
    creation process. (If your own privileges are limited, you might need
    explicit permission to pass the deployment role to CloudFormation. See the
    `CVpnPrereq-SampleDeploymentRolePassRolePol` IAM policy for an example of
    the necessary statement.)

 4. Follow
    [Step 7 of AWS's Getting Started document](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-getting-started.html#cvpn-getting-started-config)
    , which helps you download and prepare the VPN client configuration file.

    You must find your VPN in the list of
    [Client VPN endpoints](https://console.aws.amazon.com/vpc/home#ClientVPNEndpoints:search=ClientVpnEndpoint)
    in the VPC Console and download the configuration file from there. (No
    self-service portal page is available for a VPN that relies on mutual
    certificate-based authentication.)

    When inserting the certificate and key into the configuration file, copy
    only the portion of each that begins with `-----BEGIN CERTIFICATE-----`
    and ends with `-----END CERTIFICATE-----` (including those lines).

    Do not forget to prepend a random string to the Client VPN endpoint DNS
    name. That line of the configuration file begins with `remote` .

 5. Download either the
    [OpenVPN](https://openvpn.net)
    client (Products &rarr; Connect Client)
    or the
    [AWS client](https://aws.amazon.com/vpn/client-vpn-download/)
    .

    The disclosure for the AWS client indicates that AWS collects usage data.
    I do not know whether OpenVPN also collects data.

 6. Import your edited configuration file to the client.

 7. Use the client to connect to the VPN.

 8. Add `FromClientSampleSecGrp` to an EC2 instance or, if you don't use SSH,
    create and add a security group that accepts traffic from VPN clients on
    the port of your choice.

 9. Test. On your local computer, run:

    ```bash
    ssh -i PRIVATE_KEY_FILE ec2-user@IP_ADDRESS
    ```

    where _PRIVATE_KEY_FILE_ is the path to the private key for the instance's
    SSH key pair, and _IP_ADDRESS_ is the **private** address of the instance.

    Different operating system images have different
    [default user names](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connection-prereqs.html#connection-prereqs-get-info-about-instance);
    `ec2-user` is not always correct!

    If you do not use SSH, run a different command to test VPN connectivity.

10. Remove `FromClientSampleSecGrp` (or equivalent) from you EC2 instance.

## Automatic Scheduling

1. Be sure that you have completed the optional parts of
   [Quick Installation](#quick-installation)
   Steps 2 and 3.

2. [Install Lights Off](https://github.com/sqlxpert/lights-off-aws#quick-start).

3. Update your `CVpn` CloudFormation stack, adding the following stack-level
   tags:

   * `sched-set-Enable-true` : `d=01 d=02 d=03 d=04 d=05 H:M=14:00`
   * `sched-set-Enable-false` : `d=02 d=03 d=04 d=05 d=06 H:M=01:00`

   Modify these schedules according to your own work days and work hours,
   keeping in mind that the schedules are in UTC time _and_ that UTC has no
   provision for Daylight Saving Time adjustments.

4. Find your VPN in the list of
   [Client VPN endpoints](https://console.aws.amazon.com/vpc/home#ClientVPNEndpoints:search=ClientVpnEndpoint)
   in the VPC Console and check that its Target network association(s) are
   being created and deleted as scheduled.

## Parameter Changes

You can change the `Enable` parameter whenever you wish.

You can add or remove a backup subnet (for a backup Availability Zone) even
while the VPN is enabled. You can also switch between generic and custom
security groups.

Do not try to change the VPC, the destination or client IP address ranges, or
the paths, after you have created the `CVpn` stack. To choose different values
for those parameters, create a `CVpn2` stack and then delete your original
`CVpn` stack.

## Feedback

To help improve the 10-minute AWS Client VPN template, please submit
[bug reports and feature requests](https://github.com/sqlxpert/10-minute-aws-client-vpn/issues),
as well as
[proposed changes](https://github.com/sqlxpert/10-minute-aws-client-vpn/pulls).

## Licenses

|Scope|Link|Included Copy|
|--|--|--|
|Source code files, and source code embedded in documentation files|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation files (including this readme file)|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
