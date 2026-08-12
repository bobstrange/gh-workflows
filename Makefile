.PHONY: help release
.DEFAULT_GOAL := help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-12s %s\n", $$1, $$2}'

release: ## Tag the next release and move the major tag (BUMP=patch|minor|major)
	@scripts/release.sh $(BUMP)
