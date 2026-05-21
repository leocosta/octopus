# Octopus — developer convenience targets.
#
# Usage:
#   make site-dev       Run the docs site locally with hot reload (port 4321).
#   make site-preview   Build + preview the site exactly as it ships to GitHub Pages.
#   make site-build     Sync content and run the production build only.
#   make site-clean     Wipe Astro/Vite caches and the dist/ output.
#   make help           Show this list.

SITE_DIR := site
SITE_URL := http://localhost:4321/octopus/
SITE_URL_PTBR := http://localhost:4321/octopus/pt-br/

.PHONY: help site-dev site-preview site-build site-clean site-install

help:
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

site-install: ## Install site dependencies (idempotent).
	cd $(SITE_DIR) && bun install

site-dev: site-install ## Sync content and start Astro dev server (hot reload on src/, not on docs/).
	cd $(SITE_DIR) && bun run sync-content
	@echo
	@echo "▶ EN     $(SITE_URL)"
	@echo "▶ PT-BR  $(SITE_URL_PTBR)"
	@echo "  (re-run 'make site-dev' if you edit files under docs/site/)"
	@echo
	cd $(SITE_DIR) && bun run dev

site-build: site-install ## Sync content and run astro check + astro build.
	cd $(SITE_DIR) && bun run sync-content && bun run build

site-preview: site-build ## Build then serve dist/ — the exact bundle that ships to GitHub Pages.
	@echo
	@echo "▶ EN     $(SITE_URL)"
	@echo "▶ PT-BR  $(SITE_URL_PTBR)"
	@echo
	cd $(SITE_DIR) && bun run preview

site-clean: ## Remove Astro, Vite, and build artifacts.
	rm -rf $(SITE_DIR)/.astro $(SITE_DIR)/node_modules/.vite $(SITE_DIR)/dist $(SITE_DIR)/src/content/docs
