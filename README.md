# Dockerized Salt Master

<picture align="center">
  <source media="(prefers-color-scheme: dark)" srcset="/social/docker-salt-master-banner-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="/social/docker-salt-master-banner-light.png">
  <img alt="cdalvaro's docker-salt-master banner." src="/social/docker-salt-master-banner-light.png">
</picture>

<p align="center">
  <a href="https://docs.saltproject.io/en/latest/topics/releases/3007.5.html"><img alt="Salt Project" src="https://img.shields.io/badge/Salt-3007.5%20sts-57BCAD.svg?logo=SaltProject"/></a>
  <a href="https://docs.saltproject.io/en/3006/topics/releases/3006.13.html"><img alt="Salt Project" src="https://img.shields.io/badge/Salt-3006.13%20lts-57BCAD.svg?logo=SaltProject"/></a>
  <a href="https://hub.docker.com/_/ubuntu/"><img alt="Ubuntu Image" src="https://img.shields.io/badge/ubuntu-noble--20250529-E95420.svg?logo=Ubuntu"/></a>
  <a href="https://hub.docker.com/repository/docker/cdalvaro/docker-salt-master/tags"><img alt="Docker Image Size" src="https://img.shields.io/docker/image-size/cdalvaro/docker-salt-master/latest?logo=docker&color=2496ED"/></a>
  <a href="https://github.com/users/cdalvaro/packages/container/package/docker-salt-master"><img alt="Architecture AMD64" src="https://img.shields.io/badge/arch-amd64-inactive.svg"/></a>
  <a href="https://github.com/users/cdalvaro/packages/container/package/docker-salt-master"><img alt="Architecture ARM64" src="https://img.shields.io/badge/arch-arm64-inactive.svg"/></a>
</p>

Other languages: [🇪🇸 Español](/docs/es-ES/README.md)

Dockerfile to build a [Salt Project](https://saltproject.io) Master image for the Docker open source container platform.

`salt-master` is installed inside the image using the Salt Project repositories for Ubuntu as documented in the [official documentation](https://docs.saltproject.io/salt/install-guide/en/latest/topics/install-by-operating-system/ubuntu.html).

For other methods to install `salt-master`, please refer to
the [Salt install guide](https://docs.saltproject.io/salt/install-guide/en/latest/index.html).

## 🐳 Installation

### Container Registries

#### Recommended

Automated builds of the image are available on
[GitHub Container Registry](https://github.com/cdalvaro/docker-salt-master/pkgs/container/docker-salt-master) and is
the recommended method of installation.

```sh
docker pull ghcr.io/cdalvaro/docker-salt-master:3007.5_1
```

You can also pull the `latest` tag, which is built from the repository `HEAD`

```sh
docker pull ghcr.io/cdalvaro/docker-salt-master:latest
```

#### Other Registries

These images are also available
from [Docker Registry](https://hub.docker.com/r/cdalvaro/docker-salt-master):

```sh
docker pull cdalvaro/docker-salt-master:latest
```

and from [Quay.io](https://quay.io/repository/cdalvaro/docker-salt-master):

```sh
docker pull quay.io/cdalvaro/docker-salt-master:latest
```

#### Long Term Support

In addition to the latest Salt version, when new LTS (Long Term Support) versions are released, they will be packed into new images which will be available in the container registries as well.

```sh
docker pull ghcr.io/cdalvaro/docker-salt-master:3006.13
```

There are also specific tags for LTS and STS versions:

- `ghcr.io/cdalvaro/docker-salt-master:lts`
- `ghcr.io/cdalvaro/docker-salt-master:sts`

> [!NOTE]
> The `lts` image contains the same features as the `latest` image at the time the LTS version was released, but it will not be updated with new features added to `latest`.
>
> The `sts` image tracks the latest Short Term Support release of Salt and may not match `latest` if additional changes have been made after the STS release.

#### Available Tags

- `cdalvaro/docker-salt-master:latest`
- `cdalvaro/docker-salt-master:3007.5_1`, `cdalvaro/docker-salt-master:sts`
- `cdalvaro/docker-salt-master:3006.13_1`, `cdalvaro/docker-salt-master:lts`

All versions have their SaltGUI counterparts:

- `cdalvaro/docker-salt-master:latest-gui`
- `cdalvaro/docker-salt-master:3007.5_1-gui`, `cdalvaro/docker-salt-master:sts-gui`
- `cdalvaro/docker-salt-master:3006.13_1-gui`, `cdalvaro/docker-salt-master:lts-gui`

### Build From Source

Alternatively, you can build the image locally using `make` command:

```sh
make release
```

## 🚀 Quick Start

The quickest way to get started is using [docker compose](https://docs.docker.com/compose/).

```sh
wget https://raw.githubusercontent.com/cdalvaro/docker-salt-master/master/compose.yml
```

Start the `docker-salt-master` container with the `compose.yml` file by executing:

```sh
docker compose up --detach
```

Alternatively, you can manually launch the `docker-salt-master` container:

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

## ⚙️ Configuration

### Custom Configuration

This image uses its own `master.yml` file to configure `salt-master` to run properly inside the container. However, you
can still tune other configuration parameters to fit your needs by adding your configuration files inside a `config/`
directory and mounting it into `/home/salt/data/config/`.

For example, you can customize the [Reactor System](https://docs.saltproject.io/en/latest/topics/reactor/index.html) by
adding a `reactor.conf` file to `config/`:

```sls
# config/reactor.conf
reactor:                                          # Master config section "reactor"
  - 'salt/minion/*/start':                        # Match tag "salt/minion/*/start"
    - /home/salt/data/config/reactor/start.sls    # Things to do when a minion starts
```

Then, you have to add the `start.sls` file into your `config/reactor/` directory:

```sls
# config/reactor/start.sls
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
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

This image provides support for automatically restart `salt-master` when configuration files change.
This support is disabled by default, but it can be enabled by setting the
`SALT_RESTART_MASTER_ON_CONFIG_CHANGE` environment variable to `True`.

### Custom States

In order to provide salt with your custom states, you must bind the volume `/home/salt/data/srv/` to your `roots` directory.

### Minion Keys

Minion keys can be added automatically on startup to `docker-salt-master` by mounting the volume `/home/salt/data/keys`
and copying the minion keys inside `keys/minions/` directory.

**Note:** It is _recommended to mount this directory to a named volume or a host directory_. That way, you can manage your keys outside the container and avoid losing them when the container is removed.

```sh
mkdir -p keys/minions
rsync root@minion1:/etc/salt/pki/minion/minion.pub keys/minions/minion1

docker run --name salt_master -d \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
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
# minion: /etc/salt/minion.d/autosign_grains.conf
autosign_grains:
  - domain
```

More info at:
[Salt Project - Auto accept Minions From Grains](https://docs.saltproject.io/en/latest/topics/tutorials/autoaccept_grains.html)

### Master Signed Keys

It is possible to use signed master keys by establishing the environment variable `SALT_MASTER_SIGN_PUBKEY` to `True`.

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --env 'SALT_MASTER_SIGN_PUBKEY=True' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

The container will create the `master_sign` key and its signature. More information about how to configure the minion
service can be
found [here](https://docs.saltproject.io/en/latest/topics/tutorials/multimaster_pki.html#prepping-the-minion-to-verify-received-public-keys)
.

Additionally, you can generate new signed keys for your existing master key
by executing the following command:

```sh
docker run --name salt_master -it --rm \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest \
    app:gen-signed-keys
```

The newly created keys will appear inside `keys/generated/master_sign.XXXXX` directory.
Where `XXXXX` is a random code to avoid possible collisions with previous generated keys.

#### Working with Secrets

Master keys can be provided via Docker secrets. To do that, you have to set the following environment variable:

- `SALT_MASTER_KEY_FILE`: The path to the master-key-pair {pem,pub} files without suffixes.

Additionally, you can provide the master-sign key pair as well:

- `SALT_MASTER_SIGN_KEY_FILE`: The path to the master-sign-key-pair {pem,pub} files without suffixes.
- `SALT_MASTER_PUBKEY_SIGNATURE_FILE`: The path of the salt-master public key file with the pre-calculated signature.

Here you have a complete `compose.yml` example

```yml
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
        uid: 1000 # Or $PUID if env variable established
        gid: 1000 # Or $GUID if env variable established
        mode: 0400
      - source: salt-master-pub
        target: master.pub
        uid: 1000 # Or $PUID if env variable established
        gid: 1000 # Or $GUID if env variable established
        mode: 0644
      - source: salt-master-sign-priv-key
        target: master_sign.pem
        uid: 1000 # Or $PUID if env variable established
        gid: 1000 # Or $GUID if env variable established
        mode: 0400
      - source: salt-master-sign-pub-key
        target: master_sign.pub
        uid: 1000 # Or $PUID if env variable established
        gid: 1000 # Or $GUID if env variable established
        mode: 0644
      - source: salt-master-signature
        target: master_pubkey_signature
        uid: 1000 # Or $PUID if env variable established
        gid: 1000 # Or $GUID if env variable established
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

You can enable `salt-api` service by setting env variable `SALT_API_ENABLED` to `True`.

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
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 --publish 8000:8000 \
    --env 'SALT_API_ENABLED=True' \
    --env 'SALT_API_USER_PASS=4wesome-Pass0rd' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

If you choose using the [compose.yml](/compose.yml) file to manage your `salt-master` instance, uncomment `salt-api`
settings to enable and configure the service.

By default, user `salt_api` is created, and you can set its password by setting the environment
variable `SALT_API_USER_PASS`.

You can also change the salt-api _username_ by setting `SALT_API_USER`. It is possible to disable this user by
explicitly setting this variable to an empty string: `SALT_API_USER=''` if you are going to use an `LDAP` server.

As a security measure, if `SALT_API_ENABLED` is set to `True` and you don't disable `SALT_API_USER`, you'll be
required to set `SALT_API_USER_PASS`. Otherwise, the setup process will fail and your container won't work.

`SALT_API_USER_PASS_FILE` env variable is available to provide the password via a file. This is useful when using Docker
secretes. More info about how to configure secrets can be found in the subsection
[_Working with secrets_](#working-with-secrets).

With all that set, you'll be able to provide your _salt-api_ custom configuration by creating the `salt-api.conf` file
inside your `conf` directory.

#### External Authentication

Here is an example of giving permission to the `salt_api` user via pam:

```yml
external_auth:
  pam:
    salt_api:
      - .*
      - "@runner"
      - "@wheel"
      - "@jobs"
```

You can specify different authentication methods, as well as specifying groups (by adding a `%` to the name). For example to authenticate the `admins` group via LDAP:

```yml
external_auth:
  ldap:
    admins%:
      - .*
      - "@runner"
      - "@wheel"
      - "@jobs"
```

#### LDAP Configuration

To authenticate via LDAP you will need to configure salt to access your LDAP server. The following example authenticates API logins against the LDAP server. It then defines group configuration for `external_auth` searches (looking up the user's group membership via `memberOf` attributes in their person object):

```yml
auth.ldap.uri: ldaps://server.example.com # Your LDAP server
auth.ldap.basedn: "dc=server,dc=example,dc=com" # Search base DN (subtree scope).
auth.ldap.binddn: "uid={{ username }},dc=server,dc=exam,ple,dc=com" # The DN to authenticate as (username is substituted from the API authentication information).
auth.ldap.accountattributename: "uid" # The user account attribute type
auth.ldap.groupou: "" # Must be set to an empty string if not in use
auth.ldap.groupclass: "person" # The object class to look at when checking group membership
auth.ldap.groupattribute: "memberOf" # The attribute in that object to look at when checking group membership
```

Finally (since `v3006`) [you will need to enable](https://docs.saltproject.io/en/latest/topics/netapi/netapi-enable-clients.html) one or more client interfaces:

```yml
netapi_enable_clients:
  - local
```

Details of all client interfaces is available at the following
link: [Netapi Client Interfaces](https://docs.saltproject.io/en/latest/topics/netapi/netapi-enable-clients.html)

More information is available in the following
link: [External Authentication System (eAuth)](https://docs.saltproject.io/en/latest/topics/eauth/index.html#acl-eauth).

Now you have your `docker-salt-master` Docker image ready to accept external authentications and to connect external tools
such as [`saltstack/pepper`](https://github.com/saltstack/pepper).

#### Salt Pepper

The `pepper` CLI script allows users to execute Salt commands from computers that are external to computers running the `salt-master` or `salt-minion` daemons as though they were running Salt locally.

##### Installation

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

### Salt Minion

This image contains support for running a built-in `salt-minion` service.
You can enable it by setting the environment variable `SALT_MINION_ENABLED` to `True`.

The `salt-minion` will be automatically accepted by the master. Keys will be automatically configured,
even if `SALT_MASTER_SIGN_PUBKEY=True`.

However, minion keys can be provided via Docker secrets.
To do that, you have to set the env variable `SALT_MINION_KEY_FILE`,
pointing to the path inside the container of the minion-key-pair {pem,pub} files without extensions.

Minion's keys will be stored inside the `keys/SALT_MINION_ID/` directory.

This minion can be configured in the same way as the master.
You can add your custom configuration files inside a `minion_config/` directory
and mount it into `/home/salt/data/minion_config/`.

The default id of the minion is `builtin.minion`.
But you can change it by setting the environment variable `SALT_MINION_ID`.

Log levels are the same as the master,
and you can set them by using the `SALT_LOG_LEVEL` and `SALT_LEVEL_LOGFILE` environment variables.

Here you have an example of how to run a `salt-master` with a built-in `salt-minion`:

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_MINION_ENABLED=True' \
    --env 'SALT_MINION_ID=control-minion' \
    --env 'SALT_MASTER_SIGN_PUBKEY=True' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    --volume $(pwd)/minion_config/:/home/salt/data/minion_config/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

### Host Mapping

By default, the container is configured to run `salt-master` as user and group `salt` with `uid` and `gid` `1000`. From
the host the mounted data volumes will be shown as owned by _user:group_ `1000:1000`. This can be a problem if the host's id is different from `1000` or if files have too restrictive permissions. Specially the keys directory and its contents.

Also, the container processes seem to be executed as the host's user/group `1000`. To avoid this, the container can be configured to
map
the `uid` and `gid` to match host ids by passing the environment variables `PUID` and `PGID`. The following
command maps the ids to the current user and group on the host.

```sh
docker run --name salt_master -it --rm \
    --publish 4505:4505 --publish 4506:4506 \
    --env "PUID=$(id -u)" --env "PGID=$(id -g)" \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

### Git Fileserver

This image uses [PyGit2](https://www.pygit2.org) as gitfs backend to allow Salt to serve files from git repositories.

It can be enabled by adding `gitfs` to
the [`fileserver_backend`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std:conf_master-fileserver_backend)
list (see [Available Configuration Parameters](#available-configuration-parameters)), and configuring one or more
repositories
in [`gitfs_remotes`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std:conf_master-gitfs_remotes).

> [!NOTE]
> Sometimes, the `salt-master` process may restart automatically. If this happens while gitfs is updating repositories,
> lock files may remain undeleted, preventing gitfs from properly updating the repositories.
>
> The simple solution is to restart the container to clear the cache. However, if this happens frequently,
> and `salt-master` is not operating in _multimaster_ mode with shared cache (for example using Ceph, or nfs),
> then it may be useful to set these two configuration parameters to `False`:
>
> ```yaml
> gitfs_global_lock: False
> git_pillar_global_lock: False
> ```

#### PyGit2

You can create an ssh key for pygit2 with the following command:

```sh
ssh-keygen -t ed25519 -C  -f gitfs_ssh -C 'gitfs_ed25519@example.com'
```

Place it wherever you want inside the container and specify its path with the configuration parameters: `gitfs_pubkey`
and `gitfs_privkey` in your `gitfs.conf` file.

For example:

```yml
# config/gitfs.conf
gitfs_provider: pygit2
gitfs_privkey: /home/salt/data/keys/gitfs/gitfs_ssh
gitfs_pubkey: /home/salt/data/keys/gitfs/gitfs_ssh.pub
```

> [!WARNING]
> This image has been tested with an _ed25519_ ssh key.
>
> Alternately, you may create a new RSA key with SHA2 hashing like so:
>
> ```sh
> ssh-keygen -t rsa-sha2-512 -b 4096 -f gitfs_ssh -C 'gitfs_rsa4096@example.com'
> ```

### GPG Keys for Renderers

Salt can use GPG keys to decrypt pillar data. This image is ready to import your GPG keys from the `gpgkeys` directory
inside the `keys` directory.

The private key must be named `private.key` and the public key `pubkey.gpg`.

If you want to provide these keys via secrets, you can set `SALT_GPG_PRIVATE_KEY_FILE` and `SALT_GPG_PUBLIC_KEY_FILE`
env variables to specify the path to the files inside the container.

For example:

```yml
# compose.yml
services:
  salt-master:
    ...
    env:
      SALT_GPG_PRIVATE_KEY_FILE: /run/secrets/private.key
      SALT_GPG_PUBLIC_KEY_FILE: /run/secrets/pubkey.gpg
```

In this case, keys will be symlinked to the `gpgkeys` directory.

It is important that the private key doesn't have passphrase in order to be imported by salt.

To generate a GPG key and export the private/public pair you can use the following commands:

```sh
# Generate key - REMEMBER: Leave empty the passphrase!
gpg --gen-key

# Check GPG keys
gpg --list-secret-keys
gpg: checking the trustdb
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   1  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 1u
gpg: next trustdb check due at 2024-11-09
/tmp/gpgkeys/pubring.kbx
--------------------
sec   rsa3072 2022-11-10 [SC] [expires: 2024-11-09]
      CB032BA54F21722945FDDE399CE3DB8AE37D28B7
uid           [ultimate] Carlos Alvaro <github@cdalvaro.io>
ssb   rsa3072 2022-11-10 [E] [expires: 2024-11-09]

# Export public and private keys
mkdir -p keys/gpgkeys
KEY_ID=github@cdalvaro.io
gpg --armor --export "${KEY_ID}" > keys/gpgkeys/pubkey.gpg
gpg --export-secret-keys --export-options export-backup -o keys/gpgkeys/private.key "${KEY_ID}"
```

More information about this feature is available at the
[official documentation](https://docs.saltproject.io/en/latest/ref/renderers/all/salt.renderers.gpg.html).

#### How to Encrypt Data

You can encrypt strings using the following example:

```sh
echo -n 'Super secret pillar' | gpg --armor --batch --trust-model always --encrypt --recipient "${KEY_ID}"
```

Or you can encrypt files using the example bellow:

```sh
gpg --armor --batch --trust-model always --encrypt --recipient "${KEY_ID}" \
  --output /tmp/gpg_id_ed25519 ~/.ssh/id_ed25519
cat /tmp/gpg_id_ed25519
```

On macOS, you can pipe the output to `pbcopy` to copy the encrypted data to the clipboard. If you are using Linux, you
can use `xclip` or `xsel`.

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
configuring the service.

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
docker run --name salt_master -it --rm \
    --publish 4505:4505 --publish 4506:4506 \
    --env "PUID=$(id -u)" --env "PGID=$(id -g)" \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/3pfs/:/home/salt/data/3pfs/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

If you need to add more third party formulas, you can restart the container, or you can type the following command:

```sh
docker exec -it salt_master /sbin/entrypoint.sh app:reload-3rd-formulas
```

`file_roots` base configuration file will be updated with current existing formulas and `salt-master` service will be
restarted to reload the new configuration.

### Python Extra Packages

Some formulas may depend on Python packages that are not included in the default Salt installation. You can add these packages by setting the `PYTHON_PACKAGES_FILE` environment variable with an absolute path pointing to a `requirements.txt` file inside the container.

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env SALT_LOG_LEVEL="info" \
    --env PYTHON_PACKAGES_FILE=/home/salt/data/other/requirements.txt \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    --volume $(pwd)/requirements.txt:/home/salt/data/other/requirements.txt \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

This will install the packages listed in the `requirements.txt` file into the container
before `salt-master` starts.

Alternatively, you can set the `PYTHON_PACKAGES` environment variable with a list of Python packages to be installed.

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env SALT_LOG_LEVEL="info" \
    --env PYTHON_PACKAGES="docker==7.0.0 redis" \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

Although both methods are supported, they are mutually exclusive. If both are set, `PYTHON_PACKAGES_FILE` will take precedence.

### Logs

`salt-master` output is streamed directly to the container's `stdout` and `stderr`. However, they are also written inside `/home/salt/data/logs/`.

Inside the directory you can find `supervisor/` logs and `salt/` logs.

You can access all logs by mounting the volume: `/home/salt/data/logs/`.

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
services:
  master:
    container_name: salt_master
    image: ghcr.io/cdalvaro/docker-salt-master:latest
    healthcheck:
      test: ["CMD", "/usr/local/sbin/healthcheck"]
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

### SaltGUI

There is a set of dedicated images tagged with `-gui` that include built-in support for [SaltGUI](https://github.com/erwindon/SaltGUI) `1.32.0`.

These images have `salt-api` enabled by default. However, it's up to you to define the [permissions](https://docs.saltproject.io/en/latest/topics/eauth/access_control.html) granted to the `salt-api` user. There is more information about permissions in the [SaltGUI documentation](https://github.com/erwindon/SaltGUI/blob/master/docs/PERMISSIONS.md).

Below is an example of how to run a container with SaltGUI enabled.

#### Create a Salt API Configuration File

First, create a configuration file for `salt-api`. You can use the following example as a starting point:

```yml
# config/salt_api.conf
netapi_enable_clients:
  - local
  - local_async
  - local_batch
  - local_subset
  - runner
  - runner_async

external_auth:
  pam:
    saltgui:
      - .*
      - "@runner"
      - "@wheel"
      - "@jobs"
```

#### Run the Container

Once your configuration is ready, start the container with the following command:

```bash
docker run --name salt_master_gui --detach \
    --publish 4505:4505 --publish 4506:4506 --publish 8000:8000 \
    --env 'SALT_API_USER=saltgui' \
    --env 'SALT_API_USER_PASS=4wesome-Pass0rd' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest-gui
```

> [!NOTE]
> The username used in the `external_auth.pam` section (`saltgui`) must match the value of the `SALT_API_USER` environment variable.

If you plan to use an LDAP authentication backend, refer to the [External Authentication](#external-authentication) section.

#### Access SaltGUI

Once the container is running, you can access the SaltGUI interface at: https://localhost:8000

### Available Configuration Parameters

Please refer the docker run command options for the `--env-file` flag where you can specify all required environment
variables in a single file. This will save you from writing a potentially long docker run command. Alternatively you can
use docker-compose.

Below you can find a list with the available options that can be used to customize your `docker-salt-master`
installation.

| Parameter                                                                                                                             | Description                                                                                                                                                                                                                                                                                                                                                           |
| :------------------------------------------------------------------------------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DEBUG`                                                                                                                               | Set this to `True` to enable entrypoint debugging.                                                                                                                                                                                                                                                                                                                    |
| `TIMEZONE` / `TZ`                                                                                                                     | Set the container timezone. Defaults to `UTC`. Values are expected to be in Canonical format. Example: `Europe/Madrid`. See the list of [acceptable values](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).                                                                                                                                            |
| `PUID`                                                                                                                                | Sets the uid for user `salt` to the specified uid. Default: `1000`.                                                                                                                                                                                                                                                                                                   |
| `PGID`                                                                                                                                | Sets the gid for user `salt` to the specified gid. Default: `1000`.                                                                                                                                                                                                                                                                                                   |
| `PYTHON_PACKAGES`                                                                                                                     | Contains a list of Python packages to be installed. Default: _Unset_.                                                                                                                                                                                                                                                                                                 |
| `PYTHON_PACKAGES_FILE`                                                                                                                | An absolute path inside the container pointing to a requirements.txt file for installing Python extra packages. Takes preference over: `PYTHON_PACKAGES`. Default: _Unset_                                                                                                                                                                                            |
| `SALT_RESTART_MASTER_ON_CONFIG_CHANGE`                                                                                                | Set this to `True` to restart `salt-master` service when configuration files change. Default: `False`.                                                                                                                                                                                                                                                                |
| [`SALT_LOG_LEVEL`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#log-level)                                     | The level of messages to send to the console. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `warning`.                                                                                                                                                                                                                          |
| `SALT_LOG_ROTATE_FREQUENCY`                                                                                                           | Logrotate frequency for salt logs. Available options are 'daily', 'weekly', 'monthly', and 'yearly'. Default: `weekly`.                                                                                                                                                                                                                                               |
| `SALT_LOG_ROTATE_RETENTION`                                                                                                           | Keep x files before deleting old log files. Defaults: `52`.                                                                                                                                                                                                                                                                                                           |
| [`SALT_LEVEL_LOGFILE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#log-level-logfile)                         | The level of messages to send to the log file. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `SALT_LOG_LEVEL`.                                                                                                                                                                                                                  |
| `SALT_MASTER_KEY_FILE`                                                                                                                | The path to the master-key-pair {pem,pub} files without suffixes. Keys will be copied into the `pki` directory. Useful to load the password from secrets. _Unset_ by default.                                                                                                                                                                                         |
| [`SALT_API_ENABLED`](https://docs.saltproject.io/en/latest/ref/cli/salt-api.html)                                                     | Enable `salt-api` service. Default: `False`.                                                                                                                                                                                                                                                                                                                          |
| `SALT_API_USER`                                                                                                                       | Set username for `salt-api` service. Default: `salt_api`.                                                                                                                                                                                                                                                                                                             |
| `SALT_API_USER_PASS_FILE`                                                                                                             | `SALT_API_USER` password file path. Use this variable to set the path of a file containing the password for the `SALT_API_USER`. Useful to load the password from secrets. Has priority over `SALT_API_USER_PASS`. _Unset_ by default.                                                                                                                                |
| `SALT_API_USER_PASS`                                                                                                                  | `SALT_API_USER` password. Required if `SALT_API_SERVICE_ENBALED` is `True`, `SALT_API_USER` is not empty and `SALT_API_USER_PASS_FILE` is unset. _Unset_ by default.                                                                                                                                                                                                  |
| `SALT_API_CERT_CN`                                                                                                                    | Common name in the request. Default: `localhost`.                                                                                                                                                                                                                                                                                                                     |
| `SALT_MINION_ENABLED`                                                                                                                 | Enable `salt-minion` service. Default: `False`.                                                                                                                                                                                                                                                                                                                       |
| `SALT_MINION_ID`                                                                                                                      | Set the id of the `salt-minion` service. Default: `builtin.minion`.                                                                                                                                                                                                                                                                                                   |
| [`SALT_MASTER_SIGN_PUBKEY`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-sign-pubkey)                   | Sign the master auth-replies with a cryptographic signature of the master's public key. Possible values: `True` or `False`. Default: `False`.                                                                                                                                                                                                                         |
| [`SALT_MASTER_USE_PUBKEY_SIGNATURE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-use-pubkey-signature) | Instead of computing the signature for each auth-reply, use a pre-calculated signature. This option requires `SALT_MASTER_SIGN_PUBKEY` set to `True`. Possible values: `True` or `False`. Default: `True`.                                                                                                                                                            |
| [`SALT_MASTER_SIGN_KEY_NAME`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-sign-key-name)               | The customizable name of the signing-key-pair without suffix. Default: `master_sign`.                                                                                                                                                                                                                                                                                 |
| `SALT_MASTER_SIGN_KEY_FILE`                                                                                                           | The path to the signing-key-pair {pem,pub} without suffixes. The pair will be copied into the pki directory if they don't exists previously. Useful to load the password from secrets. _Unset_ by default.                                                                                                                                                            |
| [`SALT_MASTER_PUBKEY_SIGNATURE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-pubkey-signature)         | The name of the file in the master's `pki` directory that holds the pre-calculated signature of the master's public-key. Default: `master_pubkey_signature`.                                                                                                                                                                                                          |
| `SALT_MASTER_PUBKEY_SIGNATURE_FILE`                                                                                                   | The path of the salt-master public key file with the pre-calculated signature. It will be copied inside the `pki` directory if a file with name `SALT_MASTER_PUBKEY_SIGNATURE` doesn't exist. Useful to load the password from secrets. _Unset_ by default.                                                                                                           |
| `SALT_MASTER_ROOT_USER`                                                                                                               | Forces `salt-master` to be run as `root` instead of `salt`. Default: `False`.                                                                                                                                                                                                                                                                                         |
| `SALT_GPG_PRIVATE_KEY_FILE`                                                                                                           | The path to the GPG private key for GPG renderers. Useful to load the key from secrets. _Unset_ by default.                                                                                                                                                                                                                                                           |
| `SALT_GPG_PUBLIC_KEY_FILE`                                                                                                            | The path to the GPG public key for GPG renderers. Useful to load the key from secrets. _Unset_ by default.                                                                                                                                                                                                                                                            |
| [`SALT_REACTOR_WORKER_THREADS`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#reactor-worker-threads)           | The number of workers for the runner/wheel in the reactor. Default: `10`.                                                                                                                                                                                                                                                                                             |
| [`SALT_WORKER_THREADS`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#worker-threads)                           | The number of threads to start for receiving commands and replies from minions. Default: `5`.                                                                                                                                                                                                                                                                         |
| [`SALT_BASE_DIR`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#file-roots)                                     | The `base` path in `file_roots` to look for `salt` and `pillar` directories. Default: `/home/salt/data/srv`.                                                                                                                                                                                                                                                          |
| [`SALT_CONFS_DIR`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std-conf_master-default_include)               | The master will automatically include all config files from this directory. Default: `/home/salt/data/config`. When set to something different than the default value, a symlink is created from `SALT_CONFS_DIR` to `/home/salt/data/config`. This is done to simplify the configuration files allowing to use the same configuration files in different containers. |

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
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
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

Where `salt-service` is one of: `salt-master` or `salt-api` (if `SALT_API_ENABLED` is set to `True`).

## 🔨 Contributing

Everyone is wellcome to contribute to this project, and I really appreciate your support. So don't be shy!

Before you start making changes, read carefully the following notes in order to avoid issues.

> [!WARNING]
> Some tests start and stop a _**non-isolated**_ `salt-minion` instance. So don't run tests locally.
> Tests are automatically executed on GitHub when you push commits to your PR.

## 👏 Credits

Many thanks to:

- [The SaltProject](https://saltproject.io) team for the excellent [salt](https://github.com/saltstack/salt) project.
- [JetBrains](https://www.jetbrains.com) for their free [OpenSource](https://jb.gg/OpenSourceSupport) license.
- [The Contributors](https://github.com/cdalvaro/docker-salt-master/graphs/contributors) for all the smart code and
  suggestions merged in the project.
- [The Stargazers](https://github.com/cdalvaro/docker-salt-master/stargazers) for showing their support.

[![Star History Chart](https://api.star-history.com/svg?repos=cdalvaro/docker-salt-master&type=Date)](https://www.star-history.com/#cdalvaro/docker-salt-master&Date)

<div style="display: flex; align-items: center; justify-content: space-around;">
  <img src="/social/SaltProject_verticallogo_teal.png" alt="SaltProject" height="128px">
  <img src="/social/jb_beam.svg" alt="JetBrains Beam" height="128px">
</div>

## 📖 References

[![StackOverflow Community][stackoverflow_badge]][stackoverflow_community]
[![Slack Community][slack_badge]][slack_community]
[![Reddit channel][reddit_badge]][subreddit]

- [SaltStack Get Started](https://docs.saltproject.io/en/getstarted/)
- [Salt Table of Contents](https://docs.saltproject.io/en/latest/contents.html)

[reddit_badge]: https://img.shields.io/badge/reddit-saltstack-orange?logo=reddit&logoColor=FF4500&color=FF4500
[subreddit]: https://www.reddit.com/r/saltstack/
[stackoverflow_badge]: https://img.shields.io/badge/stackoverflow-community-orange?logo=stackoverflow&color=FE7A16
[stackoverflow_community]: https://stackoverflow.com/tags/salt-stack
[slack_badge]: https://img.shields.io/badge/slack-@saltstackcommunity-blue.svg?logo=slack&logoColor=4A154B&color=4A154B
[slack_community]: https://saltstackcommunity.herokuapp.com

## 📃 License

This project is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
