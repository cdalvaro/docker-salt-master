# SaltStack Master v2018.3.3

Dockerfile to build a [SaltStack](https://www.saltstack.com) Master image for the Docker opensource container platform.

SaltStack Master is set up in the Docker image using the install from git source method as documented in the the [official bootstrap](https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html) documentation.

For other methods to install SaltStack please refer to the [Official SaltStack Installation Guide](https://docs.saltstack.com/en/latest/topics/installation/index.html).

## Table of Contents

- [Installation](#installation)
  - [Changelog](CHANGELOG.md)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Custom Recipes](#custom-recipes)
  - [Minion Keys](#minion-keys)
  - [Master Signed Keys](#master-signed-keys)
  - [Host Mapping](#host-mapping)
  - [Available Configuration Parameters](#available-configuration-parameters)
- [Usage](#usage)
- [Shell Access](#shell-access)
- [References](#references)

## Installation

Automated builds of the image are available on [Dockerhub](https://hub.docker.com/r/cdalvaro/saltstack-master/) and is the recommended method of installation.

```sh
docker pull cdalvaro/saltstack-master:2018.3.3
```

You can also pull the latest tag which is built from the repository HEAD

```sh
docker pull cdalvaro/saltstack-master:latest
```

Alternatively you can build the image locally.

```sh
docker build -t cdalvaro/saltstack-master github.com/cdalvaro/saltstack-master
```

## Quick Start

The quickest way to get started is using [docker-compose](https://docs.docker.com/compose/).

```sh
wget https://raw.githubusercontent.com/cdalvaro/saltstack-master/master/docker-compose.yml
```

Start SaltStack master using:

```sh
docker-compose up --detach
```

Alternatively, you can manually launch the `saltstack-master`  container:

```sh
docker run --name salt_master --detach \
    --publish 4505:4505/tcp --publish 4506:4506/tcp \
    --env 'SALT_LOG_LEVEL=info' \
    --read-only --volume $(pwd)/srv/:/home/salt/data/srv/ \
    cdalvaro/saltstack-master:2018.3.3
```

## Configuration

### Custom Recipes

This image does not require storing data out of the container.

But it is necessary to mount the `/srv/` volume ir order to provide your custom recipes.

### Minion Keys

Minion keys can be added automatically on startup to SaltStack master by mounting the volume `/home/salt/data/keys` and copying the minion keys inside `keys/minions/` directory:

```sh
mkdir -p keys/minions
rsync root@minion1:/etc/salt/pki/minion/minion.pub keys/minions/minion1

docker run --name salt_master -d \
    --publish 4505:4505/tcp --publish 4506:4506/tcp \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/srv/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    cdalvaro/saltstack-master:2018.3.3
```

### Master Signed Keys

It is possible to use signed master keys by establishing the environment variable `SALT_MASTER_SIGN_PUBKEY` to `True`.

```sh
docker run --name salt_stack --detach \
    --publish 4505:4505/tcp --publish 4506:4506/tcp \
    --env 'SALT_LOG_LEVEL=info' \
    --env 'SALT_MASTER_SIGN_PUBKEY=True'
    --volume $(pwd)/srv/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    cdalvaro/saltstack-master:2018.3.3
```

The container will create the `master_sign` key and its signature. More information about how to configure the minion service can be found [here](https://docs.saltstack.com/en/latest/topics/tutorials/multimaster_pki.html#prepping-the-minion-to-verify-received-public-keys).

Additionally, you can generate new keys by executing the following command:

```sh
docker run --name salt_stack -it --rm \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    cdalvaro/saltstack-master:2018.3.3 app:gen-signed-keys other_master_sign
```

The newly created keys will appear inside `keys/generated/other_master_sign` directory.

### Host Mapping

Per default the container is configured to run `salt-master` as user and group `salt` with `uid` and `gid` `1000`. From the host it appears as if the mounted data volumes are owned by the host's user/group `1000` and maybe leading to unfavorable effects.

Also the container processes seem to be executed as the host's user/group `1000`. The container can be configured to map the uid and gid of git to different ids on host by passing the environment variables `USERMAP_UID` and `USERMAP_GID`. The following command maps the ids to the current user and group on the host.

```sh
docker run --name salt_stack -it --rm \
    --env "USERMAP_UID=$(id -u)" --env "USERMAP_GID=$(id -g)" \
    --volume $(pwd)/srv/:/home/salt/data/srv/ \
    cdalvaro/saltstack-master:2018.3.3
```

### Available Configuration Parameters

Please refer the docker run command options for the `--env-file` flag where you can specify all required environment variables in a single file. This will save you from writing a potentially long docker run command. Alternatively you can use docker-compose.

Below is the list of available options that can be used to customize your SaltStack master installation.

| Parameter | Description |
|-----------|-------------|
| `SALT_LOG_LEVEL` | The level of messages to send to the console. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `warning` |
| `SALT_LEVEL_LOGFILE` | The level of messages to send to the log file. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `warning` |
| `SALT_MASTER_SIGN_PUBKEY` | Sign the master auth-replies with a cryptographic signature of the master's public key. Possible values: 'True' or 'False'. Default: `False` |
| `SALT_MASTER_USE_PUBKEY_SIGNATURE` | Instead of computing the signature for each auth-reply, use a pre-calculated signature. This option requires `SALT_MASTER_SIGN_PUBKEY` set to 'True'. Possible values: 'True' or 'False'. Default: `True` |
| `SALT_MASTER_SIGN_KEY_NAME` | The customizable name of the signing-key-pair without suffix. Default: `master_sign` |
| `SALT_MASTER_PUBKEY_SIGNATURE` | The name of the file in the master's pki-directory that holds the pre-calculated signature of the master's public-key. Default: `master_pubkey_signature` |
| `SALT_MASTER_ROOT_USER` | Forces `salt-master` to be runned as `root` instead of `salt`. Default: `False` |
| `USERMAP_UID` | Sets the uid for user `salt` to the specified uid. Default: `1000`. |
| `USERMAP_GID` | Sets the gid for user `salt` to the specified gid. Default: `1000`. |

Any parameter not listed in the above table and available in the following [link](https://docs.saltstack.com/en/latest/ref/configuration/examples.html#configuration-examples-master), can be set by creating the directory `config` and adding into it a `.conf` file with the desired parameters:

```sh
mkdir config
cat > config/ports.conf << EOF
# The tcp port used by the publisher:
publish_port: 3505
# The port used by the communication interface.
ret_port: 3506
EOF

docker run --name salt_master -d \
    --publish 3505:3505/tcp --publish 3506:3506/tcp \
    --env 'SALT_LOG_LEVEL=info' \
    --read-only --volume $(pwd)/srv/:/home/salt/data/srv/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    cdalvaro/saltstack-master:2018.3.3
```

## Usage

To test which salt minions are listening the following command can be executed from the master service:

```sh
docker-compose exec master salt '*' test.ping
```

Then, you can apply salt states to your minions:

```sh
docker-compose exec master salt '*' state.apply
```

## Shell Access

For debugging and maintenance purposes you may want access the container shell. If you are using docker version 1.3.0 or higher you can access a running container shell using docker exec command.

```sh
docker exec -it salt_master bash
```

## References

- https://docs.saltstack.com/en/latest/topics/installation/index.html
- https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html
- https://github.com/saltstack/salt/releases
