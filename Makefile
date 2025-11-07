.PHONY: help tools check apply plan destroy test setup-kind install-kind delete-kind install-kubectl install-python install-terraform

# Normalized host OS/ARCH (refactored once, reused everywhere)
OS_RAW := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH_RAW := $(shell uname -m)
OS := ${OS_RAW}
ARCH := ${ARCH_RAW}

INFRA_DIR := ./infra

# Map common architecture names to download naming conventions
ifeq (${ARCH_RAW},x86_64)
	ARCH := amd64
endif
ifeq (${ARCH_RAW},aarch64)
	ARCH := arm64
endif

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

tools: install-kind install-kubectl install-python install-terraform ## Install all required tools into ./bin and .venv (prerequisite for other targets)

install-kind: ## Install KIND into ./bin if not already installed
	@mkdir -p ./bin
	@if ! command -v ./bin/kind &> /dev/null; then \
		echo "KIND not found in ./bin. Installing KIND v0.30.0 for ${OS}/${ARCH}..."; \
		case "${OS}" in \
		  darwin|linux) curl -Lo ./bin/kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-${OS}-${ARCH} ;; \
		  *) echo "Unsupported OS: ${OS}"; exit 1 ;; \
		esac; \
		chmod +x ./bin/kind; \
	else \
		echo "KIND is already installed in ./bin: $$(./bin/kind --version)"; \
	fi

install-kubectl: ## Install kubectl into ./bin if not already installed
	@mkdir -p ./bin
	@if ! command -v ./bin/kubectl &> /dev/null; then \
		echo "kubectl not found in ./bin. Installing kubectl v1.34.0 for ${OS}/${ARCH}..."; \
		case "${OS}" in \
		  darwin|linux) curl -Lo ./bin/kubectl "https://dl.k8s.io/release/v1.34.0/bin/${OS}/${ARCH}/kubectl" ;; \
		  *) echo "Unsupported OS: ${OS}"; exit 1 ;; \
		esac; \
		chmod +x ./bin/kubectl; \
	else \
		echo "kubectl is already installed in ./bin: $$(./bin/kubectl version --client)"; \
	fi

install-terraform: ## Install Terraform into ./bin if not already installed
	@mkdir -p ./bin
	@if ! command -v ./bin/terraform &> /dev/null; then \
		echo "Terraform not found in ./bin. Installing Terraform v1.9.8 for ${OS}/${ARCH}..."; \
		curl -Lo ./bin/terraform.zip "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_${OS}_${ARCH}.zip"; \
		unzip -o ./bin/terraform.zip -d ./bin/; \
		rm ./bin/terraform.zip; \
		chmod +x ./bin/terraform; \
	else \
		echo "Terraform is already installed in ./bin: $$(./bin/terraform version)"; \
	fi

install-python: ## Install Python virtual environment into .venv if not already installed
	@if [ ! -d ".venv" ]; then \
		echo "Creating Python virtual environment in .venv..."; \
		python3 -m venv .venv; \
		. .venv/bin/activate; \
		pip install --upgrade pip; \
		REQ_FILE="$(INFRA_DIR)/modules/password-generator/dynamic/requirements.txt"; \
		if [ -f "$$REQ_FILE" ]; then \
			pip install -r "$$REQ_FILE"; \
		fi; \
	else \
		echo "Python virtual environment .venv already exists."; \
	fi
	@export PATH=$$(pwd)/.venv/bin:$$PATH

KIND = ./bin/kind
KUBECTL = ./bin/kubectl
TERRAFORM = ./bin/terraform
PYTHON = .venv/bin/python3

check: tools ## Check and format Terraform configurations
	@echo "Checking and formatting Terraform configurations in $(INFRA_DIR)"
	$(TERRAFORM) -chdir=$(INFRA_DIR) init -backend=false -upgrade && \
	$(TERRAFORM) -chdir=$(INFRA_DIR) fmt -write=true -recursive  && \
	$(TERRAFORM) -chdir=$(INFRA_DIR) validate -json -no-color  

apply: tools ## Apply Terraform configurations
	@echo "Applying Terraform configurations in $(INFRA_DIR)"
	$(TERRAFORM) -chdir=$(INFRA_DIR) apply -auto-approve tfplan

plan: tools ## Generate Terraform plan
	@echo "Terraform Plan for $(INFRA_DIR)"
	$(TERRAFORM) -chdir=$(INFRA_DIR) init -upgrade && \
	$(TERRAFORM) -chdir=$(INFRA_DIR) plan -out=tfplan

destroy: tools ## Fully destroy all Terraform resources
	$(TERRAFORM) -chdir=$(INFRA_DIR) init -upgrade && \
	$(TERRAFORM) -chdir=$(INFRA_DIR) destroy

test: setup-kind ## Ensure KIND cluster then run all Terraform tests (auto-discovers modules)
	@echo "Running Terraform unit tests (grouped by module)"
	@# Find unique module roots that contain at least one *.tftest.hcl
	@set -e; \
	export KUBECONFIG=$$($(KIND) get kubeconfig --name kind); \
	MODULE_DIRS=$$(find . -type f -name "*.tftest.hcl" | while read tf; do \
		candidate=$$(dirname $$tf); \
		if [ -f "$$candidate/../main.tf" ]; then candidate="$$candidate/.."; fi; \
		echo $$candidate; \
	done | sort -u); \
	if [ -z "$$MODULE_DIRS" ]; then \
		echo "No *.tftest.hcl files found"; \
		exit 0; \
	fi; \
	for dir in $$MODULE_DIRS; do \
		echo "=== Terraform tests for module: $$dir"; \
		$(TERRAFORM) -chdir="$$dir" init -backend=false -upgrade; \
		$(TERRAFORM) -chdir="$$dir" test -verbose || exit 1; \
	done

setup-kind: tools delete-kind ## Set up a KIND Kubernetes cluster (accepts NODE_IMAGE from command line, defaults to kindest/node:v1.34.1)
	@echo "Setting up KIND cluster"
	@NODE_IMAGE=$${NODE_IMAGE:-kindest/node:v1.34.0}; \
	if $(KIND) get clusters 2>/dev/null | grep -q '^kind$$'; then \
		 echo "KIND cluster already exists; reusing."; \
	else \
		$(KIND) create cluster --image $$NODE_IMAGE; \
	fi; \
	echo "Waiting for KIND cluster to be ready..."; \
	$(KUBECTL) wait --for=condition=Ready nodes --all --timeout=300s

delete-kind: tools ## Delete KIND Kubernetes cluster (accepts CLUSTER_NAME env var, defaults to 'kind')
	@CLUSTER_NAME=$${CLUSTER_NAME:-kind}; \
	if $(KIND) get clusters 2>/dev/null | grep -q "^$$CLUSTER_NAME$$"; then \
		$(KIND) delete cluster --name $$CLUSTER_NAME; \
		echo "Cluster '$$CLUSTER_NAME' deleted."; \
	else \
		echo "Cluster '$$CLUSTER_NAME' not found; nothing to delete."; \
	fi