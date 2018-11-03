FROM ubuntu:xenial-20181005

LABEL maintainer="carlos.alvaro@citelan.es"
LABEL description="SaltStack master"
LABEL version="2018.3.3"

ENV SALT_DOCKER_DIR="/etc/docker-salt" \
    SALT_ROOT_DIR="/etc/salt" \
    SALT_USER="salt" \
    SALT_HOME="/home/salt"

ENV SALT_BUILD_DIR="${SALT_DOCKER_DIR}/build" \
    SALT_RUNTIME_DIR="${SALT_DOCKER_DIR}/runtime" \
    SALT_DATA_DIR="${SALT_HOME}/data"

ENV SALT_CONFS_DIR="${SALT_DATA_DIR}/config" \
    SALT_KEYS_DIR="${SALT_DATA_DIR}/keys" \
    SALT_BASE_DIR="${SALT_DATA_DIR}/srv"

# Bootstrap script options:
# https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html#command-line-options
## -M: install Salt Master by default
## -N: Do not install salt-minion
## -X: Do not start daemons after installation
## -U: Fully upgrade the system prior to bootstrapping Salt
## -V: Install Salt into virtualenv
## -a: Pip install all Python pkg dependencies for Salt
ENV SALT_BOOTSTRAP_OPTS='-M -N -X -U -Va'

# Release version to install
# https://github.com/saltstack/salt/releases
ENV SALT_GIT_RELEASE="v2018.3.3"

# Set non interactive mode
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update
RUN apt-get install --yes --quiet --no-install-recommends \
    ca-certificates apt-transport-https curl git vim locales \
    openssh-client python3 python-git

# Configure locales
RUN update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX \
    locale-gen en_US.UTF-8 \
    dpkg-reconfigure locales

# Install saltstack
RUN mkdir -p ${SALT_BUILD_DIR}
WORKDIR ${SALT_BUILD_DIR}

RUN curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com
RUN sh bootstrap-salt.sh ${SALT_BOOTSTRAP_OPTS} git ${SALT_GIT_RELEASE}

# Salt user
RUN useradd -d ${SALT_HOME} -ms /bin/bash -U -G root,sudo ${SALT_USER}
RUN chown -R ${SALT_USER}: ${SALT_ROOT_DIR}

EXPOSE 4505/tcp 4506/tcp
RUN mkdir -p ${SALT_DATA_DIR} ${SALT_BASE_DIR} ${SALT_KEYS_DIR} ${SALT_CONFS_DIR}
VOLUME [ "${SALT_BASE_DIR}" "${SALT_KEYS_DIR}" "${SALT_CONFS_DIR}" ]

COPY assets/runtime ${SALT_RUNTIME_DIR}
RUN chmod -R +x ${SALT_RUNTIME_DIR}

# Cleaning tasks
RUN apt-get clean --yes
RUN rm -rf /var/lib/apt/lists/*

# Entrypoint
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod +x /sbin/entrypoint.sh
WORKDIR ${SALT_HOME}

ENTRYPOINT [ "/sbin/entrypoint.sh" ]
CMD [ "app:start" ]
