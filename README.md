# 10-Minute AWS Client VPN

## Goals

This CloudFormation template will help you save up to 62% and run an
AWS-managed VPN for as little as $1 per day!

Today, security experts discourage relying mainly on the strength of the
perimeter around your private network. Nevertheless, in some scenarios,
perimeter security _is_ the available defense, and a virtual private network
connection is still necessary. For example, to access an AWS Elastic File
System (EFS) volume from your laptop, you must use a VPN, so that the Network
File System (NFS) client connection originates _inside_ your AWS Virtual
Private Cloud (VPC). NFS server software was not designed for full exposure to
the public Internet.

Client VPN is convenient because AWS manages it for you. It's well-documented,
but there are pitfalls for new users.
[Client VPN is also expensive](https://aws.amazon.com/vpn/pricing/#AWS_Client_VPN_pricing).
The baseline charge of 10¢ per hour per associated Availability Zone amounts
to $876 per year for one zone. Add 5¢ per hour per connection. Assuming a
40-hour work week, that's $104 per year per person, for a minimum total cost of
$876 + $104 = $980 per year. At least AWS now throws in
[free Client VPN data transfer between Availability Zones](https://aws.amazon.com/about-aws/whats-new/2022/04/aws-data-transfer-price-reduction-privatelink-transit-gateway-client-vpn-services/)!

The template minimizes costs by:

1. Associating the VPN with one Availability Zone. (Clients can access
   resources in any zone.) Failure of the designated zone would temporarily
   disable the VPN. You can associate a second zone for redundancy, if you
   don't mind the extra cost.

2. Configuring a "split-tunnel" VPN. The VPN carries only private network
   (VPC) traffic; a client's regular network connection handles public
   Internet traffic. The template does not support a "full tunnel"
   configuration.

3. Supporting
   [Lights Off](https://github.com/sqlxpert/lights-off-aws),
   which lets you tag your VPN stack so that the VPN will turned on and off
   on schedule. For example, leaving the VPN on 10 hours every weekday but
   shutting it off overnight and on weekends reduces the baseline cost from
   $876 to $261. With one person working 8 hours per weekday, the minimum
   total cost in this scenario drops to $261 + $104 = $365 per year.

Prices for the US East 1 (Northern Virginia) region were checked October 1,
2022. Prices and pricing rules can change at any time. NAT gateway, data
transfer, and other types of charges may also apply.

## Installation

[Documentation coming soon!]

## Licenses

|Scope|Link|Included Copy|
|--|--|--|
|Source code files, and source code embedded in documentation files|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation files (including this readme file)|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
