# Salt Minion Tests

Checks:

- Check `salt-minion` service is started and responds to `test.version` with the correct version.
- Check `salt-minion` service is started and responds to `test.ping` with `True` when the minion is accepted by the master using signed keys.
- Check `salt-minion` service is started and load custom configuration.
