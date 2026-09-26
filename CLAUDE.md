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

Everything lives in `main.py` — a single FastAPI app (`app`) with three endpoints:

- `GET /health` — returns `{"status": "ok"}`
- `GET /random` — returns `{"value": <int 0–100>}`
- `GET /port` — returns `{"port": <int>}` (reads `PORT` env var, defaults to 8000)

Tests in `tests/test_api.py` use `fastapi.testclient.TestClient` (no running server needed).

Load testing is in `locustfile.py` — targets `http://127.0.0.1:8001` with a 3:1 `/random`:`/health` task ratio.

## Deployment

In production the app runs in Docker, bound to port 8000 internally and mapped to host port 8001. Nginx on the RPi5 proxies `allisterkohn.com/tools/tinyapi/` → `127.0.0.1:8001`. The `--root-path /tinyapi` flag is passed to uvicorn in `docker-run-indefinitely` so FastAPI generates correct OpenAPI URLs behind the proxy prefix.

CI/CD (`.github/workflows/ci-cd.yml`) runs on every push/PR to `main`: lint → test → Docker build.
