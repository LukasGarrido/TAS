# Configurar Grafana para Nginx

## 1. Habilitar un sitio en Nginx para monitoreo

Crear el archivo del sitio:

```sh
vim /etc/nginx/sites-available/stub_status
```

Dentro del archivo nuevo, pegar la configuración del server:

```nginx
server {
    listen 127.0.0.1:8081;

    location /nginx_status {
        stub_status on;
        allow 127.0.0.1;
        deny all;
    }
}
```

Habilitar el sitio, validar la configuración y recargar Nginx:

```sh
sudo ln -s /etc/nginx/sites-available/stub_status /etc/nginx/sites-enabled/stub_status
sudo nginx -t && sudo nginx -s reload
```

## 2. Crear el servicio exportador en la VM de Nginx

```yaml
services:
  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:1.3.0
    network_mode: host
    command:
      - --nginx.scrape-uri=http://127.0.0.1:8081/nginx_status
      - --web.listen-address=:9113
```

## 3. Agregar el job en Prometheus

Agregar el siguiente job en `/opt/nodo-sur-monitoring/prometheus/prometheus.yml`:

```yaml
  - job_name: 'nginx-lb'
    static_configs:
      - targets: ['10.33.199.49:9113']
```
