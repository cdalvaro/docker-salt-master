# Check if Docker is installed
DOCKER := $(shell command -v docker 2> /dev/null)

# Check if Podman is installed
PODMAN := $(shell command -v podman 2> /dev/null)

# If neither Docker nor Podman is installed, exit with an error
ifeq (,$(or $(DOCKER),$(PODMAN)))
$(error "Neither Docker nor Podman is installed.")
endif

# If Docker is installed, use it instead of Podman
ifdef DOCKER
CONTAINER_ENGINE := docker
else
CONTAINER_ENGINE := podman
endif

IMAGE_NAME := ghcr.io/cdalvaro/docker-salt-master
CONTAINER_NAME := salt_master

.PHONY: all help build release quickstart stop purge log

all: build

help:
	@echo ""
	@echo "-- Help Menu"
	@echo ""
	@echo "   1. make build        - build the docker-salt-master image"
	@echo "   2. make release      - build the docker-salt-master image and tag it"
	@echo "   3. make quickstart   - start docker-salt-master"
	@echo "   4. make stop         - stop docker-salt-master"
	@echo "   5. make purge        - stop and remove the container"
	@echo "   6. make log          - view log"

build:
	$(CONTAINER_ENGINE) build --tag=$(IMAGE_NAME):latest . \
		--build-arg=BUILD_DATE="$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")" \
		--build-arg=VCS_REF="$(shell git rev-parse --short HEAD)"

release: build
	$(CONTAINER_ENGINE) tag $(IMAGE_NAME):latest \
		$(IMAGE_NAME):$(shell cat VERSION)

quickstart:
	@echo "Creating volumes..."
	$(CONTAINER_ENGINE) volume create salt-master-keys
	$(CONTAINER_ENGINE) volume create salt-master-logs
	@echo "Starting docker-salt-master container..."
	$(CONTAINER_ENGINE) run --name=$(CONTAINER_NAME) --detach \
		--publish=4505:4505/tcp --publish=4506:4506/tcp \
		--env "PUID=$(shell id -u)" --env "PGID=$(shell id -g)" \
		--env SALT_LOG_LEVEL=info \
		--volume $(shell pwd)/roots/:/home/salt/data/srv/ \
		--volume salt-master-keys:/home/salt/data/keys/ \
		--volume salt-master-logs:/home/salt/data/logs/ \
		$(IMAGE_NAME):latest
	@echo "Type 'make log' for the log"

stop:
	@echo "Stopping container..."
	$(CONTAINER_ENGINE) stop $(CONTAINER_NAME) > /dev/null

purge: stop
	@echo "Removing stopped container..."
	$(CONTAINER_ENGINE) rm $(CONTAINER_NAME) > /dev/null
	@echo "Removing volumes..."
	$(CONTAINER_ENGINE) volume rm salt-master-keys
	$(CONTAINER_ENGINE) volume rm salt-master-logs

log:
	$(CONTAINER_ENGINE) logs --follow $(CONTAINER_NAME)
