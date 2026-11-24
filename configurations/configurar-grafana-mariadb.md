# Configurar Grafana para MariaDB

## Credenciales de Grafana

- **URL:** http://grafana.tas-06.arpa
- **Usuario:** admin
- **Contraseña:** `<PASSWORD>`

## 1. Usuario de monitoreo en MariaDB

Se crea un usuario en MariaDB para monitoreo:

- **Usuario:** prometheus
- **Contraseña:** `<PASSWORD>`

El usuario está configurado para que solo pueda conectarse desde la IP `10.33.199.52` (servidor de monitoreo).

## 2. Agregar el exporter al compose.yml de monitoreo

Editar el `compose.yml` de monitoreo y agregar:

```yaml
  mysqld-exporter:
    image: prom/mysqld-exporter:v0.17.2
    restart: unless-stopped
    command:
      - --config.my-cnf=/etc/mysqld-exporter/.my.cnf
    volumes:
      - ./mysqld-exporter/.my.cnf:/etc/mysqld-exporter/.my.cnf:ro
```

## 3. Configurar Prometheus

Editar `/opt/nodo-sur-monitoring/prometheus/prometheus.yml` y agregar:

```yaml
  - job_name: mariadb
    static_configs:
      - targets: ["mysqld-exporter:9104"]
```

## 4. Crear el archivo de credenciales del exporter

Crear el directorio y el archivo:

```sh
mkdir -p /opt/nodo-sur-monitoring/mysqld-exporter
touch /opt/nodo-sur-monitoring/mysqld-exporter/.my.cnf
```

Contenido de `/opt/nodo-sur-monitoring/mysqld-exporter/.my.cnf`:

```ini
[client]
user=prometheus
password=<PASSWORD>
host=10.33.199.53
port=3306
```

## 5. Proteger las credenciales

```sh
chmod 600 /opt/nodo-sur-monitoring/mysqld-exporter/.my.cnf
ls -l /opt/nodo-sur-monitoring/mysqld-exporter/.my.cnf
```

## 6. Configurar Grafana

En el panel de Grafana:

1. Crear una conexión (data source) a Prometheus.
2. Crear un dashboard asociado a esa conexión de Prometheus.
