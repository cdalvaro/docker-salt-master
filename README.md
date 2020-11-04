[![SaltStack][saltstack_badge]][saltstack_release_notes]
[![Ubuntu Image][ubuntu_badge]][ubuntu_hub_docker]
[![StackOverflow Community][stackoverflow_badge]][stackoverflow_community]
[![Slack Community][slack_badge]][slack_community]
[![Publish Workflow][github_publish_badge]][github_publish_workflow]
[![Docker Image Size][docker_size_badge]][docker_hub_tags]
[![CodeFactor][codefactor_badge]][codefactor_score]

# Dockerized SaltStack Master Magnesium v3002.1

Dockerfile to build a [SaltStack](https://www.saltstack.com) Master image for the Docker opensource container platform.

SaltStack Master is set up in the Docker image using the install from git source method as documented in the the [official bootstrap](https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html) documentation.

For other methods to install SaltStack please refer to the [Official SaltStack Installation Guide](https://docs.saltstack.com/en/latest/topics/installation/index.html).

## Table of Contents

- [Installation](#installation)
  - [Changelog](CHANGELOG.md)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Custom States](#custom-states)
  - [Minion Keys](#minion-keys)
  - [Master Signed Keys](#master-signed-keys)
  - [Salt API](#salt-api)
    - [Salt Pepper](#salt-pepper)
  - [Host Mapping](#host-mapping)
  - [Git Fileserver](#git-fileserver)
    - [GitPython](#gitpython)
    - [PyGit2](#pygit2)
  - [3rd Party Formulas](#3rd-party-formulas)
  - [Logs](#logs)
  - [Healthcheck](#healthcheck)
    - [Autoheal](#autoheal)
  - [Available Configuration Parameters](#available-configuration-parameters)
- [Usage](#usage)
- [Shell Access](#shell-access)
- [Restart Services](#restart-services)
- [References](#references)

## Installation

Automated builds of the image are available on [Dockerhub](https://hub.docker.com/r/cdalvaro/docker-salt-master/) and is the recommended method of installation.

```sh
docker pull cdalvaro/docker-salt-master:3002.1
```

You can also pull the latest tag which is built from the repository `HEAD`

```sh
docker pull cdalvaro/docker-salt-master:latest
```

These images are also available from [Quay.io](https://quay.io/repository/cdalvaro/docker-salt-master):

```sh
docker pull quay.io/cdalvaro/docker-salt-master:latest
```

and from [GitHub Container Registry](https://github.com/users/cdalvaro/packages/container/package/docker-salt-master):

```sh
docker pull ghcr.io/cdalvaro/docker-salt-master:latest
```

Alternatively, you can build the image locally.

```sh
docker build -t cdalvaro/docker-salt-master github.com/cdalvaro/docker-salt-master
```

## Quick Start

The quickest way to get started is using [docker-compose](https://docs.docker.com/compose/).

```sh
wget https://raw.githubusercontent.com/cdalvaro/docker-salt-master/master/docker-compose.yml
```

Start SaltStack master using:

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
    cdalvaro/docker-salt-master:latest
```

## Configuration

### Custom States

In order to provide salt with your custom states you must mount the volume `/home/salt/data/srv/`
with your `roots` directory.

### Minion Keys

Minion keys can be added automatically on startup to SaltStack master by mounting the volume
`/home/salt/data/keys` and copying the minion keys inside `keys/minions/` directory.

It is also important to know that, in order to keep your keys after removing the container,
the keys directory must be mounted.

```sh
mkdir -p keys/minions
rsync root@minion1:/etc/salt/pki/minion/minion.pub keys/minions/minion1

docker run --name salt_master -d \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    cdalvaro/docker-salt-master:latest
```

### Master Signed Keys

It is possible to use signed master keys by establishing the environment variable
`SALT_MASTER_SIGN_PUBKEY` to `True`.

```sh
docker run --name salt_stack --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --env 'SALT_MASTER_SIGN_PUBKEY=True' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    cdalvaro/docker-salt-master:latest
```

The container will create the `master_sign` key and its signature.
More information about how to configure the minion service can be found
[here](https://docs.saltstack.com/en/latest/topics/tutorials/multimaster_pki.html#prepping-the-minion-to-verify-received-public-keys).

Additionally, you can generate new keys by executing the following command:

```sh
docker run --name salt_stack -it --rm \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    cdalvaro/docker-salt-master:latest \
    app:gen-signed-keys new_master_sign
```

The newly created keys will appear inside `keys/generated/new_master_sign` directory.

### Salt API

You can enable `salt-api` service by setting env variable `SALT_API_SERVICE_ENABLED` to `true`.

A self-signed SSL certificate will be automatically generated and the following configuration
will be added to the master configuration file:

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
    --env 'SALT_API_SERVICE_ENABLED=true' \
    --env 'SALT_API_USER_PASS=4wesome-Pass0rd' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    cdalvaro/docker-salt-master:latest
```

If you choose using the [docker-compose.yml](docker-compose.yml) to manage your salt-master instance,
uncomment salt-api settings to enable and configure the service.

By default, user `salt_api` is created and you can set its password by setting the environment variable
`SALT_API_USER_PASS`.

You can also change the salt-api _username_ by setting `SALT_API_USER`.
It is possible to disable this user by explicitly setting this variable to an empty string: `SALT_API_USER=''` if you are going to use an `LDAP` server.

As a security measure, if `SALT_API_SERVICE_ENABLED` is set to `true` and you don't disable `SALT_API_USER`,
you'll be required to set `SALT_API_USER_PASS`. Otherwise initialization will fail and your Docker image won't work.

With all that set, you'll be able to provide your _salt-api_ custom configuration by creating the `salt-api.conf`
file inside your `conf` directory:

```yml
external_auth:
  pam:
    salt_api:
      - .*
      - "@runner"
      - "@wheel"
      - "@jobs"
```

More information is available in the following link: [External Authentication System (eAuth)](https://docs.saltstack.com/en/latest/topics/eauth/index.html#acl-eauth).

Now you have your docker-salt-master docker image ready to accept external authentications and to connect external tools such as [`saltstack/pepper`](https://github.com/saltstack/pepper).

#### Salt Pepper

The pepper CLI script allows users to execute Salt commands from computers that are external to computers running the salt-master or salt-minion daemons as though they were running Salt locally

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

Beging executing salt states with `pepper`:

```sh
pepper '*' test.ping
```

### Host Mapping

Per default the container is configured to run `salt-master` as user and group `salt` with `uid` and `gid` `1000`. From the host it appears as if the mounted data volumes are owned by the host's user/group `1000` and maybe leading to unfavorable effects.

Also the container processes seem to be executed as the host's user/group `1000`. The container can be configured to map the uid and gid of git to different ids on host by passing the environment variables `USERMAP_UID` and `USERMAP_GID`. The following command maps the ids to the current user and group on the host.

```sh
docker run --name salt_stack -it --rm \
    --publish 4505:4505 --publish 4506:4506 \
    --env "USERMAP_UID=$(id -u)" --env "USERMAP_GID=$(id -g)" \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    cdalvaro/docker-salt-master:latest
```

### Git Fileserver

This image uses [GitPython](https://github.com/gitpython-developers/GitPython) and [PyGit2](https://www.pygit2.org) as gitfs backends to allow Salt to serve files from git repositories.

It can be enabled by adding `gitfs` to the [`fileserver_backend`](https://docs.saltstack.com/en/latest/ref/configuration/master.html#std:conf_master-fileserver_backend) list (see [Available Configuration Parameters](#available-configuration-parameters)), and configuring one or more repositories in [`gitfs_remotes`](https://docs.saltstack.com/en/latest/ref/configuration/master.html#std:conf_master-gitfs_remotes).

#### GitPython

The default name for the ssh key is `gitfs_ssh` but it can be changed with the env variables `SALT_GITFS_SSH_PRIVATE_KEY` and `SALT_GITFS_SSH_PUBLIC_KEY`.

This keys must be placed inside `/home/salt/data/keys` directory.

#### PyGit2

You can create an ssh key for pygit2 with the following command:

```sh
ssh-keygen -f gitfs_pygit2 -C 'gitfs@example.com'
```

Place it wherever you want inside the container and specify its path with the configuration parameters: `gitfs_pubkey` and `gitfs_privkey` in your `.conf` file.

For example:

```yml
gitfs_provider: pygit2
gitfs_privkey: /home/salt/data/keys/gitfs/gitfs_ssh
gitfs_pubkey: /home/salt/data/keys/gitfs/gitfs_ssh.pub
```

**Important Note**

If you get the following error while using `gitfs` with `pygit2`

```plain
_pygit2.GitError: Failed to authenticate SSH session: Unable to send userauth-publickey request
```

look if your private key hash empty lines at the bottom of the file and suppress them for solving the error.

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

This is the [SaltStack recommended](https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html#adding-a-formula-as-a-gitfs-remote) way of doing it, and you can go to the [Git Fileserver](#git-fileserver) section on this document if you need help configuring this service.

You can find a great set of formulas on the following GitHub repositories:

- [Official SaltStack Formulas](https://github.com/saltstack-formulas)
- [Unofficial SaltStack Formulas](https://github.com/salt-formulas)

Although, as mention in [SaltStack documentation](https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html#adding-a-formula-as-a-gitfs-remote), you are encouraged to fork desired formulas to avoid unexpected changes to your infrastructure.

However, sometimes you may need to load some formulas that are not available on a git repository and you want to have them separated from your main `srv` directory.

For that case, you can mount a volume containing all your third party formulas separeted in subdirectories into `/home/salt/data/3pfs/`, and they will be automatically added to the master configuration when your container starts.

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
    --env "USERMAP_UID=$(id -u)" --env "USERMAP_GID=$(id -g)" \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/3pfs/:/home/salt/data/3pfs/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    cdalvaro/docker-salt-master:latest
```

If you need to add more third party formulas, you can restart the container, or you can type the following command:

```sh
docker exec -it salt_stack /sbin/entrypoint.sh app:reload-3rd-formulas
```

`file_roots` base configuration file will be updated with current existing formulas and `salt-master` service will be restarted to reload the new configuration.

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
    cdalvaro/docker-salt-master:latest
```

Check [Available Configuration Parameters](#available-configuration-parameters) section for configuring logrotate.

### Healthcheck

This image includes a [health check](https://docs.docker.com/engine/reference/builder/#healthcheck) script: `/usr/local/sbin/healthcheck` (although it is disable by default). It is useful to check if the `salt-master` service is alive and responding.

If you are running this image under k8s, you can define a _liveness command_ as explained [here](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-a-liveness-command).

If you use `docker-compose` as your container orchestrator, you can add the following entries to your compose file:

```yml
version: "3.4"

services:
  master:
    container_name: salt_master
    image: cdalvaro/docker-salt-master:latest
    healthcheck:
      test: ["CMD", "/usr/local/sbin/healthcheck"]
      start_period: 30s
```

(More info available at [compose file](https://docs.docker.com/compose/compose-file/#healthcheck) official documentation)

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
    cdalvaro/docker-salt-master:latest
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

If you run your _docker-salt-master_ instance with healthcheck enabled, you can use [willfarrell/autoheal](https://github.com/willfarrell/docker-autoheal) image to restart your service when healthcheck fails:

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

Please refer the docker run command options for the `--env-file` flag where you can specify all required environment variables in a single file. This will save you from writing a potentially long docker run command. Alternatively you can use docker-compose.

Below is the list of available options that can be used to customize your SaltStack master installation.

| Parameter                          | Description                                                                                                                                                                                                                |
| :--------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DEBUG`                            | Set this to `true` to enable entrypoint debugging.                                                                                                                                                                         |
| `TIMEZONE`                         | Set the container timezone. Defaults to `UTC`. Values are expected to be in Canonical format. Example: `Europe/Madrid`. See the list of [acceptable values](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). |
| `SALT_LOG_LEVEL`                   | The level of messages to send to the console. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `warning`                                                                                |
| `SALT_LOG_ROTATE_FREQUENCY`        | Logrotate frequency for salt logs. Available options are 'daily', 'weekly', 'monthly', and 'yearly'. Default: `weekly`                                                                                                     |
| `SALT_LOG_ROTATE_RETENTION`        | Keep x files before deleting old log files. Defaults: `52`                                                                                                                                                                 |
| `SALT_LEVEL_LOGFILE`               | The level of messages to send to the log file. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `warning`                                                                               |
| `SALT_API_SERVICE_ENABLED`         | Enable `salt-api` service. Default: `false`                                                                                                                                                                                |
| `SALT_API_USER`                    | Set username for `salt-api` service. Default: `salt_api`                                                                                                                                                                   |
| `SALT_API_USER_PASS`               | `SALT_API_USER` password. Required if `SALT_API_SERVICE_ENBALED` is `true` and `SALT_API_USER` is not empty. _Unset_ by default                                                                                            |
| `SALT_MASTER_SIGN_PUBKEY`          | Sign the master auth-replies with a cryptographic signature of the master's public key. Possible values: 'True' or 'False'. Default: `False`                                                                               |
| `SALT_MASTER_USE_PUBKEY_SIGNATURE` | Instead of computing the signature for each auth-reply, use a pre-calculated signature. This option requires `SALT_MASTER_SIGN_PUBKEY` set to 'True'. Possible values: 'True' or 'False'. Default: `True`                  |
| `SALT_MASTER_SIGN_KEY_NAME`        | The customizable name of the signing-key-pair without suffix. Default: `master_sign`                                                                                                                                       |
| `SALT_MASTER_PUBKEY_SIGNATURE`     | The name of the file in the master's pki-directory that holds the pre-calculated signature of the master's public-key. Default: `master_pubkey_signature`                                                                  |
| `SALT_MASTER_ROOT_USER`            | Forces `salt-master` to be runned as `root` instead of `salt`. Default: `False`                                                                                                                                            |
| `SALT_GITFS_SSH_PRIVATE_KEY`       | The name of the ssh private key for gitfs. Default: `gitfs_ssh`                                                                                                                                                            |
| `SALT_GITFS_SSH_PUBLIC_KEY`        | The name of the ssh public key for gitfs. Default: `gitfs_ssh.pub`                                                                                                                                                         |
| `USERMAP_UID`                      | Sets the uid for user `salt` to the specified uid. Default: `1000`.                                                                                                                                                        |
| `USERMAP_GID`                      | Sets the gid for user `salt` to the specified gid. Default: `1000`.                                                                                                                                                        |

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
    --publish 3505:3505 --publish 3506:3506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    cdalvaro/docker-salt-master:latest
```

## Usage

To test which salt minions are listening the following command can be executed directly from the host machine:

```sh
docker exec -it salt_master salt '*' test.ping
```

Then, you can apply salt states to your minions:

```sh
docker exec -it salt_master salt '*' state.apply [state]
```

## Shell Access

For debugging and maintenance purposes you may want access the container shell. If you are using docker version 1.3.0 or higher you can access a running container shell using docker exec command.

```sh
docker exec -it salt_master bash
```

## Restart Services

You can restart containers services by running the following command:

```sh
docker exec -it salt_master entrypoint.sh app:restart [salt-service]
```

Where `salt-service` is one of: `salt-master` os `salt-api` (if `SALT_API_SERVICE_ENABLED` is set to `true`)

## References

- https://docs.saltstack.com/en/latest/topics/installation/index.html
- https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html
- https://github.com/saltstack/salt/releases

[saltstack_badge]: https://img.shields.io/badge/SaltStack-v3002.1-lightgrey.svg?style=flat-square&logo=Saltstack
[saltstack_release_notes]: https://docs.saltstack.com/en/latest/topics/releases/3002.1.html "SaltStack Release Notes"
[ubuntu_badge]: https://img.shields.io/badge/ubuntu-focal--20200925-E95420.svg?style=flat-square&logo=Ubuntu
[ubuntu_hub_docker]: https://hub.docker.com/_/ubuntu/ "Ubuntu Image"
[github_publish_badge]: https://img.shields.io/github/workflow/status/cdalvaro/docker-salt-master/Publish%20Docker%20image?style=flat-square&label=build&logo=GitHub&logoColor=%23181717
[github_publish_workflow]: https://github.com/cdalvaro/docker-salt-master/actions?query=workflow%3A%22Publish+Docker+image%22
[docker_size_badge]: https://img.shields.io/docker/image-size/cdalvaro/docker-salt-master/latest?style=flat-square&logo=docker&color=2496ED
[docker_hub_tags]: https://hub.docker.com/repository/docker/cdalvaro/docker-salt-master/tags
[codefactor_badge]: https://img.shields.io/codefactor/grade/github/cdalvaro/docker-salt-master?style=flat-square&logo=CodeFactor
[codefactor_score]: https://www.codefactor.io/repository/github/cdalvaro/docker-salt-master
[stackoverflow_badge]: https://img.shields.io/badge/stackoverflow-community-orange?style=flat-square&logo=stackoverflow&color=FE7A16
[stackoverflow_community]: https://stackoverflow.com/tags/salt-stack
[slack_badge]: https://img.shields.io/badge/slack-@saltstackcommunity-blue.svg?style=flat-square&logo=slack&logoColor=4A154B&color=4A154B
[slack_community]: https://saltstackcommunity.herokuapp.com