all: build

help:
	@echo ""
	@echo "-- Help Menu"
	@echo ""
	@echo "   1. make build        - build the saltstack-master image"
	@echo "   2. make release      - build the saltstack-master image and tag it"
	@echo "   3. make quickstart   - start saltstack-master"
	@echo "   4. make stop         - stop saltstack-master"
	@echo "   5. make purge        - stop and remove the container"
	@echo "   6. make log          - view log"

build:
	@docker build --tag=cdalvaro/saltstack-master . \
	        --build-arg=BUILD_DATE="$(shell date +"%Y-%m-%d %H:%M:%S%:z")" \
		    --build-arg=VCS_REF="$(shell git rev-parse --short HEAD)" \

release: build
	@docker build --tag=cdalvaro/saltstack-master:$(shell cat VERSION) . \
	        --build-arg=BUILD_DATE="$(shell date +"%Y-%m-%d %H:%M:%S%:z")" \
		    --build-arg=VCS_REF="$(shell git rev-parse --short HEAD)" \

quickstart:
	@echo "Starting saltstack-master container..."
	@docker run --name='saltstack-master-demo' --detach \
		--publish=4505:4505/tcp --publish=4506:4506/tcp \
		--env "USERMAP_UID=$(shell id -u)" --env "USERMAP_GID=$(shell id -g)" \
		--env SALT_LOG_LEVEL=info \
		--volume $(shell pwd)/roots/:/home/salt/data/srv/ \
		--volume $(shell pwd)/keys/:/home/salt/data/keys/ \
		--volume $(shell pwd)/logs/:/home/salt/data/logs/ \
		cdalvaro/saltstack-master:latest
	@echo "Type 'make log' for the log"

stop:
	@echo "Stopping container..."
	@docker stop saltstack-master-demo > /dev/null

purge: stop
	@echo "Removing stopped container..."
	@docker rm saltstack-master-demo > /dev/null

log:
	@docker logs --follow saltstack-master-demo
