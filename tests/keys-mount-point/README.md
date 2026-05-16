# Keys Mount Point Tests

These tests cover how the salt-master keys are provisioned into the mounted
keys directory, including the Salt 3008.0 change where master keys are **copied**
(no longer symlinked) so the `localfs_key` cache driver accepts them.

Every scenario asserts that `salt-master` reaches the `RUNNING` state under
supervisord and that the container log does **not** contain the Salt 3008.0
`SaltCacheError: ... is not a valid key path` regression.

## Scenario 1 — Generated keys on a mounted keys volume (no secrets)

- The container starts with `SALT_MASTER_SIGN_PUBKEY=True` and a mounted keys directory.
- The keys directory contains the expected files with correct permissions:
  - `master.pem` — mode `400`, owned by `salt` user
  - `master.pub` — mode `644`, owned by `salt` user
  - `master_pubkey_signature` — mode `644`, owned by `salt` user
  - `master_sign.pem` — mode `400`, owned by `salt` user
  - `master_sign.pub` — mode `644`, owned by `salt` user
- `master.pem` and `master_sign.pem` are **regular files (not symlinks)**.
- `app:gen-signed-keys` runs successfully and outputs the generated keys directory path.
- The generated signed keys directory exists under `keys/generated/` with the
  expected files and permissions.

## Scenario 2 — Secret provided, fresh keys volume

Simulates a careless full keys-volume bind mount together with
`SALT_MASTER_KEY_FILE`:

- The secret key-pair is **copied** into the keys directory as a regular file.
- The copied keys match the secret.

## Scenario 3 — Secret provided, legacy symlinked keys (migration)

Simulates upgrading from a &lt;3008 image where keys were symlinked:

- The pre-existing `master.{pem,pub}` symlinks are removed and replaced by a
  copy of the secret (regular files).
- The log contains the `Replacing legacy symlinked master keys` message.

## Scenario 4 — Secret provided, matching regular keys

- A pre-existing regular key-pair that matches the secret is kept as-is.
- The log reports the keys match the provided secret (no warning).

## Scenario 5 — Secret provided, mismatching regular keys

- A pre-existing regular key-pair that does **not** match the secret is **not**
  overwritten: the on-disk key wins and the secret is ignored.
- A `WARN` is logged and the container still starts (non-fatal).

## Scenario 6 — Secret provided, regular `master.pem` without `master.pub`

Guards the regression where a missing public key caused the on-disk **private**
key to be silently overwritten by the secret. The provisioning decision is
governed solely by the private key:

- A pre-existing regular `master.pem` (no `master.pub`) that does **not** match
  the secret is **not** overwritten — the on-disk private key wins and the
  secret is ignored.
- `salt-master` regenerates `master.pub` from the on-disk `master.pem` as a
  regular file.
- A `WARN` is logged and the container still starts (non-fatal).
