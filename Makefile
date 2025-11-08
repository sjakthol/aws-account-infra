# Mapping from long region names to shorter ones that is to be
# used in the stack names
AWS_eu-north-1_PREFIX = en1
AWS_eu-west-1_PREFIX = ew1
AWS_us-east-1_PREFIX = ue1

# Some defaults
AWS ?= aws
AWS_REGION ?= eu-west-1
AWS_CMD = $(AWS) --region $(AWS_REGION)

STACK_REGION_PREFIX = $(AWS_$(AWS_REGION)_PREFIX)

TAGS ?= Deployment=$(STACK_REGION_PREFIX)-account-infra

# Generic deployment and teardown targets
deploy-%:
	$(AWS_CMD) cloudformation deploy \
		--stack-name $(STACK_REGION_PREFIX)-$* \
		--tags $(TAGS) \
		--template-file templates/$*.yaml \
		--capabilities CAPABILITY_NAMED_IAM \
		$(EXTRA_ARGS)

delete-%:
	$(AWS_CMD) cloudformation delete-stack \
		--stack-name $(STACK_REGION_PREFIX)-$*

	$(AWS_CMD) cloudformation wait stack-delete-complete \
		--stack-name $(STACK_REGION_PREFIX)-$*

# Per-stack overrides
deploy-infra-sso: EXTRA_ARGS = --parameter-overrides InstanceArn=$(shell $(AWS_CMD) sso-admin list-instances --query 'Instances[0].InstanceArn' --output text | grep -v None)
deploy-infra-ec2key: EXTRA_ARGS = --parameter-overrides PublicKeyMaterialSjakthol="$(shell cat ~/.ssh/id_ed25519.pub)"

BUILD_RESOURCES_BUCKET = $(shell aws cloudformation list-exports --query 'Exports[?Name==`infra-buckets-BuildResourcesBucket`].Value' --output text)
MEMBERS_OU_ID = $(shell $(AWS_CMD) organizations list-organizational-units-for-parent --parent-id $(ORG_ROOT_ID) --query 'OrganizationalUnits[?Name==`Members`].Id' --output text)
ORG_ROOT_ID = $(shell $(AWS_CMD) organizations list-roots --query Roots[0].Id --output text)
BACKUP_ACCOUNT_ID = $(shell $(AWS_CMD) organizations list-accounts --query 'Accounts[?Name==`Backups 1`].Id' --output text)
deploy-infra-stacksets: EXTRA_ARGS = --parameter-overrides OrganizationalUnit=$(MEMBERS_OU_ID) PublicKeyMaterialSjakthol="$(shell cat ~/.ssh/id_ed25519.pub)" BackupAccountId=$(BACKUP_ACCOUNT_ID)
deploy-infra-stacksets: upload-templates
upload-templates:
	$(AWS_CMD) s3 cp templates/infra-buckets.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-buckets.yaml
	$(AWS_CMD) s3 cp templates/infra-ec2key.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-ec2key.yaml
	$(AWS_CMD) s3 cp templates/infra-github-actions.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-github-actions.yaml
	$(AWS_CMD) s3 cp templates/infra-vpc.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-vpc.yaml
	$(AWS_CMD) s3 cp templates/CDKToolkit.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/CDKToolkit.yaml

deploy-infra-billing-alarms: AWS_REGION = us-east-1

SUSPENDED_OU_ID = $(shell $(AWS_CMD) organizations list-organizational-units-for-parent --parent-id $(ORG_ROOT_ID) --query 'OrganizationalUnits[?Name==`Suspended`].Id' --output text)
deploy-infra-org-policies: AWS_REGION = us-east-1
deploy-infra-org-policies: EXTRA_ARGS = --parameter-overrides BackupAccountId=$(BACKUP_ACCOUNT_ID) SuspendedOu=$(SUSPENDED_OU_ID) MembersOu=$(MEMBERS_OU_ID)

CURRENT_IP_ADDRESS = $(shell curl -s https://checkip.amazonaws.com)
deploy-adhoc-instance: EXTRA_ARGS += --parameter-overrides SshAllowedIpAddress="$(CURRENT_IP_ADDRESS)"
deploy-adhoc-instance-arm64:
	$(MAKE) deploy-adhoc-instance STACK_REGION_PREFIX=$(STACK_REGION_PREFIX)-arm64 EXTRA_ARGS="--parameter-overrides Architecture=arm64 SshAllowedIpAddress=$(CURRENT_IP_ADDRESS)"
delete-adhoc-instance-arm64:
	$(MAKE) delete-adhoc-instance STACK_REGION_PREFIX=$(STACK_REGION_PREFIX)-arm64

deploy-adhoc-instance-x86:
	$(MAKE) deploy-adhoc-instance STACK_REGION_PREFIX=$(STACK_REGION_PREFIX)-x86 EXTRA_ARGS="--parameter-overrides Architecture=x86_64 SshAllowedIpAddress=$(CURRENT_IP_ADDRESS)"
delete-adhoc-instance-x86:
	$(MAKE) delete-adhoc-instance STACK_REGION_PREFIX=$(STACK_REGION_PREFIX)-x86

# Concrete deploy and delete targets for autocompletion
$(addprefix deploy-,$(basename $(notdir $(wildcard templates/*.yaml)))):
$(addprefix delete-,$(basename $(notdir $(wildcard templates/*.yaml)))):