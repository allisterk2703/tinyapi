.PHONY: install run test docker-build docker-run docker-run-indefinitely docker-stop

PORT=8001
IMAGE_NAME=tinyapi
CONTAINER_NAME=tinyapi

MAKEFLAGS += --silent

install:
	pip install -r requirements.txt -r requirements-dev.txt

run:
	uvicorn main:app --reload --host 0.0.0.0 --port $(PORT)

test:
	PYTHONPATH=. pytest -v

docker-build:
	docker build -t $(IMAGE_NAME) .

docker-run: docker-build
	docker run -p $(PORT):8000 $(IMAGE_NAME)

docker-run-indefinitely: docker-build
	docker run -d \
		--name $(CONTAINER_NAME) \
		--restart unless-stopped \
		-p $(PORT):8000 \
		$(IMAGE_NAME)

docker-stop:
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true
