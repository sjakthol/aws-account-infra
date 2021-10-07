Infrastructure setup for an AWS account backed by AWS CloudFormation.

## What is this?

This repository contains CloudFormation templates for an AWS infrastructure
setup that contains the following components:

* VPC with route tables that provide varying level of access to / from the
  public internet
* Billing alarms that send email when the estimated charges go over a pre-defined
  limit
* CloudTrail audit logging to S3
* KMS key for encrypting secrets
* Permission sets for AWS SSO

## Managing Stacks
The Makefile included in this repository contains the following targets
for each template in this repository:

* `deploy-${STACK}` - creates or updates a stack from the given template
* `delete-${STACK}` - deletes the given stack

Examples:
```
make deploy-infra-iam-base
make deploy-infra-iam-base AWS_PROFILE=admin
make delete-infra-iam-base
```

You can use the following variables to influence the commands that get executed:

* `AWS_PROFILE` - a profile for the AWS CLI `--profile` flag (default: `default`)
* `AWS_REGION` - the region to deploy the stack to (default: `eu-west-1`)
* `TAGS` - set tags to be passed to the `--tags` flag of `aws cloudformation deploy`
  command (default: `Deployment=${REGION}-account-infra`)

## Setup Details

### AWS SSO

AWS SSO has the following pre-requisites:

* You have enabled AWS Organizations
* You have enabled AWS SSO

Once enabled, you can use `infra-sso` template to deploy two permission sets to AWS SSO:

* ReadOnlyAccess - read only access to accounts the set is assigned to
* AdministratorAccess - full admin access to accounts the set is assigned to

Once created, you must provision and assign permission sets to AWS accounts
manually. Please see the AWS SSO documentation for details.

### VPC
The VPC included in the setup provides IPv4 connectivity only. The
key part of the template are the different route tables that provide different
levels of connectivity to any subnets that use those tables. The route tables
included in the setup are:
* `private` - A route table for fully private networks that provides IPv4
  connectivity to hosts in the VPC.
* `private-with-endpoints` - A route table that also includes S3 and DynamoDB
  access through a VPC endpoint.
* `nat-a` and `nat-b` - A route table with a route to the internet via a
  NAT Gateway (requires NAT stack).
* `public` - A route table that provides full bidirectional connectivity
  to the internet.

### Networks
The network stack contains two public, two NAT and two private subnets.

| Name | CIDR | Route Table | Import Name | Details |
|------|------|-------------|-------------|---------|
| Public A | 10.0.1.0/24 | public | `infra-vpc-sn-public-a` | Public subnet with direct route to and from internet in AZ-A |
| Public B | 10.0.2.0/24 | public | `infra-vpc-sn-public-b` | Public subnet with direct route to and from internet in AZ-B |
| Private A | 10.0.3.0/24 | private | `infra-vpc-sn-private-a` | Private subnet with access to VPC resources only in AZ-A. |
| Private B | 10.0.4.0/24 | private | `infra-vpc-sn-private-b` | Private subnet with access to VPC resources only in AZ-B. |
| NAT A | 10.0.5.0/24 | nat-a | `infra-vpc-sn-nat-a` | Subnet in AZ-A with access to internet through a NAT Gateway. |
| NAT B | 10.0.6.0/24 | nat-b | `infra-vpc-sn-nat-b` | Subnet in AZ-B with access to internet through a NAT Gateway. |
| Private With Endpoints A | 10.0.7.0/24 | private | `infra-vpc-sn-private-with-endpoints-a` | Private subnet with access to VPC resources + VPC endpoints in AZ-A. |
| Private With Endpoints B | 10.0.8.0/24 | private | `infra-vpc-sn-private-with-endpoints-b` | Private subnet with access to VPC resources + VPC endpoints in AZ-B. |

Other stacks can refer to the subnets with `Fn::ImportValue: <Import Name>` syntax.

### NAT
The NAT template deploys a NAT Gateway(s) to the VPC. The stack can be deployed
in two modes:

* If `HighlyAvailable` is set to true, the stack creates two NAT Gateways
  in two AZs (AZ-A and AZ-B) and attach these to the corresponding route table
  (`nat-a` and `nat-b`). This setup can handle an availability zone failure
  but costs a bit more due to two running to NAT Gateways.

* If `HighlyAvailable` is set to false, the stack creates one NAT Gateway to
  AZ-A of the region. This gateway is attached to both `nat-a` and `nat-b`
  route tables. This setup is less expensive but it cannot handle a failure
  of the availability zone that hosts the NAT Gateway. Additionally, traffic
  from instances using subnets in AZ-B will incur additional charges for cross-AZ traffic.

The template deploys the highly available setup by default.

### Billing Alarms
The billing alarms stack creates an SNS topic, subscribes your email address to
it and creates four alarms with increasing thresholds for the monthly estimated
charges. The default thresholds are:

* First Alarm: $10
* Second Alarm: $20
* Third Alarm: $40
* Fourth Alarm: $100

**Note**: You need to enable the `Receive Billing Alerts` feature from the Billing
Preferences of your account for the alarms to be functional. Also, the stack **must**
be deployed to the us-east-1 region as the metrics are only available there.

### CloudTrail
The CloudTrail setup included in this repository is pretty simple. The
CloudFormation stack includes an S3 bucket for the CloudTrail logs and
a global trail that logs to that bucket.

### KMS
The KMS stack will create a KMS key that can be used to encrypt secrets
for different purposes. The KMS key policy allows everyone to manage
the key which means that access to the key is fully controlled by IAM
policies of the users and roles on the account.

The stack also contains an alias that makes it easier to use that key.

### Buckets
The buckets stack contains infra-level buckets such as a bucket for build
artifacts and storing account-wide logs.


### Stack Sets
The stacksets stack will create CloudFormation stack sets that deploy
buckets, vpc and subnets to all member accounts.
