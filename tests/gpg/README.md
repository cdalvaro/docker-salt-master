# Salt GPG Renderer Tests

Checks:

- The container starts properly with a `roots` (read-only) and a `keys` directory mounted.
- An external `salt-minion` starts and is accepted by the master.
- The GPG-encrypted pillar value `foo:encrypted` decrypts correctly and contains `Hello, test.minion!`.
