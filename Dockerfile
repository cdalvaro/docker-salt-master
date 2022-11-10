FROM ubuntu:jammy-20221101

ARG BUILD_DATE
ARG VCS_REF

# https://github.com/saltstack/salt/releases
ENV SALT_VERSION="3005.1-2"
ENV IMAGE_VERSION="${SALT_VERSION}_1"

ENV SALT_DOCKER_DIR="/etc/docker-salt" \
    SALT_ROOT_DIR="/etc/salt" \
    SALT_CACHE_DIR='/var/cache/salt' \
    SALT_USER="salt" \
    SALT_HOME="/home/salt"

ENV SALT_BUILD_DIR="${SALT_DOCKER_DIR}/build" \
    SALT_RUNTIME_DIR="${SALT_DOCKER_DIR}/runtime" \
    SALT_DATA_DIR="${SALT_HOME}/data"

ENV SALT_CONFS_DIR="${SALT_DATA_DIR}/config" \
    SALT_KEYS_DIR="${SALT_DATA_DIR}/keys" \
    SALT_BASE_DIR="${SALT_DATA_DIR}/srv" \
    SALT_LOGS_DIR="${SALT_DATA_DIR}/logs" \
    SALT_FORMULAS_DIR="${SALT_DATA_DIR}/3pfs"

RUN mkdir -p ${SALT_BUILD_DIR}
WORKDIR ${SALT_BUILD_DIR}

# Install packages
# hadolint ignore=DL3008
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
    sudo ca-certificates openssl apt-transport-https wget locales openssh-client gpg \
    python3 python3-dev libpython3-dev \
    python3-pip python3-setuptools python3-wheel \
    supervisor logrotate git gettext-base tzdata inotify-tools psmisc \
 && DEBIAN_FRONTEND=noninteractive update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX \
    locale-gen en_US.UTF-8 \
    dpkg-reconfigure locales \
 && DEBIAN_FRONTEND=noninteractive apt-get clean --yes \
 && rm -rf /var/lib/apt/lists/*

# Install saltstack
COPY assets/build ${SALT_BUILD_DIR}
RUN bash ${SALT_BUILD_DIR}/install.sh

COPY assets/runtime ${SALT_RUNTIME_DIR}
RUN chmod -R +x ${SALT_RUNTIME_DIR}

COPY assets/sbin/* /usr/local/sbin/

# Cleaning tasks
RUN rm -rf "${SALT_BUILD_DIR:?}"/*

# Entrypoint
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod +x /sbin/entrypoint.sh

# Shared resources
EXPOSE 4505 4506 8000
RUN mkdir -p "${SALT_BASE_DIR}" "${SALT_FORMULAS_DIR}" "${SALT_KEYS_DIR}" "${SALT_CONFS_DIR}" "${SALT_LOGS_DIR}"
VOLUME [ "${SALT_KEYS_DIR}", "${SALT_LOGS_DIR}" ]

LABEL org.opencontainers.image.title="Dockerized Salt Master"
LABEL org.opencontainers.image.description="salt-master ${SALT_VERSION} containerized"
LABEL org.opencontainers.image.documentation="https://github.com/cdalvaro/docker-salt-master/blob/${IMAGE_VERSION}/README.md"
LABEL org.opencontainers.image.url="https://github.com/cdalvaro/docker-salt-master"
LABEL org.opencontainers.image.source="https://github.com/cdalvaro/docker-salt-master.git"
LABEL org.opencontainers.image.authors="Carlos Álvaro <github@cdalvaro.io>"
LABEL org.opencontainers.image.vendor="cdalvaro"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.base.digest="sha256:42ba2dfce475de1113d55602d40af18415897167d47c2045ec7b6d9746ff148f"
LABEL org.opencontainers.image.base.name="ubuntu:jammy-20221101"
LABEL org.opencontainers.image.licenses="MIT"

WORKDIR ${SALT_HOME}
ENTRYPOINT [ "/sbin/entrypoint.sh" ]
CMD [ "app:start" ]
