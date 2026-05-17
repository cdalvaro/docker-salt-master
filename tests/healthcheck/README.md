# Healthcheck Tests

Checks:

- The container starts properly with Docker health check options configured (`--health-cmd`, `--health-start-period`, `--health-interval`, `--health-timeout`, `--health-retries`).
- Running `/usr/local/sbin/healthcheck` manually inside the container exits successfully.
- The container health status is `healthy` while `salt-master` is running.
- After stopping `salt-master` via `supervisorctl` and waiting for the health check to cycle, the container health status becomes `unhealthy`.
