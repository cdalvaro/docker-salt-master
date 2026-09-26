FROM public.ecr.aws/docker/library/ubuntu:26.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# salt-ssh needs python3 on the target to run the thin; sudo is required for `sudo: True` roster entries.
# Passwords are set at runtime by the test script, so they are not baked into the image.
# hadolint ignore=DL3008
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
  openssh-server python3 sudo \
  && apt-get clean --yes \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --create-home --shell /bin/bash saltssh \
  && echo 'saltssh ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/saltssh \
  && chmod 440 /etc/sudoers.d/saltssh \
  && printf 'PermitRootLogin yes\nPasswordAuthentication yes\n' >/etc/ssh/sshd_config.d/salt-ssh-test.conf \
  && mkdir -p /run/sshd \
  && ssh-keygen -A

EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D", "-e" ]
