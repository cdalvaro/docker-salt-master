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
	@docker build --tag=cdalvaro/docker-salt-master:latest . \
		--build-arg=BUILD_DATE="$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")" \
		--build-arg=VCS_REF="$(shell git rev-parse --short HEAD)"

release: build
	@docker tag cdalvaro/docker-salt-master:latest \
		cdalvaro/docker-salt-master:$(shell cat VERSION)

quickstart:
	@echo "Starting docker-salt-master container..."
	@docker run --name='docker-salt-master-demo' --detach \
		--publish=4505:4505/tcp --publish=4506:4506/tcp \
		--env "PUID=$(shell id -u)" --env "PGID=$(shell id -g)" \
		--env SALT_LOG_LEVEL=info \
		--volume $(shell pwd)/roots/:/home/salt/data/srv/ \
		--volume $(shell pwd)/keys/:/home/salt/data/keys/ \
		--volume $(shell pwd)/logs/:/home/salt/data/logs/ \
		cdalvaro/docker-salt-master:latest
	@echo "Type 'make log' for the log"

stop:
	@echo "Stopping container..."
	@docker stop docker-salt-master-demo > /dev/null

purge: stop
	@echo "Removing stopped container..."
	@docker rm docker-salt-master-demo > /dev/null

log:
	@docker logs --follow docker-salt-master-demo
