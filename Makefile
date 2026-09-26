PORT         := 8001
IMAGE_NAME   := tinyapi
CONTAINER    := tinyapi
PYTHON       := 3.11
VENV         := .venv
REPLICAS     := 1 2 3
REPLICA_PORTS := 8001 8002 8003
OTEL_ENDPOINT ?=
OTEL_FLAGS   := --add-host=host.docker.internal:host-gateway \
                $(if $(OTEL_ENDPOINT),-e OTEL_EXPORTER_OTLP_ENDPOINT=$(OTEL_ENDPOINT))

MAKEFLAGS += --silent

.PHONY: help create-env activate-env install run test \
        docker-build docker-run docker-run-indefinitely docker-stop \
        docker-run-replicas docker-stop-replicas \
        start-locust stop-locust otel-up otel-down

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n\nTargets:\n"} \
	     /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ── Dev environment ──────────────────────────────────────────────────────────

create-env: ## Create .venv with Python $(PYTHON)
	uv venv --python $(PYTHON) $(VENV)
	echo "$(VENV) created"

activate-env: ## Print the command to activate the venv
	echo "Run:  source $(VENV)/bin/activate"

install: ## Install runtime + dev dependencies
	uv pip install --python $(VENV)/bin/python -r requirements.txt -r requirements-dev.txt

run: ## Start uvicorn on port $(PORT) with auto-reload
	$(VENV)/bin/uvicorn main:app --reload --host 0.0.0.0 --port $(PORT)

test: ## Run the test suite
	PYTHONPATH=. $(VENV)/bin/pytest -v

# ── Single container ─────────────────────────────────────────────────────────

docker-build: ## Build the Docker image
	docker build -t $(IMAGE_NAME) .

docker-run: docker-build ## Build and run a single container on port $(PORT) (foreground)
	docker run --rm -p $(PORT):8000 -e PORT=$(PORT) $(OTEL_FLAGS) $(IMAGE_NAME)

docker-run-indefinitely: docker-stop-replicas docker-stop docker-build ## Deploy single container with restart unless-stopped
	docker run -d \
		--name $(CONTAINER) \
		--restart unless-stopped \
		-p $(PORT):8000 \
		-e PORT=$(PORT) \
		$(OTEL_FLAGS) \
		$(IMAGE_NAME) \
		uvicorn main:app --host 0.0.0.0 --port 8000 --root-path /tools/tinyapi

docker-stop: ## Stop and remove the single container
	docker stop $(CONTAINER) 2>/dev/null || true
	docker rm   $(CONTAINER) 2>/dev/null || true

# ── 3-replica cluster (nginx round-robin on ports 8001/8002/8003) ─────────────

docker-run-replicas: docker-stop docker-stop-replicas docker-build ## Deploy 3 replicas on ports 8001, 8002, 8003
	docker run -d --name tinyapi-1 --restart unless-stopped \
		-p 8001:8000 -e PORT=8001 $(OTEL_FLAGS) $(IMAGE_NAME) \
		uvicorn main:app --host 0.0.0.0 --port 8000 --root-path /tools/tinyapi
	docker run -d --name tinyapi-2 --restart unless-stopped \
		-p 8002:8000 -e PORT=8002 $(OTEL_FLAGS) $(IMAGE_NAME) \
		uvicorn main:app --host 0.0.0.0 --port 8000 --root-path /tools/tinyapi
	docker run -d --name tinyapi-3 --restart unless-stopped \
		-p 8003:8000 -e PORT=8003 $(OTEL_FLAGS) $(IMAGE_NAME) \
		uvicorn main:app --host 0.0.0.0 --port 8000 --root-path /tools/tinyapi
	@echo "Replicas running — nginx round-robin across :8001 :8002 :8003"

docker-stop-replicas: ## Stop and remove the 3 replicas
	docker stop tinyapi-1 tinyapi-2 tinyapi-3 2>/dev/null || true
	docker rm   tinyapi-1 tinyapi-2 tinyapi-3 2>/dev/null || true

# ── Observability (OpenTelemetry) ─────────────────────────────────────────────

otel-up: ## Start Grafana LGTM backend (OTLP on :4317/:4318, Grafana UI on :3000)
	docker run -d --name otel-lgtm --restart unless-stopped \
		-p 3000:3000 -p 4317:4317 -p 4318:4318 grafana/otel-lgtm
	@echo "Grafana at http://localhost:3000 (admin/admin)"
	@echo "Local:  OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 make run"
	@echo "Docker: make docker-run OTEL_ENDPOINT=http://host.docker.internal:4318"

otel-down: ## Stop and remove the Grafana LGTM backend
	docker stop otel-lgtm 2>/dev/null || true
	docker rm   otel-lgtm 2>/dev/null || true

# ── Load testing ──────────────────────────────────────────────────────────────

start-locust: ## Start Locust load test UI at http://localhost:8089
	$(VENV)/bin/locust

stop-locust: ## Kill the Locust process (frees port 8089)
	fuser -k 8089/tcp
