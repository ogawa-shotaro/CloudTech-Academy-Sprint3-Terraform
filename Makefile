.PHONY: fmt validate tflint checkov trivy-config trivy-image check pre-commit-install

fmt:
	terraform fmt -recursive

validate:
	@for d in environments/*/; do \
		echo "==> terraform validate: $$d"; \
		(cd $$d && terraform init -backend=false -input=false >/dev/null && terraform validate); \
	done

tflint:
	tflint --init --config=$(CURDIR)/.tflint.hcl
	tflint --config=$(CURDIR)/.tflint.hcl --recursive

checkov:
	checkov -d . --config-file .checkov.yaml

trivy-config:
	trivy config .

trivy-image:
	@test -n "$(IMAGE)" || (echo "Usage: make trivy-image IMAGE=<image:tag>"; exit 1)
	trivy image $(IMAGE)

check: fmt validate tflint checkov

pre-commit-install:
	pre-commit install
