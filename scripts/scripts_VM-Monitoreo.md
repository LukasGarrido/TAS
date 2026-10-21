# Configuración de la VM de monitoreo

Stack de monitorización en `tas-06-monitor`: Prometheus (métricas), Alertmanager (alertas), Loki (logs) y Grafana (paneles), desplegado con Docker Compose. Es la base sobre la que se agregan los exporters de Nginx, BIND9, Apache y MariaDB (ver sus documentos).

## Características de la VM

| Elemento | Valor |
|---|---|
| Sistema operativo | Alpine Linux 3.24.2 |
| CPU | 2 núcleos |
| RAM / Swap | 4 GB / 4 GB |
| Disco | 191,6 GB |
| IP privada | 10.33.199.52 |
| IP pública | 10.33.195.245 (se quitará al terminar la configuración) |
| Docker / Compose | v29.8.1 / v5.1.4 |
| Directorio de trabajo | `/opt/nodo-sur-monitoring` |

## Servicios

| Servicio | Imagen | Puerto (solo `127.0.0.1`) | Función |
|---|---|---|---|
| Prometheus | `prom/prometheus:v3.5.0` | 9090 | Recolección de métricas y evaluación de reglas (retención 7 días) |
| Alertmanager | `prom/alertmanager:v0.28.1` | 9093 | Agrupación y envío de alertas |
| Loki | `grafana/loki:3.5.0` | 3100 | Almacenamiento de logs (retención 7 días) |
| Grafana | `grafana/grafana:11.6.0` | 3000 | Paneles |

Todos los puertos se publican solo en la interfaz local de la VM; el acceso desde fuera se hace por túnel SSH.

## Estructura de directorios

Ejecutar:

```sh
mkdir -p /opt/nodo-sur-monitoring/prometheus/rules
mkdir -p /opt/nodo-sur-monitoring/alertmanager
mkdir -p /opt/nodo-sur-monitoring/loki
mkdir -p /opt/nodo-sur-monitoring/grafana/provisioning/datasources

cd /opt/nodo-sur-monitoring
```

Los archivos siguientes se crean con `cat > <archivo> <<'EOF'` desde ese directorio. Las comillas en `'EOF'` evitan que el shell interprete caracteres especiales.

## Prometheus

Archivo `prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s

rule_files:
  - /etc/prometheus/rules/*.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets:
          - prometheus:9090
```

Archivo `prometheus/rules/alerts.yml`:

```yaml
groups:
  - name: nodo-sur
    rules:
      - alert: PrometheusTargetDown
        expr: up{job="prometheus"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "El endpoint de Prometheus no responde"
          description: "Prometheus no puede consultar sus propias métricas."
```

## Alertmanager

Archivo `alertmanager/alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: laboratorio
  group_by:
    - alertname
    - job
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 4h

receivers:
  - name: laboratorio
```

## Loki

Archivo `loki/loki.yml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules

schema_config:
  configs:
    - from: "2024-04-01"
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 168h
  allow_structured_metadata: true

compactor:
  working_directory: /loki/retention
  retention_enabled: true
  delete_request_store: filesystem
```

## Compose

Archivo `compose.yaml`:

```yaml
services:
  prometheus:
    image: prom/prometheus:v3.5.0
    restart: unless-stopped
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=7d
      - --web.enable-lifecycle
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/rules:/etc/prometheus/rules:ro
      - prometheus_data:/prometheus
    ports:
      - "127.0.0.1:9090:9090"
    depends_on:
      - alertmanager

  alertmanager:
    image: prom/alertmanager:v0.28.1
    restart: unless-stopped
    command:
      - --config.file=/etc/alertmanager/alertmanager.yml
      - --storage.path=/alertmanager
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    ports:
      - "127.0.0.1:9093:9093"

  loki:
    image: grafana/loki:3.5.0
    restart: unless-stopped
    command:
      - -config.file=/etc/loki/loki.yml
    volumes:
      - ./loki/loki.yml:/etc/loki/loki.yml:ro
      - loki_data:/loki
    ports:
      - "127.0.0.1:3100:3100"

  grafana:
    image: grafana/grafana:11.6.0
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:?Define GRAFANA_ADMIN_PASSWORD en .env}
      GF_USERS_ALLOW_SIGN_UP: "false"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro
    ports:
      - "127.0.0.1:3000:3000"
    depends_on:
      - prometheus
      - loki

volumes:
  prometheus_data:
  alertmanager_data:
  loki_data:
  grafana_data:
```

## Credencial de Grafana

La contraseña del administrador se genera en el momento y se guarda en `.env`, fuera del repositorio. `umask 077` hace que el archivo quede con permisos `600`.

Ejecutar:

```sh
umask 077
printf 'GRAFANA_ADMIN_PASSWORD=%s\n' \
  "$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')" > .env
```

Compose lee el `.env` de esa carpeta automáticamente. Si la variable faltara, `:?` hace fallar el arranque en vez de usar una contraseña vacía.

## Validar y levantar

Ejecutar:

```sh
docker compose config -q
```

No debe imprimir nada si la sintaxis es correcta. Después:

```sh
docker compose pull
docker compose up -d
```

## Acceso mediante túnel SSH

Como los puertos solo escuchan en `127.0.0.1`, se habilita el reenvío local de puertos en SSH. El comando respalda la configuración, ajusta o agrega la directiva, valida la sintaxis y recién entonces reinicia el servicio.

Ejecutar:

```sh
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak &&
if grep -qE '^[[:space:]]*AllowTcpForwarding[[:space:]]' /etc/ssh/sshd_config; then
  sed -i 's/^[[:space:]]*AllowTcpForwarding[[:space:]].*/AllowTcpForwarding local/' /etc/ssh/sshd_config
else
  echo 'AllowTcpForwarding local' >> /etc/ssh/sshd_config
fi &&
sshd -t && rc-service sshd restart
```

Con `local` solo se permiten túneles iniciados por el cliente. Desde el equipo del administrador:

```sh
ssh -L 3000:127.0.0.1:3000 <usuario>@10.33.199.52
```

Luego se abre `http://localhost:3000` en el navegador. Para revertir: `cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config` y reiniciar `sshd`.

## Verificación

Ejecutar:

```sh
docker compose ps
curl -s http://127.0.0.1:9090/-/ready
curl -s http://127.0.0.1:9093/-/healthy
curl -s http://127.0.0.1:3100/ready
curl -s http://127.0.0.1:3000/api/health
sshd -T | grep -i allowtcpforwarding
```

Los cuatro servicios deben figurar como `running`, cada comprobación debe responder sin error y `sshd -T` debe mostrar `allowtcpforwarding local`. En Prometheus, el job `prometheus` debe aparecer en `UP`:

```sh
curl -s http://127.0.0.1:9090/api/v1/targets | head -c 300
```
