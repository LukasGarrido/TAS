# Servidor NFS para archivos compartidos de WordPress

El servidor NFS corre en la VM de la base de datos (Alpine Linux, OpenRC) y comparte con los backends la configuración y los archivos subidos de WordPress, para que ambos nodos sirvan el mismo contenido.

| Elemento | Valor |
|---|---|
| Servidor NFS | 10.33.199.53 |
| Clientes | VM de CMS (10.33.199.50 y 10.33.199.51) |
| Directorio exportado | `/srv/nfs/wordpress` |
| Subdirectorios | `config/` y `uploads/` |
| Puertos | 2049/TCP (NFS) y 111 (rpcbind) |

## Servidor (VM de la base de datos)

### Instalación

Ejecutar:

```sh
apk add nfs-utils
```

### Directorios y permisos

Ejecutar:

```sh
mkdir -p /srv/nfs/wordpress/uploads
mkdir -p /srv/nfs/wordpress/config
chown -R nobody:nobody /srv/nfs/wordpress
```

### Exportar la carpeta

Ejecutar:

```sh
echo "/srv/nfs/wordpress 10.33.199.48/29(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
```

### Arrancar los servicios

Ejecutar:

```sh
rc-update add rpcbind default
rc-update add nfs default
rc-service rpcbind start
rc-service nfs start
```

## Origen del `wp-config.php`

Se exporta desde el backend con la configuración más completa y se copia al servidor NFS.

Ejecutar en el backend de origen:

```sh
docker compose exec wordpress cat /var/www/html/wp-config.php > /tmp/wp-config.php
scp /tmp/wp-config.php database@10.33.199.53:/srv/nfs/wordpress/config/wp-config.php
```

## Cliente (VM de CMS)

Repetir en cada backend.

### Instalación del cliente

Ejecutar:

```sh
apk add nfs-utils
rc-update add rpcbind default
rc-service rpcbind start
```

### Montaje

Ejecutar:

```sh
mkdir -p /mnt/wp-config
mount -t nfs 10.33.199.53:/srv/nfs/wordpress/config /mnt/wp-config
```

### Persistencia del montaje

Ejecutar:

```sh
echo "10.33.199.53:/srv/nfs/wordpress/config /mnt/wp-config nfs defaults 0 0" >> /etc/fstab
rc-update add netmount default
```

`netmount` hace que el sistema monte los sistemas de archivos de red al iniciar, una vez levantada la red.

## Verificación

En el servidor:

```sh
rc-service nfs status
exportfs -v
```

En cada cliente:

```sh
showmount -e 10.33.199.53
df -h /mnt/wp-config
sha256sum /mnt/wp-config/wp-config.php
```
