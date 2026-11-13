IMAGE ?= claude-dev
ENV_FILE ?= .env
CLAUDE_CONFIG_VOLUME ?= claude-config

.PHONY: help build run check clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build -t $(IMAGE) .

run: ## Run the container with .env, /app mounted, and persistent Claude auth
	docker run -it --rm --env-file $(ENV_FILE) \
		-v "$(CURDIR):/app" \
		-v "$(CLAUDE_CONFIG_VOLUME):/root/.claude" \
		-e CLAUDE_CONFIG_DIR=/root/.claude \
		$(IMAGE)

check: ## Validate required files and that .env is not tracked
	@test -f .env.example || { echo "Missing .env.example"; exit 1; }
	@if git ls-files --error-unmatch .env >/dev/null 2>&1; then echo ".env is tracked in git"; exit 1; else echo "OK: .env is not tracked"; fi
	@if git check-ignore -q .env; then echo "OK: .env is ignored"; else echo ".env is not ignored"; exit 1; fi
	@test -f Dockerfile && echo "OK: Dockerfile present"

clean: ## Remove the Docker image
	docker rmi $(IMAGE) 2>/dev/null || true
