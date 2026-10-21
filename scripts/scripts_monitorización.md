# Monitorización del nodo perimetral: Nginx y BIND9

Se habilita la exposición de métricas de los servicios del nodo perimetral (`tas-06-jose`, 10.33.199.49) para que Prometheus y Grafana, en `tas-06-monitor` (10.33.199.52), puedan monitorearlos.

| Servicio | Origen de los datos | Exporter | Puerto | Job de Prometheus |
|---|---|---|---|---|
| Nginx | `127.0.0.1:8081/nginx_status` | `nginx-prometheus-exporter` 1.3.0 | 9113 | `nginx-lb` |
| BIND9 | `127.0.0.1:8053` (canal de estadísticas) | No configurado aún | — | — |

## Nginx

### Sitio de estadísticas

Se habilita un sitio exclusivo para monitoreo, accesible solo desde el propio nodo.

Editar:

```sh
vim /etc/nginx/sites-available/stub_status
```

Contenido del archivo nuevo:

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

### Habilitar el sitio

Ejecutar:

```sh
sudo ln -s /etc/nginx/sites-available/stub_status /etc/nginx/sites-enabled/stub_status
sudo nginx -t && sudo nginx -s reload
```

### Servicio exportador

Se crea un contenedor con el exporter en el nodo perimetral. Usa `network_mode: host` para alcanzar `127.0.0.1:8081`.

```yaml
services:
  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:1.3.0
    network_mode: host
    command:
      - --nginx.scrape-uri=http://127.0.0.1:8081/nginx_status
      - --web.listen-address=:9113
```

Levantar:

```sh
docker compose up -d
```

### Job en Prometheus

En la VM del monitor, agregar dentro de `scrape_configs:` en `/opt/nodo-sur-monitoring/prometheus/prometheus.yml`:

```yaml
  - job_name: 'nginx-lb'
    static_configs:
      - targets: ['10.33.199.49:9113']
```

Reiniciar Prometheus para que lea el job:

```sh
cd /opt/nodo-sur-monitoring
docker compose restart prometheus
```

### Verificación

En el nodo perimetral:

```sh
curl -s http://127.0.0.1:8081/nginx_status
curl -s http://127.0.0.1:9113/metrics | grep nginx_up
sudo ss -tlnp | grep -E '8081|9113'
```

`nginx_status` debe mostrar `Active connections` y `nginx_up` debe valer `1`.

Desde la VM del monitor:

```sh
curl -s http://10.33.199.49:9113/metrics | head
```

En la interfaz de Prometheus (Status → Targets) el job `nginx-lb` debe aparecer en estado `UP`.

## BIND9

### Canal de estadísticas

Editar:

```sh
sudo nano /etc/bind/named.conf.options
```

Contenido aplicado:

```sh
options {
        directory "/var/cache/bind";

        allow-query { any; };
        allow-recursion { any; };
        allow-query-cache { any; };

        recursion yes;

        listen-on port 53 { any; };

        listen-on-v6 { any; };

        forwarders {
                8.8.8.8;
                1.1.1.1;
        };

        dnssec-validation auto;
};

statistics-channels {
    inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
};
```

El bloque `statistics-channels` expone las estadísticas solo en la interfaz local. Ese canal no tiene autenticación, por lo que no debe publicarse hacia la red.

### Validación de sintaxis

Ejecutar:

```sh
sudo named-checkconf
```

Si no imprime nada, la sintaxis es correcta.

### Recarga de la configuración

Ejecutar:

```sh
sudo rndc reconfig
```

### Verificación del canal de estadísticas

Ejecutar:

```sh
sudo ss -tlnp | grep 8053
curl -s http://127.0.0.1:8053/json/v1 | head -c 300
```

Debe aparecer `127.0.0.1:8053` en escucha y una respuesta JSON. Si no responde, reiniciar el servicio `named`, porque algunos cambios de configuración no se aplican con `reconfig`.

