.PHONY: help release sync-pins
.DEFAULT_GOAL := help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-12s %s\n", $$1, $$2}'

sync-pins: ## Rewrite inline fallback pins from package.json / requirements.txt
	@scripts/sync-pins.sh

release: ## Tag the next release and move the major tag (BUMP=patch|minor|major)
	@scripts/release.sh $(BUMP)
