# Configurar Grafana para WordPress

## 1. Agregar el servicio al compose general

Agregar el siguiente servicio al `compose.yaml`:

```yaml
  blackbox-exporter:
    image: prom/blackbox-exporter
    dns:
      - 10.33.199.49
    ports:
      - "9115:9115"
```

## 2. Agregar jobs a la configuración de Prometheus

Agregar los siguientes jobs en `prometheus/prometheus.yml`:

```yaml
  - job_name: 'blackbox-wordpress'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - http://tas-06.arpa
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115

  - job_name: 'apache-wordpress'
    static_configs:
      - targets: ['10.33.199.50:9117']
        labels:
          replica: 'cms-2'
          cms_ip: '10.33.199.50'
      - targets: ['10.33.199.51:9117']
        labels:
          replica: 'cms-1'
          cms_ip: '10.33.199.51'
```

## 3. Levantar el exporter y recrear Prometheus

```sh
docker compose up -d blackbox-exporter
docker compose up -d --force-recreate prometheus
```
