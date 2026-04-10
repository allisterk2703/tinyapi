.PHONY: create-env activate-env install run test docker-build docker-run docker-run-indefinitely docker-stop start-locust stop-locust

PORT=8001
IMAGE_NAME=tinyapi
CONTAINER_NAME=tinyapi

MAKEFLAGS += --silent

PYTHON_VERSION := 3.11
VENV_PATH := .venv

create-env:
	uv venv --python $(PYTHON_VERSION) $(VENV_PATH)
	echo "$(VENV_PATH) created successfully"

activate-env:
	echo "Run the following command:"
	echo "  source $(VENV_PATH)/bin/activate"

install:
	$(VENV_PATH)/bin/pip install -r requirements.txt -r requirements-dev.txt

run:
	$(VENV_PATH)/bin/uvicorn main:app --reload --host 0.0.0.0 --port $(PORT)

test:
	PYTHONPATH=. $(VENV_PATH)/bin/pytest -v

docker-build:
	docker build -t $(IMAGE_NAME) .

docker-run: docker-build
	docker run -p $(PORT):8000 $(IMAGE_NAME)

docker-run-indefinitely: docker-stop docker-build
	docker run -d \
		--name $(CONTAINER_NAME) \
		--restart unless-stopped \
		-p $(PORT):8000 \
		$(IMAGE_NAME) \
		uvicorn main:app --host 0.0.0.0 --port 8000 --root-path /tinyapi

docker-stop:
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true

start-locust:
	$(VENV_PATH)/bin/locust

stop-locust:
	fuser -k 8089/tcp
