# Instalación de Docker y Docker Compose

Docker se usa en los nodos del proyecto para ejecutar los servicios en contenedores: MariaDB en la VM de la base de datos y WordPress con su exporter en los backends.

## Alpine Linux

### Repositorio community

Los paquetes `docker` y `docker-cli-compose` están en el repositorio `community`, que debe estar habilitado.

Ejecutar:

```sh
cat /etc/apk/repositories
```

Salida esperada:

```
#/media/sr0/apks
http://dl-cdn.alpinelinux.org/alpine/v3.24/main
http://dl-cdn.alpinelinux.org/alpine/v3.24/community
```

Si la línea de `community` aparece comentada con `#`, quitar el comentario y actualizar el índice:

```sh
apk update
```

### Instalación

Ejecutar:

```sh
apk add docker docker-cli-compose
```

### Habilitar y arrancar el servicio

Ejecutar:

```sh
rc-update add docker default
service docker start
```

`rc-update add` hace que Docker arranque con el sistema.

### Verificación

Ejecutar:

```sh
rc-status | grep docker
docker version
docker compose version
docker run --rm hello-world
```

`rc-status` debe mostrar el servicio como `started`, y `hello-world` debe imprimir el mensaje de bienvenida. Si Docker no responde, revisar `/var/log/docker.log`.
