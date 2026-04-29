# Keys Mount Point Tests

Checks:

- The container starts properly with `SALT_MASTER_SIGN_PUBKEY=True` and a mounted keys directory.
- The keys directory contains the expected files with correct permissions:
  - `master.pem` — mode `400`, owned by `salt` user, group `root`
  - `master.pub` — mode `644`, owned by `salt` user, group `root`
  - `master_pubkey_signature` — mode `644`, owned by `salt` user and group
  - `master_sign.pem` — mode `400`, owned by `salt` user and group
  - `master_sign.pub` — mode `644`, owned by `salt` user and group
- The `app:gen-signed-keys` command runs successfully and outputs the generated keys directory path.
- The generated signed keys directory exists under `keys/generated/`.
- The generated signed keys directory contains the expected files with correct permissions:
  - `master_pubkey_signature` — mode `644`, owned by `salt` user and group
  - `master_sign.pem` — mode `400`, owned by `salt` user and group
  - `master_sign.pub` — mode `644`, owned by `salt` user and group
