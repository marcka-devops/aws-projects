# Marck Enterprise: local workflow. Works in Git Bash, Linux and macOS.
#   make help

STACKS := 10-network 20-security 30-data 40-storage 50-compute 60-delivery 70-self-service
REGION ?= us-east-1
STACK  ?=

-include infra/settings.env
export

TF = terraform -chdir=infra/stacks/$(STACK)

.PHONY: help bootstrap init plan apply destroy apply-all fmt validate lint test check diagrams

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'
	@echo "  Stacks: $(STACKS)"

bootstrap: ## Create the state bucket and GitHub OIDC roles (local state, run once)
	terraform -chdir=infra/stacks/00-bootstrap init
	terraform -chdir=infra/stacks/00-bootstrap apply

init: guard-STACK ## make init STACK=10-network
	$(TF) init -reconfigure -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="region=$(REGION)"

plan: init ## make plan STACK=10-network
	$(TF) plan -out=tfplan

apply: init ## make apply STACK=10-network (plans, then asks before applying)
	$(TF) apply

destroy: init ## make destroy STACK=60-delivery (run in reverse order)
	$(TF) destroy

apply-all: ## Apply every stack in dependency order
	@for s in $(STACKS); do $(MAKE) --no-print-directory apply STACK=$$s || exit 1; done

fmt: ## Format Terraform
	terraform fmt -recursive infra

validate: ## terraform validate every stack without touching state
	@for s in infra/stacks/*/; do \
		terraform -chdir=$$s init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$s validate -no-color | sed "s|^|$$s: |" || exit 1; \
	done

lint: ## tflint + cfn-lint (if installed)
	tflint --init --config "$(CURDIR)/.tflint.hcl" && tflint --recursive --config "$(CURDIR)/.tflint.hcl" --chdir infra
	cfn-lint infra/cloudformation/*.yaml

test: ## App and Lambda unit tests
	php app/tests/run_tests.php
	python -m unittest discover -s functions/tests

check: fmt validate test ## Everything CI runs that needs no extra tools

diagrams: ## Re-export the PNGs from docs/architecture/marck-enterprise.drawio (needs draw.io desktop)
	drawio --export --format png --page-index 1 --scale 2 --border 20 --output docs/architecture/delivery-workflow.png docs/architecture/marck-enterprise.drawio
	drawio --export --format png --page-index 2 --scale 1.5 --border 20 --output docs/architecture/aws-architecture.png docs/architecture/marck-enterprise.drawio

guard-%:
	@if [ -z "$($*)" ]; then echo "Set $*, for example: make $(MAKECMDGOALS) $*=10-network"; exit 1; fi
