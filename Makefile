# Mapping from long region names to shorter ones that is to be
# used in the stack names
AWS_eu-west-1_PREFIX = ew1
AWS_us-east-1_PREFIX = ue1

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

endef

$(foreach template, $(wildcard templates/*.yaml), $(eval $(call stack_template,$(template))))
