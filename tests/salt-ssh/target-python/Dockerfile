ARG PYTHON_VERSION=3.10
FROM public.ecr.aws/docker/library/python:${PYTHON_VERSION}-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Target with a different Python version than the salt-master one, to test ssh_ext_alternatives.
# The root password is set at runtime by the test script, so it is not baked into the image.
# hadolint ignore=DL3008
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
  openssh-server \
  && apt-get clean --yes \
  && rm -rf /var/lib/apt/lists/* \
  && printf 'PermitRootLogin yes\nPasswordAuthentication yes\n' >/etc/ssh/sshd_config.d/salt-ssh-test.conf \
  && mkdir -p /run/sshd \
  && ssh-keygen -A

EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D", "-e" ]
