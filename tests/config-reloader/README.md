# Config Reloader Tests

Checks:

- The container starts properly with `SALT_RESTART_MASTER_ON_CONFIG_CHANGE=True`.
- Initial configuration values are correct:
  - `file_buffer_size` equals `1048576` (default).
  - `yaml_utf8` is empty (not set).
- After updating `file_buffer_size` to `2097152` in a config file, `salt-master` reloads and the new value is applied.
- After creating a new `yaml_utf8.conf` file with `yaml_utf8: True`, `salt-master` reloads and the new value is applied.
- The `config-reloader` supervisor log records exactly one reload after the first config change, and exactly two reloads after the second.
