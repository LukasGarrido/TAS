# Monitorización de MariaDB con Prometheus y Grafana

Se agrega un exporter de MariaDB al stack de monitorización de `tas-06-monitor` (10.33.199.52) para visualizar la base de datos (10.33.199.53) en Grafana.

Flujo de métricas: MariaDB (3306) → `mysqld-exporter` (en el monitor, 9104) → Prometheus → Grafana.

| Elemento | Valor |
|---|---|
| Directorio de trabajo | `/opt/nodo-sur-monitoring` |
| Exporter | `prom/mysqld-exporter:v0.17.2`, puerto 9104 (solo red interna de Compose) |
| Credenciales | `mysqld-exporter/.my.cnf`, permisos `600`, fuera del repositorio |
| Job de Prometheus | `mariadb` |

## Usuario de monitorización en MariaDB

Requisito: el usuario `prometheus` debe existir en la base de datos, con permisos mínimos de lectura de métricas.

Ejecutar en la VM de la base de datos:

```sh
docker exec -it mariadb mariadb -uroot -p
```

```sql
CREATE USER 'prometheus'@'10.33.199.52' IDENTIFIED BY '<hidden_password>' WITH MAX_USER_CONNECTIONS 3;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'prometheus'@'10.33.199.52';
FLUSH PRIVILEGES;
EXIT;
```

## Credenciales del exporter

Crear el directorio y el archivo:

```sh
mkdir -p /opt/nodo-sur-monitoring/mysqld-exporter
touch /opt/nodo-sur-monitoring/mysqld-exporter/.my.cnf
```

Contenido de `/opt/nodo-sur-monitoring/mysqld-exporter/.my.cnf`:

```ini
[client]
user=prometheus
password=<hidden_password>
host=10.33.199.53
port=3306
```

Proteger el archivo:

```sh
chmod 600 /opt/nodo-sur-monitoring/mysqld-exporter/.my.cnf
ls -l /opt/nodo-sur-monitoring/mysqld-exporter/.my.cnf
```

`ls -l` debe mostrar `-rw-------`.

## Servicio en el compose de monitoreo

Editar `/opt/nodo-sur-monitoring/compose.yml` y agregar dentro de `services:`:

```yaml
  mysqld-exporter:
    image: prom/mysqld-exporter:v0.17.2
    restart: unless-stopped
    command:
      - --config.my-cnf=/etc/mysqld-exporter/.my.cnf
    volumes:
      - ./mysqld-exporter/.my.cnf:/etc/mysqld-exporter/.my.cnf:ro
```

## Job en Prometheus

Editar `/opt/nodo-sur-monitoring/prometheus/prometheus.yml` y agregar dentro de `scrape_configs:`:

```yaml
  - job_name: mariadb
    static_configs:
      - targets: ["mysqld-exporter:9104"]
```

El nombre `mysqld-exporter` se resuelve porque Prometheus y el exporter comparten la red de Compose.

## Levantar los servicios

Ejecutar:

```sh
cd /opt/nodo-sur-monitoring
docker compose up -d
docker compose restart prometheus
```

## Configuración en Grafana

1. Crear una conexión de tipo Prometheus (Connections → Data sources → Add data source → Prometheus), con la URL del servicio Prometheus de la red de Compose.
2. Crear un dashboard asociado a esa fuente de datos, con paneles de las métricas de MariaDB.

## Verificación

Ejecutar en el monitor:

```sh
docker compose ps
docker compose logs --tail 20 mysqld-exporter
docker compose exec prometheus wget -qO- http://mysqld-exporter:9104/metrics | grep -E "^mysql_up"
```

`mysql_up` debe valer `1`. En la interfaz de Prometheus (Status → Targets), el job `mariadb` debe aparecer en `UP`.

En la VM de la base de datos, confirmar que ya no hay rechazos:

```sh
docker compose logs --since 5m mariadb | grep -c "Access denied"
```

El resultado esperado es `0`. En Grafana, un panel con la consulta `mysql_up` debe mostrar `1`.
