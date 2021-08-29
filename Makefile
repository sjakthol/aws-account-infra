# Mapping from long region names to shorter ones that is to be
# used in the stack names
AWS_ap-northeast-1_PREFIX = an1
AWS_ap-northeast-2_PREFIX = an2
AWS_ap-south-1_PREFIX = as1
AWS_ap-southeast-1_PREFIX = as1
AWS_ap-southeast-2_PREFIX = as2
AWS_ca-central-1_PREFIX = cc1
AWS_eu-central-1_PREFIX = ec1
AWS_eu-north-1_PREFIX = en1
AWS_eu-west-1_PREFIX = ew1
AWS_eu-west-2_PREFIX = ew2
AWS_eu-west-3_PREFIX = ew3
AWS_sa-east-1_PREFIX = se1
AWS_us-east-1_PREFIX = ue1
AWS_us-east-2_PREFIX = ue2
AWS_us-west-1_PREFIX = uw1
AWS_us-west-2_PREFIX = uw2

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

BUILD_RESOURCES_BUCKET = $(shell aws cloudformation list-exports --query 'Exports[?Name==`infra-buckets-BuildResourcesBucket`].Value' --output text)
MEMBERS_OU_ID = $(shell $(AWS_CMD) organizations list-organizational-units-for-parent --parent-id $(ORG_ROOT_ID) --query 'OrganizationalUnits[?Name==`Members`].Id' --output text)
ORG_ROOT_ID = $(shell $(AWS_CMD) organizations list-roots --query Roots[0].Id --output text)
deploy-infra-stacksets: EXTRA_ARGS = --parameter-overrides OrganizationalUnit=$(MEMBERS_OU_ID)
deploy-infra-stacksets: upload-templates
upload-templates:
	$(AWS_CMD) s3 cp templates/infra-buckets.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-buckets.yaml
	$(AWS_CMD) s3 cp templates/infra-vpc.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-vpc.yaml
	$(AWS_CMD) s3 cp templates/infra-networks.yaml s3://$(BUILD_RESOURCES_BUCKET)/stacksets/infra-networks.yaml

# Concrete deploy and delete targets for autocompletion
$(addprefix deploy-,$(basename $(notdir $(wildcard templates/*.yaml)))):
$(addprefix delete-,$(basename $(notdir $(wildcard templates/*.yaml)))):