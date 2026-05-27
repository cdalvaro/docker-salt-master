# Salt Minion Tests

Checks:

- **Built-in minion running** - Starts the container with `SALT_MINION_ENABLED=True` and verifies that:
  - The `salt-minion` process is running inside the container.
  - `test.version` returns the expected Salt version for the minion.

- **Built-in minion with signed keys** - Starts the container with `SALT_MINION_ENABLED=True`, `SALT_MASTER_SIGN_PUBKEY=True`, and a mounted keys directory, and verifies that:
  - The minion keys directory (`keys/<SALT_MINION_ID>/`) is created inside the mounted keys volume.
  - `test.ping` returns `True` for the built-in minion.

- **Built-in minion with custom configuration** - Starts the container reusing the previous keys and a mounted `minion_config` directory containing a custom `pyenv.conf`, and verifies that:
  - `test.ping` still returns `True` (keys are correctly reused).
  - `config.get pyenv.root` returns the custom path defined in `pyenv.conf`.
