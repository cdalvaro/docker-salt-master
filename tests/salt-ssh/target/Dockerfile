FROM public.ecr.aws/docker/library/ubuntu:26.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# salt-ssh needs python3 on the target to run the thin.
# The root password is set at runtime by the test script, so it is not baked into the image.
# hadolint ignore=DL3008
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
  openssh-server python3 \
  && apt-get clean --yes \
  && rm -rf /var/lib/apt/lists/* \
  && printf 'PermitRootLogin yes\nPasswordAuthentication yes\n' >/etc/ssh/sshd_config.d/salt-ssh-test.conf \
  && mkdir -p /run/sshd \
  && ssh-keygen -A

EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D", "-e" ]
