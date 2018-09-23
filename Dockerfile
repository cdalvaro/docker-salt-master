FROM ubuntu:18.04

LABEL maintainer="carlos.alvaro@citelan.es"
LABEL description="SaltStack master"
LABEL version="2018.3.2"

ENV SALT_DOCKER_DIR="/etc/salt-docker" \
    SALT_MASTER_DIR="/etc/salt/pki/master"

ENV SALT_BUILD_DIR="${SALT_DOCKER_DIR}/build" \
    SALT_KEYS_DIR="${SALT_DOCKER_DIR}/keys" \
    SALT_RUNTIME_DIR="${SALT_DOCKER_DIR}/runtime"

# Bootstrap script options:
# https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html#command-line-options
## -M: install Salt Master by default
## -N: Do not install salt-minion
## -X: Do not start daemons after installation
## -U: Fully upgrade the system prior to bootstrapping Salt
ENV SALT_BOOTSTRAP_OPTS='-M -N -X -U'

# Version of salt to install:
# https://github.com/saltstack/salt/releases
ENV SALT_GIT_RELEASE="v2018.3.2"

# Set non interactive mode
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update
RUN apt-get install --yes --quiet --no-install-recommends \
    ca-certificates apt-transport-https curl git vim python3 locales virt-what

# Configure locales
RUN update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX \
    locale-gen en_US.UTF-8 \
    dpkg-reconfigure locales

EXPOSE 4505/tcp 4506/tcp
RUN mkdir -p /srv ${SALT_KEYS_DIR}
VOLUME [ "/srv", "${SALT_KEYS_DIR}" ]

RUN mkdir -p ${SALT_BUILD_DIR}
WORKDIR ${SALT_BUILD_DIR}

RUN curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com
RUN sh bootstrap-salt.sh ${SALT_BOOTSTRAP_OPTS} git ${SALT_GIT_RELEASE}

RUN apt-get clean --yes
RUN rm -rf /var/lib/apt/lists/*

COPY assets/runtime ${SALT_RUNTIME_DIR}
RUN chmod -R +x ${SALT_RUNTIME_DIR}

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod +x /sbin/entrypoint.sh
WORKDIR ${SALT_DOCKER_DIR}

ENTRYPOINT [ "/sbin/entrypoint.sh" ]

