# Configurar VM de Monitoreo

## Características de la máquina virtual

| Recurso | Valor |
|---|---|
| SO | Alpine 3.24.2 |
| Disco | 191.6 GB |
| RAM | 4 GB |
| SWAP | 4 GB |
| CPU | 2 núcleos |
| IP pública | 10.33.195.245 (se quitará luego de la configuración) |
| IP privada | 10.33.199.52 |
| Docker | v29.8.1 |
| Docker Compose | v5.1.4 |

## 1. Crear la estructura de directorios

```sh
mkdir -p /opt/nodo-sur-monitoring/prometheus/rules
mkdir -p /opt/nodo-sur-monitoring/alertmanager
mkdir -p /opt/nodo-sur-monitoring/loki
mkdir -p /opt/nodo-sur-monitoring/grafana/provisioning/datasources

cd /opt/nodo-sur-monitoring
```

## 2. Configuración de Prometheus

Archivo `prometheus/prometheus.yml`:

```sh
cat > prometheus/prometheus.yml <<'EOF'
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
EOF
```

## 3. Reglas de alertas

Archivo `prometheus/rules/alerts.yml`:

```sh
cat > prometheus/rules/alerts.yml <<'EOF'
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
EOF
```

## 4. Configuración de Alertmanager

Archivo `alertmanager/alertmanager.yml`:

```sh
cat > alertmanager/alertmanager.yml <<'EOF'
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
EOF
```

## 5. Configuración de Loki

Archivo `loki/loki.yml`:

```sh
cat > loki/loki.yml <<'EOF'
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
EOF
```

## 6. Docker Compose

Archivo `compose.yaml`:

```sh
cat > compose.yaml <<'EOF'
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
EOF
```

## 7. Generar la contraseña de Grafana

Se genera una contraseña aleatoria y se guarda en `.env` con permisos restringidos:

```sh
umask 077
printf 'GRAFANA_ADMIN_PASSWORD=%s\n' \
  "$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')" > .env
```

## 8. Validar y levantar los servicios

Validar la sintaxis del compose:

```sh
docker compose config -q
```

Descargar las imágenes e iniciar los contenedores:

```sh
docker compose pull
docker compose up -d
```

## 9. Habilitar reenvío de puertos local en SSH

Como los servicios solo escuchan en `127.0.0.1`, se habilita `AllowTcpForwarding local` en SSH para poder acceder mediante túnel. Se respalda el archivo, se aplica el cambio, se valida la configuración y se reinicia el servicio:

```sh
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak &&
if grep -qE '^[[:space:]]*AllowTcpForwarding[[:space:]]' /etc/ssh/sshd_config; then
  sed -i 's/^[[:space:]]*AllowTcpForwarding[[:space:]].*/AllowTcpForwarding local/' /etc/ssh/sshd_config
else
  echo 'AllowTcpForwarding local' >> /etc/ssh/sshd_config
fi &&
sshd -t && rc-service sshd restart
```
