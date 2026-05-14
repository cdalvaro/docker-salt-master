# GitFS Tests

Checks:

- The GitFS SSH key pair (`gitfs_ssh` / `gitfs_ssh.pub`) is present in `tests/gitfs/data/keys/gitfs/` before the container starts.
- The container starts properly with the SSH key mounted.
- `pygit2` is installed at the expected version (`1.19.2`).
- `salt-run fileserver.update` successfully updates the GitFS repositories.
- The fileserver file list contains `test.txt` (served from the GitFS remote).
- An external `salt-minion` starts and is accepted by the master.
- A Salt test state confirms the pillar `docker-salt-master-test:email` is present on the minion.
- `state.apply` executes successfully and creates `/tmp/my_file.txt` on the minion.
