# WordPress en contenedor (Docker) con exporter de Apache

Despliegue de WordPress en cada backend (`tas-06-02` en 10.33.199.51 y `tas-06-cms-02` en 10.33.199.50). El procedimiento es idéntico en ambos nodos. Reemplaza la instalación tradicional descrita en `script_cms.md`.

# Precauciones

Debe haber instalado antes docker, nfs y haber configurado un montaje para el archivo de configuración de wordpress en la ruta `/mnt/wp-config`

| Elemento              | Valor                                                                         |
| --------------------- | ----------------------------------------------------------------------------- |
| Directorio de trabajo | `/opt/cms`                                                                    |
| WordPress             | `wordpress:php8.3-apache`, puerto publicado 8080 (80 dentro del contenedor)   |
| Exporter              | `lusotycoon/apache-exporter`, puerto 9117                                     |
| Configuración         | `wp-config.php` compartido por NFS, montado en `/mnt/wp-config`               |
| Archivos subidos      | Volumen NFS `wp_uploads_shared` (10.33.199.53:`/srv/nfs/wordpress/uploads`)   |
| Base de datos         | Definida en el `wp-config.php` compartido (no hay credenciales en el compose) |

## Directorio de trabajo

Ejecutar:

```sh
mkdir -p /opt/cms
```

## Archivo de estado de Apache

Se crea antes del compose porque este lo monta como archivo. Si no existe al levantar el servicio, Docker crea un directorio con ese nombre.

Ejecutar:

```sh
touch /opt/cms/status.conf
```

Contenido de `/opt/cms/status.conf`:

```apache
<Location /server-status>
    SetHandler server-status
    Require all granted
    RewriteEngine Off
</Location>
```

`RewriteEngine Off` evita que las reglas de WordPress intercepten la ruta `/server-status`.

## Compose

Ejecutar:

```sh
touch /opt/cms/compose.yml
```

Contenido de `/opt/cms/compose.yml`:

```yaml
services:
  wordpress:
    image: wordpress:php8.3-apache
    container_name: wordpress
    restart: unless-stopped
    ports:
      - "8080:80"
    command: >
      bash -c "a2enmod status &&
      a2enconf status &&
      apache2-foreground"
    volumes:
      - wordpress_data:/var/www/html
      - /mnt/wp-config/wp-config.php:/var/www/html/wp-config.php
      - wp_uploads_shared:/var/www/html/wp-content/uploads
      - ./status.conf:/etc/apache2/conf-available/status.conf:ro
  apache-exporter:
    image: lusotycoon/apache-exporter
    command: ["--scrape_uri", "http://wordpress/server-status?auto"]
    ports:
      - "9117:9117"
volumes:
  wordpress_data:
  wp_uploads_shared:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.33.199.53,rw,nfsvers=4
      device: ":/srv/nfs/wordpress/uploads"
```

Qué hace cada parte:

- `command`: habilita el módulo `status` de Apache antes de arrancar el servidor.
- `/mnt/wp-config/wp-config.php`: configuración compartida entre ambos backends (ver `script_nfs.md`).
- `wp_uploads_shared`: volumen NFS para `wp-content/uploads`, de modo que ambos nodos sirvan los mismos archivos.
- `apache-exporter`: lee `/server-status` por la red interna de Compose y expone las métricas en el 9117 para Prometheus.

## Levantar el servicio

Ejecutar:

```sh
cd /opt/cms/
docker compose up -d
```

## Verificación

Ejecutar:

```sh
docker compose ps
curl -sI http://127.0.0.1:8080 | head -n 3
curl -s "http://127.0.0.1:8080/server-status?auto" | head -n 5
curl -s http://127.0.0.1:9117/metrics | grep apache_up
docker compose exec wordpress df -h /var/www/html/wp-content/uploads
```

`apache_up` debe valer `1` y `df` debe mostrar `10.33.199.53:/srv/nfs/wordpress/uploads` como origen. Para comprobar la coherencia entre nodos, subir un archivo desde un backend y comparar su `sha256sum` desde el otro:

```sh
docker compose exec wordpress sha256sum /var/www/html/wp-content/uploads/<archivo>
```
