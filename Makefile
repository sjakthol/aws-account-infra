# Mapping from long region names to shorter ones that is to be
# used in the stack names
AWS_ap-northeast-1_PREFIX = an1
AWS_ap-northeast-2_PREFIX = an2
AWS_ap-south-1_PREFIX = as1
AWS_ap-southeast-1_PREFIX = as1
AWS_ap-southeast-2_PREFIX = as2
AWS_ca-central-1_PREFIX = cc1
AWS_eu-central-1_PREFIX = ec1
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
AWS_PROFILE ?= default

AWS_CMD := $(AWS) --profile $(AWS_PROFILE) --region $(AWS_REGION)

STACK_REGION_PREFIX := $(AWS_$(AWS_REGION)_PREFIX)

TAGS ?= Key=Deployment,Value=$(STACK_REGION_PREFIX)-account-infra

define stack_template =


validate-$(basename $(notdir $(1))): $(1)
	 $(AWS_CMD) cloudformation validate-template\
		--template-body file://$(1)

create-$(basename $(notdir $(1))): $(1)
	$(AWS_CMD) cloudformation create-stack \
		--stack-name $(STACK_REGION_PREFIX)-$(basename $(notdir $(1))) \
		--tags $(TAGS) \
		--template-body file://$(1) \
		--capabilities CAPABILITY_NAMED_IAM

update-$(basename $(notdir $(1))): $(1)
	$(AWS_CMD) cloudformation update-stack \
		--stack-name $(STACK_REGION_PREFIX)-$(basename $(notdir $(1))) \
		--tags $(TAGS) \
		--template-body file://$(1) \
		--capabilities CAPABILITY_NAMED_IAM

delete-$(basename $(notdir $(1))): $(1)
	$(AWS_CMD) cloudformation delete-stack \
		--stack-name $(STACK_REGION_PREFIX)-$(basename $(notdir $(1)))

endef

$(foreach template, $(wildcard templates/*.yaml), $(eval $(call stack_template,$(template))))
