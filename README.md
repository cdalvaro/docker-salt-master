[![Salt Project][saltproject_badge]][saltproject_release_notes]
[![Ubuntu Image][ubuntu_badge]][ubuntu_hub_docker]
[![Publish Workflow][github_publish_badge]][github_publish_workflow]

[![Docker Image Size][docker_size_badge]][docker_hub_tags]
[![Architecture AMD64][arch_amd64_badge]][arch_link]
[![Architecture ARM64][arch_arm64_badge]][arch_link]
[![Architecture ARM/v7][arch_arm_badge]][arch_link]

# Dockerized Salt Master v3005 _Phosphorus_

Dockerfile to build a [Salt Project](https://saltproject.io) Master image for the Docker opensource container platform.

`salt-master` is installed inside the Docker image using git source as documented in
the [official bootstrap](https://docs.saltproject.io/en/latest/topics/tutorials/salt_bootstrap.html) documentation.

For other methods to install `salt-master` please refer to
the [Official Salt Project Installation Guide](https://docs.saltproject.io/en/latest/topics/installation/index.html).

## 🐳 Installation

Automated builds of the image are available on
[GitHub Container Registry](https://github.com/cdalvaro/docker-salt-master/pkgs/container/docker-salt-master) and is
the recommended method of installation.

```sh
docker pull ghcr.io/cdalvaro/docker-salt-master:3005_1
```

You can also pull the latest tag which is built from the repository `HEAD`

```sh
docker pull ghcr.io/cdalvaro/docker-salt-master:latest
```

These images are also available
from [Docker Registry](https://hub.docker.com/r/cdalvaro/docker-salt-master):

```sh
docker pull cdalvaro/docker-salt-master:latest
```

and from [Quay.io](https://quay.io/repository/cdalvaro/docker-salt-master):

```sh
docker pull quay.io/cdalvaro/docker-salt-master:latest
```

Alternatively, you can build the image locally using `make` command:

```sh
make release
```

## 🚀 Quick Start

The quickest way to get started is using [docker-compose](https://docs.docker.com/compose/).

```sh
wget https://raw.githubusercontent.com/cdalvaro/docker-salt-master/master/docker-compose.yml
```

Start the `docker-salt-master` container with the `docker-compose.yml` file by executing:

```sh
docker-compose up --detach
```

Alternatively, you can manually launch the `docker-salt-master` container:

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

## ⚙️ Configuration

### Custom Configuration

This image uses its own `master.yml` file to configure `salt-master` to run properly inside the container. However, you
can still tune other configuration parameters to fit your needs by adding your configuration files into a `config/`
directory and mounting it into `/home/salt/data/config/`.

For example, you can customize the [Reactor System](https://docs.saltproject.io/en/latest/topics/reactor/index.html) by
adding a `reactor.conf` file to `config/`:

```sls
# config/reactor.conf
reactor:                        # Master config section "reactor"
  - 'salt/minion/*/start':      # Match tag "salt/minion/*/start"
    - /srv/reactor/start.sls    # Things to do when a minion starts
```

Then, you have to add the `start.sls` file into your `roots/reactor/` directory:

```sls
# roots/reactor/start.sls
highstate_run:
  local.state.apply:
    - tgt: {{ data['id'] }}
```

Finally, run your `docker-salt-master` instance mounting the required directories:

```sh
docker run --name salt_master -d \
    --publish 4505:4505 --publish 4506:4506 \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

This image provides support for automatically restart `salt-master` when configuration files change.
This support is disabled by default, but it can be enabled by setting the
`SALT_RESTART_MASTER_ON_CONFIG_CHANGE` environment variable to `True`.

### Custom States

In order to provide salt with your custom states you must mount the volume `/home/salt/data/srv/` with your `roots`
directory inside it.

### Minion Keys

Minion keys can be added automatically on startup to `docker-salt-master` by mounting the volume `/home/salt/data/keys`
and copying the minion keys inside `keys/minions/` directory.

It is also important to know that, in order to keep your keys after removing the container, the keys directory must be
mounted.

```sh
mkdir -p keys/minions
rsync root@minion1:/etc/salt/pki/minion/minion.pub keys/minions/minion1

docker run --name salt_master -d \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

Also, you can set your `docker-salt-master` instance to auto accept minions that match certain grains. To do that, add
the `autosign_grains.conf` to your `config` directory:

```sls
# config/autosign_grains.conf
autosign_grains_dir: /home/salt/data/srv/autosign_grains
```

Then, inside `roots/autosign_grains` you can place a file named like the grain you want to match and fill it with the
content to match. For example, if you want to auto accept minions that belong to specific domains, you have to add
the `domain` file with the domains you want to allow:

```sls
# roots/autosign_grains/domain
cdalvaro.io
cdalvaro.com
```

It is possible that you have to configure the minion to send the specific grains to the master in the minion config
file:

```sls
autosign_grains:
  - domain
```

More info at:
[Salt Project - Auto accept Minions From Grains](https://docs.saltproject.io/en/latest/topics/tutorials/autoaccept_grains.html)

### Master Signed Keys

It is possible to use signed master keys by establishing the environment variable `SALT_MASTER_SIGN_PUBKEY` to `True`.

```sh
docker run --name salt_stack --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --env 'SALT_MASTER_SIGN_PUBKEY=True' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

The container will create the `master_sign` key and its signature. More information about how to configure the minion
service can be
found [here](https://docs.saltproject.io/en/latest/topics/tutorials/multimaster_pki.html#prepping-the-minion-to-verify-received-public-keys)
.

Additionally, you can generate new keys by executing the following command:

```sh
docker run --name salt_stack -it --rm \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest \
    app:gen-signed-keys new_master_sign
```

The newly created keys will appear inside `keys/generated/new_master_sign` directory.

#### Working with secrets

Master keys can be provided via Docker secrets. To do that, you have to set the following environment variable:

- `SALT_MASTER_KEY_FILE`: The path to the master-key-pair {pem,pub} files without suffixes.

Additionally, you can provide the master-sign key pair as well:

- `SALT_MASTER_SIGN_KEY_FILE`: The path to the master-sign-key-pair {pem,pub} files without suffixes.
- `SALT_MASTER_PUBKEY_SIGNATURE_FILE`: The path of the salt-master public key file with the pre-calculated signature.

Here you have a complete docker-compose example

```yml
version: '3.9'

services:
  salt-master:
    image: ghcr.io/cdalvaro/docker-salt-master:latest
    ports:
      - "4505:4505"
      - "4506:4506"
    volumes:
      - ./config:/home/salt/data/config
    secrets:
      - source: salt-master-key
        target: master.pem
        uid: 1000     # Or $PUID if env variable established
        gid: 1000     # Or $GUID if env variable established
        mode: 0400
      - source: salt-master-pub
        target: master.pub
        uid: 1000     # Or $PUID if env variable established
        gid: 1000     # Or $GUID if env variable established
        mode: 0644
      - source: salt-master-sign-priv-key
        target: master_sign.pem
        uid: 1000     # Or $PUID if env variable established
        gid: 1000     # Or $GUID if env variable established
        mode: 0400
      - source: salt-master-sign-pub-key
        target: master_sign.pub
        uid: 1000     # Or $PUID if env variable established
        gid: 1000     # Or $GUID if env variable established
        mode: 0644
      - source: salt-master-signature
        target: master_pubkey_signature
        uid: 1000     # Or $PUID if env variable established
        gid: 1000     # Or $GUID if env variable established
        mode: 0644
    environment:
      SALT_MASTER_SIGN_PUBKEY: True
      SALT_MASTER_KEY_FILE: /run/secrets/master
      SALT_MASTER_SIGN_KEY_FILE: /run/secrets/master_sign
      SALT_MASTER_PUBKEY_SIGNATURE_FILE: /run/secrets/master_pubkey_signature

secrets:
  salt-master-pem-key:
    file: keys/master.pem
  salt-master-pub-key:
    file: keys/master.pub
  salt-master-sign-priv-key:
    file: keys/master_sign.pem
  salt-master-sign-pub-key:
    file: keys/master_sign.pub
  salt-master-signature:
    file: keys/master_pubkey_signature
```

### Salt API

You can enable `salt-api` service by setting env variable `SALT_API_SERVICE_ENABLED` to `True`.

A self-signed SSL certificate will be automatically generated and the following configuration will be added to the
master configuration file:

```yml
rest_cherrypy:
  port: 8000
  ssl_crt: /etc/pki/tls/certs/docker-salt-master.crt
  ssl_key: /etc/pki/tls/certs/docker-salt-master.key
```

The container exposes port `8000` by default, although you can map this port to whatever port you like in
your `docker run` command:

```sh
docker run --name salt_stack --detach \
    --publish 4505:4505 --publish 4506:4506 --publish 8000:8000 \
    --env 'SALT_API_SERVICE_ENABLED=True' \
    --env 'SALT_API_USER_PASS=4wesome-Pass0rd' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

If you choose using the [docker-compose.yml](docker-compose.yml) to manage your salt-master instance, uncomment salt-api
settings to enable and configure the service.

By default, user `salt_api` is created, and you can set its password by setting the environment
variable `SALT_API_USER_PASS`.

You can also change the salt-api _username_ by setting `SALT_API_USER`. It is possible to disable this user by
explicitly setting this variable to an empty string: `SALT_API_USER=''` if you are going to use an `LDAP` server.

As a security measure, if `SALT_API_SERVICE_ENABLED` is set to `True` and you don't disable `SALT_API_USER`, you'll be
required to set `SALT_API_USER_PASS`. Otherwise, initialization will fail and your Docker image won't work.

`SALT_API_USER_PASS_FILE` env variable is available to provide the password via a file. This is useful when using docker
secretes. More info about how to configure secrets can be found in the subsection
[_Working with secrets_](#working-with-secrets).

With all that set, you'll be able to provide your _salt-api_ custom configuration by creating the `salt-api.conf` file
inside your `conf` directory:

```yml
external_auth:
  pam:
    salt_api:
      - .*
      - "@runner"
      - "@wheel"
      - "@jobs"
```

More information is available in the following
link: [External Authentication System (eAuth)](https://docs.saltproject.io/en/latest/topics/eauth/index.html#acl-eauth).

Now you have your docker-salt-master docker image ready to accept external authentications and to connect external tools
such as [`saltstack/pepper`](https://github.com/saltstack/pepper).

#### Salt Pepper

The pepper CLI script allows users to execute Salt commands from computers that are external to computers running the
salt-master or salt-minion daemons as though they were running Salt locally

##### Installation:

```sh
pip3 install salt-pepper
```

##### Configuration

Then configure pepper by filling your `~/.pepperrc` file with your salt-api credentials:

```conf
[main]
SALTAPI_URL=https://your.salt-master.hostname:8000/
SALTAPI_USER=salt_api
SALTAPI_PASS=4wesome-Pass0rd
SALTAPI_EAUTH=pam
```

##### Usage

Begin executing salt states with `pepper`:

```sh
pepper '*' test.ping
```

### Host Mapping

Per default the container is configured to run `salt-master` as user and group `salt` with `uid` and `gid` `1000`. From
the host it appears as if the mounted data volumes are owned by the host's user/group `1000` and maybe leading to
unfavorable effects.

Also, the container processes seem to be executed as the host's user/group `1000`. The container can be configured to
map
the uid and gid of git to different ids on host by passing the environment variables `PUID` and `PGID`. The following
command maps the ids to the current user and group on the host.

```sh
docker run --name salt_stack -it --rm \
    --publish 4505:4505 --publish 4506:4506 \
    --env "PUID=$(id -u)" --env "PGID=$(id -g)" \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

### Git Fileserver

This image uses [GitPython](https://github.com/gitpython-developers/GitPython) and [PyGit2](https://www.pygit2.org) as
gitfs backends to allow Salt to serve files from git repositories.

It can be enabled by adding `gitfs` to
the [`fileserver_backend`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std:conf_master-fileserver_backend)
list (see [Available Configuration Parameters](#available-configuration-parameters)), and configuring one or more
repositories
in [`gitfs_remotes`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std:conf_master-gitfs_remotes).

#### GitPython

The default name for the ssh key is `gitfs_ssh` but it can be changed with the env
variables `SALT_GITFS_SSH_PRIVATE_KEY` and `SALT_GITFS_SSH_PUBLIC_KEY`.

This keys must be placed inside `/home/salt/data/keys` directory.

#### PyGit2

You can create an ssh key for pygit2 with the following command:

```sh
ssh-keygen -t ed25519 -C  -f gitfs_ssh -C 'gitfs_ed25519@example.com'
```

Place it wherever you want inside the container and specify its path with the configuration parameters: `gitfs_pubkey`
and `gitfs_privkey` in your `.conf` file.

For example:

```yml
gitfs_provider: pygit2
gitfs_privkey: /home/salt/data/keys/gitfs/gitfs_ssh
gitfs_pubkey: /home/salt/data/keys/gitfs/gitfs_ssh.pub
```

**Important Note**

This image has been tested with an _ed25519_ ssh key.

Alternately, you may create a new RSA key with SHA2 hashing like so:

```sh
ssh-keygen -t rsa-sha2-512 -b 4096 -f gitfs_ssh -C 'gitfs_rsa4096@example.com'
```

### 3rd Party Formulas

You can add third party formulas to your configuration simply by adding them to your `gitfs_remotes`:

```yml
# fileserver.conf
fileserver_backend:
  - roots
  - gitfs

# gitfs.conf
gitfs_provider: pygit2
gitfs_remotes:
  - https://github.com/saltstack-formulas/apache-formula
  - https://github.com/aokiji/salt-formula-helm.git
```

This is
the [Salt recommended](https://docs.saltproject.io/en/latest/topics/development/conventions/formulas.html#adding-a-formula-as-a-gitfs-remote)
way of doing it, and you can go to the [Git Fileserver](#git-fileserver) section on this document if you need help
configuring this service.

You can find a great set of formulas on the following GitHub repositories:

- [Official Salt Formulas](https://github.com/saltstack-formulas)
- [Unofficial Salt Formulas](https://github.com/salt-formulas)

Although, as mention
in [Salt Project documentation](https://docs.saltproject.io/en/latest/topics/development/conventions/formulas.html#adding-a-formula-as-a-gitfs-remote)
, you are encouraged to fork desired formulas to avoid unexpected changes to your infrastructure.

However, sometimes you may need to load some formulas that are not available on a git repository, and you want to have
them separated from your main `srv` directory.

For that case, you can mount a volume containing all your third party formulas separated in subdirectories
into `/home/salt/data/3pfs/`, and they will be automatically added to the master configuration when your container
starts.

```sh
# 3pfs directory content
3pfs
├── custom-formula
├── golang-formula
└── vim-formula
```

```sh
docker run --name salt_stack -it --rm \
    --publish 4505:4505 --publish 4506:4506 \
    --env "PUID=$(id -u)" --env "PGID=$(id -g)" \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/3pfs/:/home/salt/data/3pfs/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

If you need to add more third party formulas, you can restart the container, or you can type the following command:

```sh
docker exec -it salt_stack /sbin/entrypoint.sh app:reload-3rd-formulas
```

`file_roots` base configuration file will be updated with current existing formulas and `salt-master` service will be
restarted to reload the new configuration.

### Logs

Salt logs are accessible by mounting the volume `/home/salt/data/logs/`.

Inside that directory you could find `supervisor/` logs and `salt/` logs:

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

Check [Available Configuration Parameters](#available-configuration-parameters) section for configuring logrotate.

### Healthcheck

This image includes a [health check](https://docs.docker.com/engine/reference/builder/#healthcheck)
script: `/usr/local/sbin/healthcheck` (although it is disabled by default). It is useful to check if the `salt-master`
service is alive and responding.

If you are running this image under k8s, you can define a _liveness command_ as
explained [here](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-a-liveness-command)
.

If you use `docker-compose` as your container orchestrator, you can add the following entries to your compose file:

```yml
version: "3.4"

services:
  master:
    container_name: salt_master
    image: ghcr.io/cdalvaro/docker-salt-master:latest
    healthcheck:
      test: [ "CMD", "/usr/local/sbin/healthcheck" ]
      start_period: 30s
```

(More info available at [compose file](https://docs.docker.com/compose/compose-file/#healthcheck) official
documentation)

Or, if you launch your container [with docker](https://docs.docker.com/engine/reference/run/#healthcheck):

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --health-cmd='/usr/local/sbin/healthcheck' \
    --health-start-period=30s \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

Then you can manually check this info by running the following command:

```sh
docker inspect --format "{{json .State.Health }}" salt_master | jq
```

Then, the output will be something similar to this:

```json
{
  "Status": "healthy",
  "FailingStreak": 0,
  "Log": [
    {
      "Start": "2020-05-23T16:47:55.1046568Z",
      "End": "2020-05-23T16:48:02.3381442Z",
      "ExitCode": 0,
      "Output": "local:\n    True\n"
    }
  ]
}
```

#### Autoheal

If you run your _docker-salt-master_ instance with healthcheck enabled, you can
use [willfarrell/autoheal](https://github.com/willfarrell/docker-autoheal) image to restart your service when
healthcheck fails:

```sh
docker run -d \
  --name autoheal \
  --restart=always \
  -e AUTOHEAL_CONTAINER_LABEL=all \
  -v /var/run/docker.sock:/var/run/docker.sock \
  willfarrell/autoheal
```

This container will watch your containers and restart your failing instances.

### Available Configuration Parameters

Please refer the docker run command options for the `--env-file` flag where you can specify all required environment
variables in a single file. This will save you from writing a potentially long docker run command. Alternatively you can
use docker-compose.

Below you can find a list with the available options that can be used to customize your `docker-salt-master`
installation.

| Parameter                                                                                                                             | Description                                                                                                                                                                                                                                               |
|:--------------------------------------------------------------------------------------------------------------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `DEBUG`                                                                                                                               | Set this to `True` to enable entrypoint debugging.                                                                                                                                                                                                        |
| `TIMEZONE` / `TZ`                                                                                                                     | Set the container timezone. Defaults to `UTC`. Values are expected to be in Canonical format. Example: `Europe/Madrid`. See the list of [acceptable values](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).                                |
| `PUID`                                                                                                                                | Sets the uid for user `salt` to the specified uid. Default: `1000`.                                                                                                                                                                                       |
| `PGID`                                                                                                                                | Sets the gid for user `salt` to the specified gid. Default: `1000`.                                                                                                                                                                                       |
| `SALT_RESTART_MASTER_ON_CONFIG_CHANGE`                                                                                                | Set this to `True` to restart `salt-master` service when configuration files change. Default: `False`.                                                                                                                                                    |
| [`SALT_LOG_LEVEL`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#log-level)                                     | The level of messages to send to the console. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `warning`.                                                                                                              |
| `SALT_LOG_ROTATE_FREQUENCY`                                                                                                           | Logrotate frequency for salt logs. Available options are 'daily', 'weekly', 'monthly', and 'yearly'. Default: `weekly`.                                                                                                                                   |
| `SALT_LOG_ROTATE_RETENTION`                                                                                                           | Keep x files before deleting old log files. Defaults: `52`.                                                                                                                                                                                               |
| [`SALT_LEVEL_LOGFILE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#log-level-logfile)                         | The level of messages to send to the log file. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `warning`.                                                                                                             |
| `SALT_MASTER_KEY_FILE`                                                                                                                | The path to the master-key-pair {pem,pub} files without suffixes. Keys will be copied into the pki directory. Useful to load the password from secrets. _Unset_ by default.                                                                               |
| [`SALT_API_SERVICE_ENABLED`](https://docs.saltproject.io/en/latest/ref/cli/salt-api.html)                                             | Enable `salt-api` service. Default: `False`.                                                                                                                                                                                                              |
| `SALT_API_USER`                                                                                                                       | Set username for `salt-api` service. Default: `salt_api`.                                                                                                                                                                                                 |
| `SALT_API_USER_PASS_FILE`                                                                                                             | `SALT_API_USER` password file path. Use this variable to set the path of a file containing the password for the `SALT_API_USER`. Useful to load the password from secrets. Has priority over `SALT_API_USER_PASS`. _Unset_ by default.                    |
| `SALT_API_USER_PASS`                                                                                                                  | `SALT_API_USER` password. Required if `SALT_API_SERVICE_ENBALED` is `True`, `SALT_API_USER` is not empty and `SALT_API_USER_PASS_FILE` is unset. _Unset_ by default.                                                                                      |
| `SALT_API_CERT_CN`                                                                                                                    | Common name in the request. Default: `localhost`.                                                                                                                                                                                                         |
| [`SALT_MASTER_SIGN_PUBKEY`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-sign-pubkey)                   | Sign the master auth-replies with a cryptographic signature of the master's public key. Possible values: 'True' or 'False'. Default: `False`.                                                                                                             |
| [`SALT_MASTER_USE_PUBKEY_SIGNATURE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-use-pubkey-signature) | Instead of computing the signature for each auth-reply, use a pre-calculated signature. This option requires `SALT_MASTER_SIGN_PUBKEY` set to 'True'. Possible values: 'True' or 'False'. Default: `True`.                                                |
| [`SALT_MASTER_SIGN_KEY_NAME`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-sign-key-name)               | The customizable name of the signing-key-pair without suffix. Default: `master_sign`.                                                                                                                                                                     |
| `SALT_MASTER_SIGN_KEY_FILE`                                                                                                           | The path to the signing-key-pair {pem,pub} without suffixes. The pair will be copied into the pki directory if they don't exists previously. Useful to load the password from secrets. _Unset_ by default.                                                |
| [`SALT_MASTER_PUBKEY_SIGNATURE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-pubkey-signature)         | The name of the file in the master's pki-directory that holds the pre-calculated signature of the master's public-key. Default: `master_pubkey_signature`.                                                                                                |
| `SALT_MASTER_PUBKEY_SIGNATURE_FILE`                                                                                                   | The path of the salt-master public key file with the pre-calculated signature. It will be copied inside the pki directory if a file with name `SALT_MASTER_PUBKEY_SIGNATURE` doesn't exist. Useful to load the password from secrets. _Unset_ by default. |
| `SALT_MASTER_ROOT_USER`                                                                                                               | Forces `salt-master` to be run as `root` instead of `salt`. Default: `False`.                                                                                                                                                                             |
| `SALT_GITFS_SSH_PRIVATE_KEY`                                                                                                          | The name of the ssh private key for gitfs. Default: `gitfs_ssh`.                                                                                                                                                                                          |
| `SALT_GITFS_SSH_PUBLIC_KEY`                                                                                                           | The name of the ssh public key for gitfs. Default: `gitfs_ssh`.pub`.                                                                                                                                                                                      |
| [`SALT_REACTOR_WORKER_THREADS`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#reactor-worker-threads)           | The number of workers for the runner/wheel in the reactor. Default: `10`.                                                                                                                                                                                 |
| [`SALT_WORKER_THREADS`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#worker-threads)                           | The number of threads to start for receiving commands and replies from minions. Default: `5`.                                                                                                                                                             |
| [`SALT_BASE_DIR`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#file-roots)                                     | The `base` path in `file_roots` to look for `salt` and `pillar` directories. Default: `/home/salt/data/srv`.                                                                                                                                              |
| [`SALT_CONFS_DIR`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std-conf_master-default_include)               | The master will automatically include all config files from this directory. Default: `/home/salt/data/config`.                                                                                                                                            |

Any parameter not listed in the above table and available in the
following [link](https://docs.saltproject.io/en/latest/ref/configuration/examples.html#configuration-examples-master),
can be set by creating the directory `config` and adding into it a `.conf` file with the desired parameters:

```sh
mkdir config
cat > config/ports.conf << EOF
# The tcp port used by the publisher:
publish_port: 3505
# The port used by the communication interface.
ret_port: 3506
EOF

docker run --name salt_master -d \
    --publish 3505:3505 --publish 3506:3506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

## 🧑‍🚀 Usage

To test which salt minions are listening the following command can be executed directly from the host machine:

```sh
docker exec -it salt_master salt '*' test.ping
```

Then, you can apply salt states to your minions:

```sh
docker exec -it salt_master salt '*' state.apply [state]
```

## 🧰 Shell Access

For debugging and maintenance purposes you may want to access the container's shell.
If you are using docker version 1.3.0 or higher you can access a running container shell using docker exec command.

```sh
docker exec -it salt_master bash
```

## 💀 Restart Services

You can restart containers services by running the following command:

```sh
docker exec -it salt_master entrypoint.sh app:restart [salt-service]
```

Where `salt-service` is one of: `salt-master` os `salt-api` (if `SALT_API_SERVICE_ENABLED` is set to `True`)

## 👏 Credits

Many thanks to:

* [The SaltProject](https://saltproject.io) team for the excellent [salt](https://github.com/saltstack/salt) project
* [JetBrains](https://www.jetbrains.com) for their free [OpenSource](https://jb.gg/OpenSourceSupport) license
* [The Contributors](https://github.com/cdalvaro/docker-salt-master/graphs/contributors) for all the smart code and
  suggestions merged in the project
* [The Stargazers](https://github.com/cdalvaro/docker-salt-master/stargazers) for showing their support

<div style="display: flex; align-items: center; justify-content: space-around;">
  <img src="social/SaltProject_verticallogo_teal.png" alt="SaltProject" height="128px">
  <img src="social/jb_beam.svg" alt="JetBrains Beam" height="128px">
</div>

## 📖 References

[![StackOverflow Community][stackoverflow_badge]][stackoverflow_community]
[![Slack Community][slack_badge]][slack_community]
[![Reddit channel][reddit_badge]][subreddit]

- https://docs.saltproject.io/en/getstarted/
- https://docs.saltproject.io/en/latest/contents.html

[saltproject_badge]: https://img.shields.io/badge/Salt-v3005-lightgrey.svg?logo=Saltstack

[saltproject_release_notes]: https://docs.saltproject.io/en/latest/topics/releases/3005.html "Salt Project Release Notes"

[ubuntu_badge]: https://img.shields.io/badge/ubuntu-jammy--20220801-E95420.svg?logo=Ubuntu

[ubuntu_hub_docker]: https://hub.docker.com/_/ubuntu/ "Ubuntu Image"

[github_publish_badge]: https://img.shields.io/github/workflow/status/cdalvaro/docker-salt-master/Publish%20Docker%20image?label=build&logo=GitHub&logoColor=%23181717

[github_publish_workflow]: https://github.com/cdalvaro/docker-salt-master/actions?query=workflow%3A%22Publish+Docker+image%22

[docker_size_badge]: https://img.shields.io/docker/image-size/cdalvaro/docker-salt-master/latest?logo=docker&color=2496ED

[docker_hub_tags]: https://hub.docker.com/repository/docker/cdalvaro/docker-salt-master/tags

[reddit_badge]: https://img.shields.io/badge/reddit-saltstack-orange?logo=reddit&logoColor=FF4500&color=FF4500

[subreddit]: https://www.reddit.com/r/saltstack/

[stackoverflow_badge]: https://img.shields.io/badge/stackoverflow-community-orange?logo=stackoverflow&color=FE7A16

[stackoverflow_community]: https://stackoverflow.com/tags/salt-stack

[slack_badge]: https://img.shields.io/badge/slack-@saltstackcommunity-blue.svg?logo=slack&logoColor=4A154B&color=4A154B

[slack_community]: https://saltstackcommunity.herokuapp.com

[arch_amd64_badge]: https://img.shields.io/badge/arch-amd64-inactive.svg

[arch_arm_badge]: https://img.shields.io/badge/arch-arm/v7-inactive.svg

[arch_arm64_badge]: https://img.shields.io/badge/arch-arm64-inactive.svg

[arch_link]: https://github.com/users/cdalvaro/packages/container/package/docker-salt-master

## 📃 License

This project is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
