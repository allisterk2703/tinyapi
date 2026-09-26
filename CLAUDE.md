# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make install                  # Install dependencies into .venv
make run                      # Run uvicorn on port 8001 (with --reload)
make test                     # Run pytest with PYTHONPATH=.
make docker-run-indefinitely  # Build image and run detached container with --restart unless-stopped
make docker-stop              # Stop and remove the container
make start-locust             # Open Locust UI at http://localhost:8089
make otel-up                  # Start grafana/otel-lgtm (OTLP on :4317/:4318, Grafana on :3000)
make otel-down                # Stop the LGTM backend
```

Run a single test file or test by name:

```bash
.venv/bin/pytest tests/test_api.py::test_health -v
```

Lint and format:

```bash
ruff check .
ruff format .
```

## Architecture

The app lives in `main.py` — a single FastAPI app (`app`) with three endpoints:

- `GET /health` — returns `{"status": "ok"}`
- `GET /random` — returns `{"value": <int 0–100>}`
- `GET /port` — returns `{"port": <int>}` (reads `PORT` env var, defaults to 8000)

Tests in `tests/test_api.py` use `fastapi.testclient.TestClient` (no running server needed).

Load testing is in `locustfile.py` — targets `http://127.0.0.1:8001` with a 3:1 `/random`:`/health` task ratio.

OpenTelemetry setup is in `telemetry.py` (`setup_telemetry(app)`, called from `main.py`). SDK tracer/meter providers are always installed; OTLP/HTTP exporters are only attached when `OTEL_EXPORTER_OTLP_ENDPOINT` is set (exporters read it from env and append `/v1/traces`, `/v1/metrics`). Resource: `service.name` from `OTEL_SERVICE_NAME` (default `tinyapi`), `service.instance.id` from `PORT`. `tests/test_telemetry.py` asserts spans via an in-memory exporter.

## Deployment

In production the app runs in Docker, bound to port 8000 internally and mapped to host port 8001. Nginx on the RPi5 proxies `allisterkohn.com/tools/tinyapi/` → `127.0.0.1:8001`. The `--root-path /tinyapi` flag is passed to uvicorn in `docker-run-indefinitely` so FastAPI generates correct OpenAPI URLs behind the proxy prefix.

Docker targets accept `OTEL_ENDPOINT=...` (e.g. `http://host.docker.internal:4318`), passed to containers as `OTEL_EXPORTER_OTLP_ENDPOINT`; `--add-host=host.docker.internal:host-gateway` makes that hostname work on the RPi (Linux).

CI/CD (`.github/workflows/ci-cd.yml`) runs on every push/PR to `main`: lint → test → Docker build.
