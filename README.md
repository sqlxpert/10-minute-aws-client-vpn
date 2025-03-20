# 10-Minute AWS Client VPN

## Goals

This CloudFormation template will help you set up an AWS-managed VPN in about
10 minutes and operate it for as little as $1 per day!

Experts discourage relying on the strength of the perimeter around your
private network, but sometimes, perimeter security _is_ the available defense,
and a virtual private network connection is necessary. For example, to access
an AWS Elastic File System (EFS) volume from your local computer, you must use
a VPN, so that the Network File System (NFS) client connection originates
_inside_ your AWS Virtual Private Cloud (VPC). NFS server software was not
designed for exposure to the public Internet.

Client VPN is convenient because AWS manages it for you. It is
[well-documented](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/what-is.html),
but there are pitfalls for new users.

[Client VPN is expensive](https://aws.amazon.com/vpn/pricing/#AWS_Client_VPN_pricing).
The baseline charge of 10¢ per hour per associated Availability Zone amounts
to $876 per year. Add 5¢ per hour per connection. Assuming a 40-hour work week,
that is $104 per year per person, for a minimum total cost of $876 + $104 =
$980 per year. At least AWS now throws in
[free Client VPN data transfer between Availability Zones](https://aws.amazon.com/about-aws/whats-new/2022/04/aws-data-transfer-price-reduction-privatelink-transit-gateway-client-vpn-services/)!

The template minimizes costs by:

1. Associating the VPN with one Availability Zone. (Clients can access
   resources in any zone.) Failure of the designated zone would temporarily
   disable the VPN. You can associate a second zone for redundancy, if you
   do not mind the extra cost.

2. Configuring a "split-tunnel" VPN, which carries only private network (VPC)
   traffic. Your regular Internet connection handles public Internet traffic.

3. Optionally supporting
   [Lights Off](https://github.com/sqlxpert/lights-off-aws#bonus-delete-and-recreate-expensive-resources-on-a-schedule),
   which can turn the VPN on and off automatically. Leaving the VPN on for 10
   hours every weekday but shutting it off overnight and on weekends reduces
   the baseline cost to $261. With one person connecting for 8 hours per
   weekday, the minimum total cost drops to $261 + $104 = $365 per year.

Prices for the US East 1 (Northern Virginia) region were checked March 20,
2025. Pricing can change at any time. NAT gateway, data transfer, and other
types of charges may also apply.

## Quick Installation

 1. Follow AWS's
    [mutual authentication steps](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-auth-mutual-enable.html).

    Copy the individual Linux/macOS commands and execute them verbatim.

    Copy and edit the block of commands before executing those.
    `~/custom_folder` is fine for now, but after the `mkdir` line, insert:

    ```bash
    chmod go= ~/custom_folder
    ```

    After uploading the first (server) certificate, copy the ARN returned by
    AWS Certificate Manager. There is no need to upload the second (client)
    certificate.

 2. _Optional:_ You can use a
    [CloudFormation service role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-servicerole.html)
    to delegate only the privileges needed to deploy a Client VPN stack.
    Create a stack from a locally-saved copy of
    [10-minute-aws-client-vpn-prereq.yaml](/10-minute-aws-client-vpn-prereq.yaml?raw=true)
    [right-click to save as...]. Name the stack `CVpnPrereq` .

    This step is _required_ if you plan to use
    [Lights Off](https://github.com/sqlxpert/lights-off-aws#bonus-delete-and-recreate-expensive-resources-on-a-schedule)
    to turn the VPN on and off on a schedule.

 3. Create a CloudFormation stack from a locally-saved copy of
    [10-minute-aws-client-vpn.yaml](/10-minute-aws-client-vpn.yaml?raw=true)
    [right-click to save as...].

    Name the stack `CVpn` .

    The parameters are thoroughly documented. Set only the Essential ones.

    _Optional:_ If you created the deployment role in the previous step, set
    IAM role - optional to `CVpnPrereq-DeploymentRole` later in the `CVpn`
    stack creation process. (If your own privileges are limited, you might
    need explicit permission to pass the role to CloudFormation. See the
    `CVpnPrereq-SampleDeploymentRolePassRolePol` IAM policy for an example.)

 4. Follow
    [Step 7 of AWS's Getting Started document](https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/cvpn-getting-started.html#cvpn-getting-started-config).

    You must find your VPN in the list of
    [Client VPN endpoints](https://console.aws.amazon.com/vpc/home#ClientVPNEndpoints:search=ClientVpnEndpoint)
    in the AWS Console and download the configuration file from there.

    `cd` to the directory where you downloaded the file and:

    ```bash
    chmod go= downloaded-client-config.ovpn
    ```

    Open the file in your preferred editor, copy the skeleton from AWS's
    instructions and paste it at the end of the file, then replace the text
    between the tags with the contents of the
    `~/custom_folder/client1.domain.tld.crt` certificate file and the
    `~/custom_folder/client1.domain.tld.key` key file.

    Rename `~/custom_folder` and note that you must also continue to protect
    `easy-rsa/easyrsa3/pki` and `downloaded-client-config.ovpn` , all of which
    contain copies of your key.

 5. Download either the latest
    [OpenVPN](https://openvpn.net) client (Resources &rarr; Connect Client
    &rarr; Download) or
    [AWS client](https://aws.amazon.com/vpn/client-vpn-download/).

    It is not known whether OpenVPN collects data. The download page for the
    AWS client reveals that AWS collects usage data.

 6. Import your edited configuration file to the client.

 7. Use the client to connect to the VPN.

 8. Add `FromClientSampleSecGrp` to an EC2 instance or, if you do not use SSH,
    create and add a security group that accepts traffic from VPN clients on
    another port of your choice.

 9. Test. On your local computer, run:

    ```bash
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

1. Be sure that you have completed the optional parts of the
   [Quick Installation](#quick-installation) procedure.

2. [Install Lights Off](https://github.com/sqlxpert/lights-off-aws#quick-start).

3. Update your `CVpn` CloudFormation stack, adding the following stack-level
   tags:

   - `sched-set-Enable-true` : `d=01 d=02 d=03 d=04 d=05 H:M=14:00`
   - `sched-set-Enable-false` : `d=02 d=03 d=04 d=05 d=06 H:M=01:00`

   Adjust the weekdays and the times based on your work schedule.

   - `u=1` is Monday and `u=7` is Sunday, per
     [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601#Week_dates).
   - Times are in Universal Coordinated Time (UTC). This converter may be
     helpful:
     [www.timeanddate.com](https://www.timeanddate.com/worldclock/converter.html?iso=20250320T140000&p1=224&p2=250&p3=1440&p4=37&p5=44)
     .
   - UTC has no provision for Daylight Saving Time/Summer Time. Leave a
     buffer after your work day to avoid having to change schedules.

4. Find your VPN in the list of
   [Client VPN endpoints](https://console.aws.amazon.com/vpc/home#ClientVPNEndpoints:search=ClientVpnEndpoint)
   in the AWS Console and check that its Target network association(s) are
   being created and deleted as scheduled. After a few days of operation,
   check actual costs.

## Parameter Changes

You can change the `Enable` parameter whenever you wish.

You can add or remove a backup subnet (for a second Availability Zone) even
while the VPN is enabled. You can also switch between generic and custom
security groups.

Do not try to change the VPC, the destination or client IP address ranges, or
the paths, after you have created the `CVpn` stack. Instead, create a `CVpn2`
stack and then delete your original `CVpn` stack; distributing a new VPN
client configuration is required.

## Feedback

To help improve the 10-minute AWS Client VPN template, please
[report bugs](https://github.com/sqlxpert/10-minute-aws-client-vpn/issues)
and
[propose changes](https://github.com/sqlxpert/10-minute-aws-client-vpn/pulls).

## Licenses

|Scope|Link|Included Copy|
|--|--|--|
|Source code files, and source code embedded in documentation files|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation files (including this readme file)|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
