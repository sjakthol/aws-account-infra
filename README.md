Infrastructure setup for an AWS organization.

## What is this?

This repository contains CloudFormation templates that defines an AWS infrastructure
for an AWS organization.

**Organization Infra**

The following stacks create organization wide configurations. They should be deployed to the organization management
account or a delegated administrator account for a given feature.

* `infra-org-policies.yaml` - Deploys Service Control Policies for the organization.
* `infra-sso.yaml` - Deploys AWS IAM Identity Center for the organization.
* `infra-stacksets.yaml` - Deploys common infra (CDKToolkit, buckets, ec2key, github-actions and vpc stacks) to all accounts and regions via CloudFormation StackSets.
* `infra-trail.yaml` - Creates a CloudTrail organization trail for the AWS Organization.

**Account Infra**

The following stacks create infra for each AWS account / region. They should be deployed to each account and active region. Some of these stacks are deployed to all accounts and regions with CloudFormation StackSets.

* `adhoc-instance.yaml` - Creates an EC2 instance for ad-hoc development work. Instance is configured with Docker, Node.js and Python.
* `CDKToolkit.yaml`  - The AWS CDK bootstrap stack.
* `infra-billing-alarms.yaml` - Creates billing alarms that send email alerts if estimated charges go over a pre-defined limit. This can be deployed to the consolidated billing account only or to all accounts separately. This stack is deployed to `us-east-1` region only.
* `infra-buckets.yaml` - Creates S3 buckets for build artifacts and log storage.
* `infra-ec2key.yaml` - Deploys an EC2 key pair to be used with EC2 instances.
* `infra-github-actions-roles.yaml` - Creates IAM roles for GitHub Actions.
* `infra-github-actions.yaml` - Creates an OIDC provider for GitHub Actions.
* `infra-kms.yaml` - Creates a generic KMS key.
* `infra-nat.yaml` - Creates a NAT Gateway for the VPC.
* `infra-vpc-logs.yaml` - Sets up logging for the VPC (VPC Flow Logs and Route 53 DNS resolver logs)
* `infra-vpc.yaml`- Creates a VPC with 2 x public, 2 x nat (NAT gateway deployed separately), 2 x isolated and 2 x private subnets.

See below for additional details on the setup.

## Managing Stacks
The Makefile included in this repository contains the following targets
for each template:

* `deploy-${STACK}` - creates or updates a stack from the given template
* `delete-${STACK}` - deletes the given stack

Examples:
```
make deploy-infra-buckets
make delete-infra-buckets
```

You can use the following variables to influence the commands that get executed:

* `AWS_REGION` - the region to deploy the stack to (default: `eu-west-1`)
* `TAGS` - set tags to be passed to the `--tags` flag of `aws cloudformation deploy`
  command (default: `Deployment=${REGION}-account-infra`)

## Setup Details

Here are some additional de

### AWS IAM Identity Center

AWS IAM Identity Center has the following pre-requisites:

* You have enabled AWS Organizations
* You have enabled AWS IAM Identity Center

Once enabled, you can use `infra-sso` template to deploy two permission sets to AWS IAM Identity Center:

* ReadOnlyAccess - read only access to accounts the set is assigned to
* AdministratorAccess - full admin access to accounts the set is assigned to

This stack must be deployed to the organization management account or to the
delegated administrator account for AWS IAM Identity Center and the region
the Identity Center was created to.

Once created, you must provision and assign permission sets to AWS accounts
manually. Please see the AWS IAM Identity Center documentation for details.

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

The NAT template deploys a regional NAT Gateway to the VPC. The stack can be deployed
in two modes:

* If `HighlyAvailable` is set to true, the stack creates a regional NAT gateway
  which will automatically expand to all AZs that have active ENIs. This setup
  can handle an availability zone failure but costs a bit more due to having NAT
  gateway active in multiple availability zones

* If `HighlyAvailable` is set to false, the stack creates a regional NAT Gateway
  and configures it to use the AZ-A of the region only. This setup is less expensive
  but it cannot handle a failure of the availability zone that hosts the NAT Gateway.
  Additionally, traffic from instances using subnets in other AZs will incur additional
  charges for cross-AZ traffic.

The template deploys the non-highly available setup by default.

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

The CloudTrail setup creates an S3 bucket for the CloudTrail logs and a global, organization
trail that logs to that bucket. This stack must be deployed to the organization management
account.

### KMS

The KMS stack creates a generic KMS key. This can be used to encrypt secrets
and data in the account. The stack also creates an alias `alias/common` for the
key.

The KMS key policy allows everyone to manage the key. Access to the key is
controlled with IAM identity policies only. IAM policies should use the
encryption context condition keys to limit access to the shared KMS key.

### Buckets

The buckets stack contains infra-level buckets such as a bucket for build
artifacts and storing account-wide logs.

### StackSets

The stacksets stack will create CloudFormation StackSets that common infra stacks
to all member accounts and select regions. Currently the following stacks are
deployed via StackSets: `CDKToolkit`, `infra-buckets`, `infra-ec2key`, `infra-github-actions`
and `infra-vpc`

This stack must be deployed to the organization management account or to the delegated
administrator account for CloudFormation StackSets.

### GitHub Actions

The `infra-github-actions` template creates an AWS IAM OIDC Provider for GitHub
actions. The provider is created by stack deployed to `eu-west-1` region. In
other regions the stack only sets up outputs and exports for the ARN of the
OIDC Provider that can be used in IAM roles deployments to that region.

The `infra-github-actions-roles` template creates IAM roles that GitHub Actions
can assume. This stack shall be deployed to accounts that GitHub Actions should
have access to.