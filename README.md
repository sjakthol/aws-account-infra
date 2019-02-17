Infrastructure setup for an AWS account backed by AWS CloudFormation.

## What is this?

This repository contains CloudFormation templates for an AWS infrastructure
setup that contains the following components:

* IAM roles, policies, groups and users
* VPC with route tables that provide varying level of access to / from the
  public internet
* Billing alarms that send email when the estimated charges go over a pre-defined
  limit
* CloudTrail audit logging to S3
* KMS key for encrypting secrets

## Managing Stacks
The Makefile included in this repository contains the following targets
for each template in this repository:

* `create-${STACK}` - creates a stack from the given template
* `update-${STACK}` - updates a stack from the given template
* `validate-${STACK}` - validates the given stack template

Examples:
```
make create-infra-iam-base
make update-infra-iam-base AWS_PROFILE=admin
make validate-infra-iam-base
```

You can use the following variables to influence the commands that get executed:

* `AWS_PROFILE` - a profile for the AWS CLI `--profile` flag (default: `default`)
* `AWS_REGION` - the region to deploy the stack to (default: `eu-west-1`)
* `TAGS` - set tags to be passed to the `--tags` flag of `aws cloudformation {create,update}-stack`
  command (default: `Key=Deployment,Value=${REGION}-account-infra`)

## Setup Details

### IAM
The key features of the IAM setup are:
* MFA is required for all operations
* Users need to assume roles with higher privileges to modify resources and
  these roles can have varying levels of access to the account

#### IAM Group Structure
There are three different type of groups for IAM users.

All users should be added to the `all-users` group which provides them with
the basic access to manage their own IAM preferences and enforces the usage
of MFA across all AWS API operations.

The second set of groups provides different levels of read-only access to
AWS services for IAM users. The policies attached to these groups should
give the users direct access to the set of read-only API calls different
users require. The `read-only-users` group provides all members of the
group read-only access to all AWS services.

The third set of groups provides users means to modify AWS resources. The
policies attached to these groups should not provide IAM users direct
access to the APIs but they should allow users to assume a role which
has the required permissions to perform the required task. This ensures
that users cannot accidentally modify resources but need to explicitly
assume a role in order to perform potentially destructive actions. The
`admin-users` group is an example of a group that allows its members
to assume the `account-admin` role for performing administrative tasks
(full access to account). Another example is the `power-users` group
that allows users to use specific AWS services through the
`power-user-access` role.

It is advisable to create additional administrative groups and roles with
less privileges for users who only need to be able to perform specific
administrative tasks.

### VPC
The VPC included in the setup provides IPv4 connectivity only. The
key part of the template are the different route tables that provide different
levels of connectivity to any subnets that use those tables. The route tables
included in the setup are:
* `private` - a route table for fully private networks that provides IPv4
  connectivity to hosts in the VPC
* `private-with-endpoints` - a route table that also includes S3 and DynamoDB
  access through a VPC endpoint
* `public` - a route table that provides full bidirectional connectivity
  to the internet

### Networks
The network stack contains two public and two private subnets.

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

### GuardDuty
Amazon GuardDuty is a service that analyzes CloudTrail and VPC flow / DNS
logs for signs of malicious activity. The GuardDuty template sets up
GuardDuty and configures email notifications for GuardDuty findings.

### KMS
The KMS stack will create a KMS key that can be used to encrypt secrets
for different purposes. The KMS key policy allows everyone to manage
the key which means that access to the key is fully controlled by IAM
policies of the users and roles on the account.

The stack also contains an alias that makes it easier to use that key.

### Buckets
The buckets stack contains infra-level buckets such as a bucket for build
artifacts and storing account-wide logs.
