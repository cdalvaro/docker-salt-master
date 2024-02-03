# Salt Master v3006.6 _Sulfur_ Contenerizado

[![Salt Project][saltproject_badge]][saltproject_release_notes]
[![Ubuntu Image][ubuntu_badge]][ubuntu_hub_docker]
[![Publish Workflow][github_publish_badge]][github_publish_workflow]

[![Docker Image Size][docker_size_badge]][docker_hub_tags]
[![Architecture AMD64][arch_amd64_badge]][arch_link]
[![Architecture ARM64][arch_arm64_badge]][arch_link]

![Banner](/social/docker-salt-master-social.jpg)

Otros idiomas: [🇺🇸 English](/docs/en-US/README.md)

Dockerfile para construir una imagen de [Salt Project](https://saltproject.io) Master para contenedores.

`salt-master` está instalado dentro de la imagen utilizando los repositorios del proyecto Salt para Ubuntu, tal y como se indica en la [documentación oficial](https://docs.saltproject.io/salt/install-guide/en/latest/topics/install-by-operating-system/ubuntu.html).

Para otros métodos de instalación de `salt-master`, por favor consulta la [guía de instalación de Salt](https://docs.saltproject.io/salt/install-guide/en/latest/index.html).

## 🐳 Instalación

### Registros de Contenedores

#### Recomendado

Todas las imágenes están disponibles en el [Registro de Contenedores de GitHub](https://github.com/cdalvaro/docker-salt-master/pkgs/container/docker-salt-master) y es el método recomendado para la instalación.

```sh
docker pull ghcr.io/cdalvaro/docker-salt-master:3006.6
```

También puedes obtener la imagen `latest`, que se construye a partir del repositorio `HEAD`.

```sh
docker pull ghcr.io/cdalvaro/docker-salt-master:latest
```

#### Otros Registros

Estas imágenes están también disponibles en el [Registro de Contenedores de Docker](https://hub.docker.com/r/cdalvaro/docker-salt-master):

```sh
docker pull cdalvaro/docker-salt-master:latest
```

y en [Quay.io](https://quay.io/repository/cdalvaro/docker-salt-master):

```sh
docker pull quay.io/cdalvaro/docker-salt-master:latest
```

### Construir desde la fuente

Alternativamente, puedes construir la imagen localmente utilizando el comando `make`:

```sh
make release
```

## 🚀 Inicio Rápido

La manera más rápida de empezar es utilizando [docker compose](https://docs.docker.com/compose/).

```sh
wget https://raw.githubusercontent.com/cdalvaro/docker-salt-master/master/docker-compose.yml
```

A continuación, inicia el contenedor `docker-salt-master` con el archivo `docker-compose.yml` ejecutando:

```sh
docker compose up --detach
```

O también, puedes lanzar manualmente el contenedor `docker-salt-master` de esta manera:

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

## ⚙️ Configuración

### Personalización

Esta imagen construye su propio archivo de configuración `master.yml` para configurar `salt-master` y garantizar su correcto funcionamiento dentro del contenedor. Sin embargo, puedes ajustar otros parámetros de configuración para adaptarlos a tus necesidades añadiendo tus archivos de configuración dentro de un directorio `config/` y montándolo en `/home/salt/data/config/`.

Por ejemplo, puedes personalizar un [Reactor](https://docs.saltproject.io/en/latest/topics/reactor/index.html) añadiendo un archivo `reactor.conf` a `config/`:

```sls
# config/reactor.conf
reactor:                                          # Master config section "reactor"
  - 'salt/minion/*/start':                        # Match tag "salt/minion/*/start"
    - /home/salt/data/config/reactor/start.sls    # Things to do when a minion starts
```

A continuación, debes añadir el archivo `start.sls` a tu directorio `config/reactor/`:

```sls
# config/reactor/start.sls
highstate_run:
  local.state.apply:
    - tgt: {{ data['id'] }}
```

Por último, ejecuta tu instancia `docker-salt-master` montando los directorios requeridos:

```sh
docker run --name salt_master -d \
    --publish 4505:4505 --publish 4506:4506 \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/config/:/home/salt/data/config/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

Esta imagen incorpora soporte para reiniciar automáticamente `salt-master` cuando cambian los archivos de configuración. Esta opción está deshabilitada por defecto, pero puede habilitarse estableciendo la variable de entorno `SALT_RESTART_MASTER_ON_CONFIG_CHANGE` a `True`.

### Estados Personalizados

Para configurar `salt-master` con tus propios estados personalizados, debes montar el volumen `/home/salt/data/srv/` en tu directorio `roots`.

### Claves de Minions

Las claves de los minions pueden añadirse automáticamente al inicio de `docker-salt-master` montando el volumen `/home/salt/data/keys` y copiando las claves de los minions dentro del directorio `keys/minions/`.

**Nota**: El directorio `/home/salt/data/keys` está definido como un volumen en la imagen `docker-salt-master`, por lo que su contenido puede persistir después de que el contenedor sea eliminado. Sin embargo, es _recomendable montar este directorio en un volumen con nombre o en un directorio del host_. De esta manera, puedes gestionar tus claves fuera del contenedor y evitar perderlas cuando el contenedor sea eliminado.

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

También se puede configurar `docker-salt-master` para aceptar automáticamente minions que cumplan ciertos _grains_. Para ello, añade el archivo `autosign_grains.conf` a tu directorio `config`:

```sls
# config/autosign_grains.conf
autosign_grains_dir: /home/salt/data/srv/autosign_grains
```

Después, dentro de `roots/autosign_grains` puedes añadir un archivo con el nombre del _grain_ que quieres que coincida y rellenarlo con el contenido a coincidir. Por ejemplo, si quieres aceptar automáticamente minions que pertenezcan a dominios específicos, debes añadir el archivo `domain` con los dominios que quieres permitir:

```sls
# roots/autosign_grains/domain
cdalvaro.io
cdalvaro.com
```

Tendrás que configurar el minion para enviar los _grains_ específicos al master en el archivo de configuración del minion:

```sls
# minion: /etc/salt/minion.d/autosign_grains.conf
autosign_grains:
  - domain
```

Más información en:
[Salt Project - Auto accept Minions From Grains](https://docs.saltproject.io/en/latest/topics/tutorials/autoaccept_grains.html)

### Claves de Master Firmadas

Es posible utilizar claves firmadas con `salt-master` estableciendo la variable de entorno `SALT_MASTER_SIGN_PUBKEY` a `True`.

```sh
docker run --name salt_stack --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --env 'SALT_MASTER_SIGN_PUBKEY=True' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

El contenedor creará la clave `master_sign` y su firma. Para más información sobre cómo configurar el servicio del minion para aceptar estas claves consultar la [documentación oficial](https://docs.saltproject.io/en/latest/topics/tutorials/multimaster_pki.html#prepping-the-minion-to-verify-received-public-keys).

Además, se pueden generar nuevas claves ejecutando el siguiente comando:

```sh
docker run --name salt_stack -it --rm \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest \
    app:gen-signed-keys new_master_sign
```

Las nuevas claves estarán disponibles dentro del directorio: `keys/generated/new_master_sign`.

#### Trabajando con _secrets_

Las claves del master pueden ser proporcionadas a través de _secrets_ de Docker. Para hacerlo, debes establecer la siguiente variable de entorno:

- `SALT_MASTER_KEY_FILE`: Ruta al par de claves del master {pem,pub} sin sufijos.

Adicionalmente, puedes proporcionar el par de claves de firma del master:

- `SALT_MASTER_SIGN_KEY_FILE`: Ruta al par de claves firmadas {pem,pub} sin sufijos.
- `SALT_MASTER_PUBKEY_SIGNATURE_FILE`: Ruta al archivo de la clave pública de `salt-master` con la firma pre-calculada.

A continuación un ejemplo completo de `docker-compose.yml` con estas variables y el uso de _secrets_:

```yml
version: "3.9"

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

El servicio `salt-api` puede habilitarse estableciendo la variable de entorno `SALT_API_SERVICE_ENABLED` a `True`.

Un certificado SSL autofirmado se generará automáticamente y la siguiente configuración se añadirá al archivo de configuración del master:

```yml
rest_cherrypy:
  port: 8000
  ssl_crt: /etc/pki/tls/certs/docker-salt-master.crt
  ssl_key: /etc/pki/tls/certs/docker-salt-master.key
```

El contenedor expone el puerto `8000` por defecto, aunque puedes asociar este puerto a cualquier otro puerto que desees en tu comando `docker run`:

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

Si eliges usar el archivo [docker-compose.yml](/docker-compose.yml) para gestionar tu instancia `salt-master`, descomenta la configuración de `salt-api` para habilitar y configurar el servicio.

Por defecto, se crea el usuario `salt_api` para este servicio, y puedes establecer su contraseña estableciendo la variable de entorno `SALT_API_USER_PASS`. Pero también puedes cambiar el _username_ de `salt-api` estableciendo `SALT_API_USER`.

Sin embargo, es posible deshabilitar este usuario estableciendo explícitamente esta variable a una cadena vacía: `SALT_API_USER=''` si vas a usar un servidor `LDAP`, por ejemplo.

Como medida de seguridad, si `SALT_API_SERVICE_ENABLED` se establece a `True` y no deshabilitas `SALT_API_USER`, se requerirá establecer la variable `SALT_API_USER_PASS`. De lo contrario, el proceso de configuración fallará y tu contenedor no arrancará.

También se da la opción de establecer la variable de entorno `SALT_API_USER_PASS_FILE` para proporcionar la contraseña a través de un archivo. Esto es útil cuando se usan _secrets_ de Docker. Más información sobre cómo configurar secretos está disponible en la sección [_Trabajando con secrets_](#trabajando-con-secrets).

Con todo esto configurado, podrás proporcionar tu propia configuración personalizada para `salt-api` creando el archivo `salt-api.conf` dentro de tu directorio `config`:

```yml
external_auth:
  pam:
    salt_api:
      - .*
      - "@runner"
      - "@wheel"
      - "@jobs"
```

En el enlace: [External Authentication System (eAuth)](https://docs.saltproject.io/en/latest/topics/eauth/index.html#acl-eauth) hay más información disponible sobre cómo configurar `salt-api` para autenticar usuarios externos.

Ahora tienes tu imagen `docker-salt-master` lista para aceptar autenticaciones externas y conectar herramientas externas como [`saltstack/pepper`](https://github.com/saltstack/pepper).

#### Salt Pepper

El script `pepper` permite a los usuarios ejecutar comandos Salt desde ordenadores externos a los que ejecutan los demonios `salt-master` o `salt-minion` como si estuvieran ejecutando Salt localmente.

##### Instalación

```sh
pip3 install salt-pepper
```

##### Configuración

A continuación, configura `pepper` rellenando tu archivo `~/.pepperrc` con tus credenciales de `salt-api`:

```conf
[main]
SALTAPI_URL=https://your.salt-master.hostname:8000/
SALTAPI_USER=salt_api
SALTAPI_PASS=4wesome-Pass0rd
SALTAPI_EAUTH=pam
```

##### Uso

Empieza ejecutando estados de Salt con `pepper`:

```sh
pepper '*' test.ping
```

### Mapeo de Host

Por defecto, el contenedor está configurado para ejecutar `salt-master` como usuario y grupo `salt` con `uid` y `gid` `1000`. Desde el host los volúmenes de datos montados se mostrarán con propiedad del _usuario:grupo_ `1000:1000`. Esto tener efectos desfavorables si los ids no coinciden o si los permisos de los archivos montados son muy restrictivos. Especialmente el directorio de claves y sus contenidos.

También, los procesos internos del contenedor se mostrarán como propiedad del usuario/grupo `1000`. Para evitar esto, el contenedor puede configurarse para mapear los `uid` y `gid` para que coincidan con los ids del host estableciendo las variables de entorno `PUID` y `PGID`. El siguiente comando asocia los ids para que coincidan con el usuario y grupo actual del host.

```sh
docker run --name salt_stack -it --rm \
    --publish 4505:4505 --publish 4506:4506 \
    --env "PUID=$(id -u)" --env "PGID=$(id -g)" \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

### Servidor de Archivos Git

Esta imagen integra [PyGit2](https://www.pygit2.org) como _backend_ de `gitfs` para permitir a Salt servir archivos desde repositorios git.

Puede habilitarse añadiendo `gitfs` a la lista de [`fileserver_backend`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std:conf_master-fileserver_backend) (ver [Parámetros de Configuración Disponibles](#parámetros-de-configuración-disponibles)), y configurando uno o más repositorios en [`gitfs_remotes`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std:conf_master-gitfs_remotes).

#### PyGit2

Puedes crear una clave ssh para `pygit2` con el siguiente comando:

```sh
ssh-keygen -t ed25519 -C  -f gitfs_ssh -C 'gitfs_ed25519@example.com'
```

Y colocarla donde quieras dentro del contenedor. Luego, especifica su ruta con los parámetros de configuración: `gitfs_pubkey` y `gitfs_privkey` en tu archivo de configuración `gitfs.conf`.

Por ejemplo:

```yml
# config/gitfs.conf
gitfs_provider: pygit2
gitfs_privkey: /home/salt/data/keys/gitfs/gitfs_ssh
gitfs_pubkey: /home/salt/data/keys/gitfs/gitfs_ssh.pub
```

##### Nota Importante

La imagen se ha probado con una clave ssh de tipo _ed25519_.

Alternativamente, puedes crear una nueva clave RSA con _hashing_ SHA2 de la siguiente manera:

```sh
ssh-keygen -t rsa-sha2-512 -b 4096 -f gitfs_ssh -C 'gitfs_rsa4096@example.com'
```

### Claves GPG para Desencriptar Pillar

Salt puede utilizar claves GPG para desencriptar datos de pillar. Esta imagen está lista para importar tus claves GPG desde el directorio `gpgkeys` dentro del directorio `keys`.

La clave privada debe llamarse `private.key` y la clave pública `pubkey.gpg`.

Si quieres proporcionar estas claves a través de _secrets_, puedes establecer las variables de entorno `SALT_GPG_PRIVATE_KEY_FILE` y `SALT_GPG_PUBLIC_KEY_FILE` para especificar la ruta a los archivos dentro del contenedor.

Por ejemplo:

```yml
# docker-compose.yml
services:
  salt-master:
    ...
    env:
      SALT_GPG_PRIVATE_KEY_FILE: /run/secrets/private.key
      SALT_GPG_PUBLIC_KEY_FILE: /run/secrets/pubkey.gpg
```

En este caso, las clave se enlazarán simbólicamente al directorio `gpgkeys`.

Es importante que la clave privada no tenga contraseña para poder ser importada por Salt.

Para generar una clave GPG y exportar el par privado/público puedes usar los siguientes comandos:

```sh
# Crear clave - Recuerda: Deja la contraseña en vacía!
gpg --gen-key

# Comprobar claves GPG
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

# Exportar el par de claves pública/privada
mkdir -p keys/gpgkeys
KEY_ID=github@cdalvaro.io
gpg --armor --export "${KEY_ID}" > keys/gpgkeys/pubkey.gpg
gpg --export-secret-keys --export-options export-backup -o keys/gpgkeys/private.key "${KEY_ID}"
```

Más información acerca de esta funcionalidad disponible en la [documentación oficial](https://docs.saltproject.io/en/latest/ref/renderers/all/salt.renderers.gpg.html).

#### Cómo encriptar datos

Puedes encriptar cadenas utilizando el siguiente ejemplo:

```sh
echo -n 'Super secret pillar' | gpg --armor --batch --trust-model always --encrypt --recipient "${KEY_ID}"
```

O puedes encriptar archivos utilizando el siguiente ejemplo:

```sh
gpg --armor --batch --trust-model always --encrypt --recipient "${KEY_ID}" \
  --output /tmp/gpg_id_ed25519 ~/.ssh/id_ed25519
cat /tmp/gpg_id_ed25519
```

En macOS, puedes enviar la salida a `pbcopy` para copiar los datos encriptados al portapapeles. Si estás usando Linux, puedes usar `xclip` o `xsel`.

### Fórmulas de terceros

Puedes añadir fórmulas de terceros a tu configuración simplemente añadiéndolas a tus `gitfs_remotes`:

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

Esta es la manera [recomendada por Salt](https://docs.saltproject.io/en/latest/topics/development/conventions/formulas.html#adding-a-formula-as-a-gitfs-remote) de hacerlo, y puedes ir a la sección [Servidor de Archivos Git](#servidor-de-archivos-git) de este documento si necesitas ayuda para configurar el servicio.

Puedes encontrar grupos de fórulas en los siguientes repositorios de GitHub:

- [Official Salt Formulas](https://github.com/saltstack-formulas)
- [Unofficial Salt Formulas](https://github.com/salt-formulas)

Aunque, como se menciona en la [documentación del Proyecto Salt](https://docs.saltproject.io/en/latest/topics/development/conventions/formulas.html#adding-a-formula-as-a-gitfs-remote), se recomienda hacer un _fork_ de las fórmulas deseadas para evitar cambios inesperados en tu infraestructura.

Sin embargo, a veces puedes necesitar cargar algunas fórmulas que no están disponibles en un repositorio git, y quieres tenerlas separadas de tu directorio `srv` principal.

Para este caso, puedes montar un volumen que contenga todas tus fórmulas de terceros separadas en subdirectorios en `/home/salt/data/3pfs/`, y se añadirán automáticamente a la configuración del master cuando tu contenedor arranque.

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

Si necesitas añadir más fórmulas de terceros, puedes añadirlas y reiniciar el contenedor, o introducir el siguiente comando tras añadirlas:

```sh
docker exec -it salt_stack /sbin/entrypoint.sh app:reload-3rd-formulas
```

El archivo de configuración `file_roots` se actualizará con las fórmulas existentes y el servicio `salt-master` se reiniciará para recargar la nueva configuración.

### Logs

La salida de `salt-master` se redirige directamente al `stdout` y `stderr` del contenedor. Sin embargo, también se escriben dentro de `/home/salt/data/logs/`.

Este directorio se define como un volumen para que los logs puedan persistir después de que el contenedor sea eliminado.

Dentro del directorio puedes encontrar los logs de `supervisor/` y `salt/`.

Puedes acceder a todos los logs montando el volumen: `/home/salt/data/logs/`.

```sh
docker run --name salt_master --detach \
    --publish 4505:4505 --publish 4506:4506 \
    --env 'SALT_LOG_LEVEL=info' \
    --volume $(pwd)/roots/:/home/salt/data/srv/ \
    --volume $(pwd)/keys/:/home/salt/data/keys/ \
    --volume $(pwd)/logs/:/home/salt/data/logs/ \
    ghcr.io/cdalvaro/docker-salt-master:latest
```

Consulta la sección [Parámetros de Configuración Disponibles](#parámetros-de-configuración-disponibles) para configurar logrotate.

### Comprobación de Salud (Healthcheck)

Esta imagen incluye un script de [healthcheck](https://docs.docker.com/engine/reference/builder/#healthcheck): `/usr/local/sbin/healthcheck` (aunque está deshabilitado por defecto). Es útil para comprobar si el servicio `salt-master` está vivo y responde.

Si ejecutas esta imagen bajo k8s, puedes definir un _comando de liveness_ como se explica [aquí](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-a-liveness-command).

Si usas `docker compose` como orquestador de contenedores, puedes añadir las siguientes entradas a tu `docker-compose.yml`:

```yml
version: "3.4"

services:
  master:
    container_name: salt_master
    image: ghcr.io/cdalvaro/docker-salt-master:latest
    healthcheck:
      test: ["CMD", "/usr/local/sbin/healthcheck"]
      start_period: 30s
```

(Más información sobre healthcheck usando `docker compose` en la [documentación oficial](https://docs.docker.com/compose/compose-file/#healthcheck)).

O, si lanzas tu contenedor [con docker](https://docs.docker.com/engine/reference/run/#healthcheck):

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

Finalmente, puedes comprobar manualmente la salud del contenedor ejecutando el siguiente comando:

```sh
docker inspect --format "{{json .State.Health }}" salt_master | jq
```

La salida será algo parecida a esto:

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

#### Autocura (Autoheal)

Si ejecutas tu instancia de `docker-salt-master` con el _healthcheck_ habilitado, puedes usar la imagen [willfarrell/autoheal](https://github.com/willfarrell/docker-autoheal) para reiniciar automáticamente tu contenedor si el _healthcheck_ falla.

```sh
docker run -d \
  --name autoheal \
  --restart=always \
  -e AUTOHEAL_CONTAINER_LABEL=all \
  -v /var/run/docker.sock:/var/run/docker.sock \
  willfarrell/autoheal
```

Este contenedor vigilará tus contenedores y reiniciará las instancias que fallen.

### Parámetros de Configuración Disponibles

Por favor, consulta la ayuda del comando `docker run` para ver la información del la opción `--env-file` con la que puedes especificar todas las variables de entorno requeridas en un solo archivo. Esto te ahorrará escribir un comando `docker run` potencialmente largo. Alternativamente, puedes usar `docker compose`.

A continuación puedes encontrar una lista con las opciones disponibles que pueden ser usadas para personalizar tu instalación de `docker-salt-master`.

| Parámetro                                                                                                                             | Descripción                                                                                                                                                                                                                                                                                                                |
| :------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DEBUG`                                                                                                                               | Establece esta opción a `True` para que la salida sea más _verbosa_.                                                                                                                                                                                                                                                       |
| `TIMEZONE` / `TZ`                                                                                                                     | Establece la zona horaria del contenedor. Por defecto: `UTC`. Se espera que el valor proporcionado esté en forma canónica. Por ejemplo: `Europe/Madrid`. Lista completa de [valores válidos](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).                                                                |
| `PUID`                                                                                                                                | Establece el uid del usuario `salt` al valor indicado. Por defecto: `1000`.                                                                                                                                                                                                                                                |
| `PGID`                                                                                                                                | Establece el gid del usuario `salt` al valor indicado. Por defecto: `1000`.                                                                                                                                                                                                                                                |
| `SALT_RESTART_MASTER_ON_CONFIG_CHANGE`                                                                                                | Establece el valor a `True` para reiniciar el servicio `salt-master` cuando se detecte un cambio en los archivos de configuración. Por defecto: `False`.                                                                                                                                                                   |
| [`SALT_LOG_LEVEL`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#log-level)                                     | El nivel de los mensajes que se enviarán a la consola. Valores aceptados: 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Por defecto: `warning`.                                                                                                                                                      |
| `SALT_LOG_ROTATE_FREQUENCY`                                                                                                           | Frecuencia de rotado de logs. Valores aceptados: 'daily', 'weekly', 'monthly', y 'yearly'. Por defecto: `weekly`.                                                                                                                                                                                                          |
| `SALT_LOG_ROTATE_RETENTION`                                                                                                           | Keep x files before deleting old log files. Defaults: `52`.                                                                                                                                                                                                                                                                |
| [`SALT_LEVEL_LOGFILE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#log-level-logfile)                         | The level of messages to send to the log file. One of 'garbage', 'trace', 'debug', info', 'warning', 'error', 'critical'. Default: `SALT_LOG_LEVEL`.                                                                                                                                                                       |
| `SALT_MASTER_KEY_FILE`                                                                                                                | La ruta del par de archivos de la clave del master {pem,pub} sin sufijos. Las claves se copiarán al directorio `pki`. Es útil cuando se quieren cargar las claves usando _secrets_. Por defecto: _No establecida_.                                                                                                         |
| [`SALT_API_SERVICE_ENABLED`](https://docs.saltproject.io/en/latest/ref/cli/salt-api.html)                                             | Habilita el servicio `salt-api`. Por defecto: `False`.                                                                                                                                                                                                                                                                     |
| `SALT_API_USER`                                                                                                                       | Establece el nombre de usuario para el servicio `salt-api`. Por defecto: `salt_api`.                                                                                                                                                                                                                                       |
| `SALT_API_USER_PASS_FILE`                                                                                                             | Archivo con la contraseña para el usuario `SALT_API_USER`. Usa esta variable para establecer la ruta del archivo que contiene la contraseña del usuario `SALT_API_USER`. Es útil para cargar la contraseña usando _secrets_. Esta variable tiene preferencia frente a `SALT_API_USER_PASS`. Por defecto: _No establecida_. |
| `SALT_API_USER_PASS`                                                                                                                  | Contraseña del usuario `SALT_API_USER`. Requerida si `SALT_API_SERVICE_ENBALED` es `True`, `SALT_API_USER` no está vacía y no se ha definido `SALT_API_USER_PASS_FILE`. Por defecto: _No establecida_.                                                                                                                     |
| `SALT_API_CERT_CN`                                                                                                                    | _Common name_ en el certificado de `salt-api`. Por defecto: `localhost`.                                                                                                                                                                                                                                                   |
| [`SALT_MASTER_SIGN_PUBKEY`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-sign-pubkey)                   | Firma las respuestas de `salt-master` con una firma criptográfica usando la clave pública del master. Valores permitidos: `True` o `False`. Por defecto: `False`.                                                                                                                                                          |
| [`SALT_MASTER_USE_PUBKEY_SIGNATURE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-use-pubkey-signature) | En lugar de calcular la firma para cada respuesta, usa una firma pre-calculada. Esta opción requiere que `SALT_MASTER_SIGN_PUBKEY` sea `True`. Valores posibles: `True` or `False`. Por defecto: `True`.                                                                                                                   |
| [`SALT_MASTER_SIGN_KEY_NAME`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-sign-key-name)               | El nombre del par de claves de firma sin sufijo. Por defecto: `master_sign`.                                                                                                                                                                                                                                               |
| `SALT_MASTER_SIGN_KEY_FILE`                                                                                                           | La ruta al par de archivos de clave de firma {pem,pub} sin sufijos. El par de archivos se copiará al directorio `pki` si no existían previamente. Útil para cargar las claves usando _secrets_. Por defecto: _No establecida_.                                                                                             |
| [`SALT_MASTER_PUBKEY_SIGNATURE`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#master-pubkey-signature)         | El nombre del fichero en el directorio `pki` del master que contiene la firma pre-calculada de la clave pública. Por defecto: `master_pubkey_signature`.                                                                                                                                                                   |
| `SALT_MASTER_PUBKEY_SIGNATURE_FILE`                                                                                                   | La ruta del archivo con la firma pre-calculada de la clave pública de salt-master. La clave se copiará al directorio `pki` si no existe previamente un archivo con el nombre `SALT_MASTER_PUBKEY_SIGNATURE`. Útil para cargar el archivo usando _secrets_. Por defecto: _No establecida_.                                  |
| `SALT_MASTER_ROOT_USER`                                                                                                               | Fuerza que `salt-master` se ejecute como `root` en lugar de hacer con el usuario `salt`. Por defecto: `False`.                                                                                                                                                                                                             |
| `SALT_GPG_PRIVATE_KEY_FILE`                                                                                                           | La ruta de la clave GPG privada para desencriptar contenidos. Útil para cargar la clave usando _secrets_. Por defecto: _No establecida_.                                                                                                                                                                                   |
| `SALT_GPG_PUBLIC_KEY_FILE`                                                                                                            | La ruta de la calve GPG pública para desencriptar contenidos. Útil para cargar la clave usando _secrets_. Por defecto: _No establecida_.                                                                                                                                                                                   |
| [`SALT_REACTOR_WORKER_THREADS`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#reactor-worker-threads)           | El número de procesos de runner/wheel en el reactor. Por defecto: `10`.                                                                                                                                                                                                                                                  |
| [`SALT_WORKER_THREADS`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#worker-threads)                           | El número de hilos para recibir comandos y respuestas de los minions conectados. Por defecto: `5`.                                                                                                                                                                                                                              |
| [`SALT_BASE_DIR`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#file-roots)                                     | La ruta `base` en `file_roots` para buscar los directorios `salt` y `pillar`. Por defecto: `/home/salt/data/srv`.                                                                                                                                                                                                               |
| [`SALT_CONFS_DIR`](https://docs.saltproject.io/en/latest/ref/configuration/master.html#std-conf_master-default_include)               | `salt-master` cargará automáticamente los ficheros de configuración que encuentre en este directorio. Por defecto: `/home/salt/data/config`.                                                                                                                                                                                                             |

Cualquier parámetro no listado en la tabla anterior y disponible en el siguiente [enlace](https://docs.saltproject.io/en/latest/ref/configuration/examples.html#configuration-examples-master), puede establecerse creando el directorio `config` y añadiendo en él un archivo `.conf` con los parámetros deseados:

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

## 🧑‍🚀 Uso

Para comprobar que minions están escuchando, se puede ejecutar el siguiente comando directamente desde la máquina donde corre el contenedor de `salt-master`:

```sh
docker exec -it salt_master salt '*' test.ping
```

Para aplicar un estado en todos los minions:

```sh
docker exec -it salt_master salt '*' state.apply [state]
```

## 🧰 Acceso con Shell

Para propósitos de depuración y mantenimiento, es posible que desees acceder a la shell del contenedor. Si estás usando docker versión 1.3.0 o superior, puedes acceder a la shell de un contenedor en ejecución usando el comando `docker exec`.

```sh
docker exec -it salt_master bash
```

## 💀 Reiniciar Servicios

Puedes reiniciar los servicios de los contenedores ejecutando el siguiente comando:

```sh
docker exec -it salt_master entrypoint.sh app:restart [salt-service]
```

Donde `salt-service` es uno de: `salt-master` o `salt-api` (si `SALT_API_SERVICE_ENABLED` está establecido a `True`).

## 🔨 Contribuciones

Quien quiera contribuir a este proyecto, es bienvenido. Y yo realmente aprecio cualquier ayuda.

Antes de empezar a hacer cambios, lee atentamente las siguientes notas para evitar problemas.

- ⚠️ Algunos tests requieren que se ejecute un `salt-minion` no aislado. Así que no ejecutes los tests localmente. Los tests se ejecutan automáticamente en GitHub cuando haces _push_ a tus PR.

## 👏 Agradecimientos

Muchas gracias:

- Al equipo [SaltProject](https://saltproject.io) por su excelente proyecto [salt](https://github.com/saltstack/salt)
- A [JetBrains](https://www.jetbrains.com) por su licencia _open source_ gratuita [OpenSource](https://jb.gg/OpenSourceSupport)
- A [los Contribuidores](https://github.com/cdalvaro/docker-salt-master/graphs/contributors) por vuestras aportaciones de código y vuestras sugerencias.
- A [los Stargazers](https://github.com/cdalvaro/docker-salt-master/stargazers) por mostrar vuestro apoyo.

<div style="display: flex; align-items: center; justify-content: space-around;">
  <img src="social/SaltProject_verticallogo_teal.png" alt="SaltProject" height="128px">
  <img src="social/jb_beam.svg" alt="JetBrains Beam" height="128px">
</div>

## 📖 Referencias

[![StackOverflow Community][stackoverflow_badge]][stackoverflow_community]
[![Slack Community][slack_badge]][slack_community]
[![Reddit channel][reddit_badge]][subreddit]

- https://docs.saltproject.io/en/getstarted/
- https://docs.saltproject.io/en/latest/contents.html

[saltproject_badge]: https://img.shields.io/badge/Salt-v3006.6-lightgrey.svg?logo=Saltstack
[saltproject_release_notes]: https://docs.saltproject.io/en/latest/topics/releases/3006.6.html "Salt Project Release Notes"
[ubuntu_badge]: https://img.shields.io/badge/ubuntu-jammy--20231004-E95420.svg?logo=Ubuntu
[ubuntu_hub_docker]: https://hub.docker.com/_/ubuntu/ "Ubuntu Image"
[github_publish_badge]: https://github.com/cdalvaro/docker-salt-master/actions/workflows/publish.yml/badge.svg
[github_publish_workflow]: https://github.com/cdalvaro/docker-salt-master/actions/workflows/publish.yml
[docker_size_badge]: https://img.shields.io/docker/image-size/cdalvaro/docker-salt-master/latest?logo=docker&color=2496ED
[docker_hub_tags]: https://hub.docker.com/repository/docker/cdalvaro/docker-salt-master/tags
[reddit_badge]: https://img.shields.io/badge/reddit-saltstack-orange?logo=reddit&logoColor=FF4500&color=FF4500
[subreddit]: https://www.reddit.com/r/saltstack/
[stackoverflow_badge]: https://img.shields.io/badge/stackoverflow-community-orange?logo=stackoverflow&color=FE7A16
[stackoverflow_community]: https://stackoverflow.com/tags/salt-stack
[slack_badge]: https://img.shields.io/badge/slack-@saltstackcommunity-blue.svg?logo=slack&logoColor=4A154B&color=4A154B
[slack_community]: https://saltstackcommunity.herokuapp.com
[arch_amd64_badge]: https://img.shields.io/badge/arch-amd64-inactive.svg
[arch_arm64_badge]: https://img.shields.io/badge/arch-arm64-inactive.svg
[arch_link]: https://github.com/users/cdalvaro/packages/container/package/docker-salt-master

## 📃 Licencia

Este proyecto está disponible como código abierto bajo los términos de la [Licencia MIT](https://opensource.org/licenses/MIT).
