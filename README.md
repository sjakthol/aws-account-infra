This repository contains CloudFormation templates for an AWS infrastructure
setup that contains the following components:

* IAM roles, policies, groups and users
* VPC with route tables that provide varying level of access to / from the
  public internet
* CloudTrail audit logging to S3

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
to assume the `account-admin` role for performing administrative tasks.

It is advisable to create additional administrative groups and roles with
less privileges for users who only need to be able to perform specific
administrative tasks.

### VPC
The VPC included in the setup provides both IPv4 and IPv6 connectivity. The
key part of the template are the different route tables that provide different
levels of connectivity to any subnets that use those tables. The route tables
included in the setup are:
* `private` - a route table for fully private networks that provides both
  IPv4 and IPv6 connectivity to hosts in the VPC
* `private-with-endpoints` - a route table that also includes S3 access through
  a VPC endpoint
* `private-with-ipv6` - a route table that provides egress-only IPv6 connectivity
  to the internet
* `public` - a route table that provides full bidirectional IPv4 and IPv6
  connectivity to the internet

### CloudTrail
The CloudTrail setup included in this repository is pretty simple. The
CloudFormation stack includes an S3 bucket for the CloudTrail logs and
a global trail that logs to that bucket.
