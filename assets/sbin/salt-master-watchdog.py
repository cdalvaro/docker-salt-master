#!/usr/bin/env python3

import logging
import os
import subprocess
import sys

from supervisor.childutils import listener


def main():
    logging.basicConfig(
        stream=sys.stderr,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s: %(message)s",
    )
    logger = logging.getLogger("salt-master-watchdog")

    logger.info("salt-master monitor started")

    while True:
        try:
            headers, data = listener.wait(sys.stdin, sys.stdout)
            data = dict([pair.split(":") for pair in data.split(" ")])

            logger.debug("Headers: %r", repr(headers))
            logger.debug("Event Data: %r", repr(data))

            event_name = headers.get("eventname", "")
            process_name = data.get("processname", "")

            first_run_flag = "/tmp/salt-master-watchdog.first_run"

            if process_name == "salt-master" and event_name == "PROCESS_STATE_RUNNING":
                if not os.path.exists(first_run_flag):
                    logger.info(
                        "salt-master started for the first time, nothing to do now..."
                    )
                    with open(first_run_flag, "w") as f:
                        f.write("initialized")
                else:
                    logger.info("salt-master restarted, restarting salt-api...")
                    subprocess.call(
                        ["supervisorctl", "restart", "salt-api"], stdout=sys.stderr
                    )

        except Exception as e:
            logger.critical("Unexpected Exception: %s", str(e))
            listener.fail(sys.stdout)
            exit(1)
        else:
            listener.ok(sys.stdout)


if __name__ == "__main__":
    main()
