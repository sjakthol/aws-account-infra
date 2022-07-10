# Mapping from long region names to shorter ones that is to be
# used in the stack names
AWS_eu-north-1_PREFIX = en1
AWS_eu-west-1_PREFIX = ew1
AWS_us-east-1_PREFIX = ue1

# Some defaults
AWS ?= aws
AWS_REGION ?= eu-west-1
AWS_CMD := $(AWS) --region $(AWS_REGION)

STACK_REGION_PREFIX := $(AWS_$(AWS_REGION)_PREFIX)

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
deploy-infra-sso: EXTRA_ARGS = --parameter-overrides InstanceArn=$(shell $(AWS_CMD) sso-admin list-instances --query 'Instances[0].InstanceArn' --output text)
deploy-infra-ec2key: EXTRA_ARGS = --parameter-overrides PublicKeyMaterialSjakthol="$(shell cat ~/.ssh/id_ed25519.pub)"

BUILD_RESOURCES_BUCKET = $(shell aws cloudformation list-exports --query 'Exports[?Name==`infra-buckets-BuildResourcesBucket`].Value' --output text)
ORG_ID = $(shell $(AWS_CMD) organizations describe-organization --query Organization.Id --output text)
MEMBERS_OU_ID = $(shell $(AWS_CMD) organizations list-organizational-units-for-parent --parent-id $(ORG_ROOT_ID) --query 'OrganizationalUnits[?Name==`Members`].Id' --output text)
ORG_ROOT_ID = $(shell $(AWS_CMD) organizations list-roots --query Roots[0].Id --output text)
deploy-infra-stacksets: EXTRA_ARGS = --parameter-overrides OrganizationalUnit=$(MEMBERS_OU_ID) PublicKeyMaterialSjakthol="$(shell cat ~/.ssh/id_ed25519.pub)"
deploy-infra-stacksets: upload-templates
upload-templates:
	$(AWS_CMD) s3 cp templates/infra-buckets.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-buckets.yaml
	$(AWS_CMD) s3 cp templates/infra-ec2key.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-ec2key.yaml
	$(AWS_CMD) s3 cp templates/infra-vpc.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-vpc.yaml


deploy-infra-log-archive: EXTRA_ARGS = --parameter-overrides OrganizationId=$(ORG_ID)

# Concrete deploy and delete targets for autocompletion
$(addprefix deploy-,$(basename $(notdir $(wildcard templates/*.yaml)))):
$(addprefix delete-,$(basename $(notdir $(wildcard templates/*.yaml)))):