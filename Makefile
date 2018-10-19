all: build

help:
	@echo ""
	@echo "-- Help Menu"
	@echo ""
	@echo "   1. make build        - build the saltstack-master image"
	@echo "   2. make quickstart   - start saltstack-master"
	@echo "   3. make stop         - stop saltstack-master"
	@echo "   4. make purge        - stop and remove the container"
	@echo "   5. make logs         - view logs"

build:
	@docker build --tag=cdalvaro/saltstack-master .

release: build
	@docker build --tag=cdalvaro/saltstack-master:$(shell cat VERSION) .

quickstart:
	@echo "Starting saltstack-master container..."
	@docker run --name='saltstack-master-demo' -d \
		--publish=4505:4505/tcp --publish=4506:4506/tcp \
		--env "USERMAP_UID=$(id -u)" --env "USERMAP_GID=$(id -g)" \
		--env SALT_LOG_LEVEL=info \
		--read-only --volume $(pwd)/srv/:/home/salt/data/srv/ \
		cdalvaro/saltstack-master:latest
	@echo "Type 'make logs' for the logs"

stop:
	@echo "Stopping container..."
	@docker stop saltstack-master-demo > /dev/null

purge: stop
	@echo "Removing stopped container..."
	@docker rm saltstack-master-demo > /dev/null

logs:
	@docker logs -d saltstack-master-demo
