# Configurar Grafana para las máquinas (node_exporter)

Los exporters actuales miden **servicios** (Nginx, Apache, MariaDB). Para medir el **estado de cada VM** (encendida, CPU, RAM, disco, red) se instala `node_exporter` en las cinco máquinas, en el puerto 9100.

| VM | IP | Sistema | Etiqueta `host` |
|---|---|---|---|
| DNS / Nginx | 10.33.199.49 | Ubuntu 24.04 | `dns` |
| WordPress 1 | 10.33.199.51 | Alpine | `cms-1` |
| WordPress 2 | 10.33.199.50 | Alpine | `cms-2` |
| Base de datos | 10.33.199.53 | Alpine | `db` |
| Monitor | 10.33.199.52 | Alpine | `monitor` |

## Estado (27/11/2026)

| Elemento | Estado |
|---|---|
| `node_exporter` en las cinco VMs | Aplicado (Alpine: 1.11.1; Ubuntu: 1.7.0) |
| Job `node` en Prometheus | Aplicado: los cinco targets responden `up = 1` |
| Dashboard **Nodo Sur - Máquinas** | Importado en Grafana |
| Reglas de alerta `maquinas.yml` | **Pendiente** |
| Prueba de caída | **Pendiente** |

## 1. Instalar node_exporter

Se instala como paquete del sistema (no como contenedor), para que lea las métricas reales del host.

### VMs Alpine (`cms-1`, `cms-2`, `db`, `monitor`), como root

```sh
apk add prometheus-node-exporter
rc-update add node-exporter default
rc-service node-exporter start
```

Si `apk` no encuentra el paquete, habilitar el repositorio `community` en `/etc/apk/repositories` y ejecutar `apk update`.

### VM Ubuntu (`dns`)

```sh
sudo apt update
sudo apt install -y prometheus-node-exporter
sudo systemctl enable --now prometheus-node-exporter
```

### Comprobar en cada VM

```sh
wget -qO- http://127.0.0.1:9100/metrics | grep '^node_uname_info'
```

## 2. Restringir el acceso al puerto 9100

Revisar primero el firewall con `ufw status verbose`. Si está `inactive`, **no activarlo** sin definir antes las reglas de SSH y de los demás servicios.

### `cms-1`, `cms-2` y `db`

Permitir solo al monitor:

```sh
ufw allow from 10.33.199.52 to any port 9100 proto tcp
```

### `monitor`

Prometheus corre en un contenedor, por lo que llega desde la red de Docker:

```sh
ufw allow from 172.16.0.0/12 to any port 9100 proto tcp
```

### `dns`

En esta VM UFW está `inactive` y es el nodo con acceso público, por lo que el exporter se configura para escuchar solo en la IP privada. En `/etc/default/prometheus-node-exporter` (editar con `sudo vim`):

```sh
ARGS="--web.listen-address=10.33.199.49:9100"
```

Reiniciar y comprobar. La salida debe mostrar `10.33.199.49:9100`:

```sh
sudo systemctl restart prometheus-node-exporter
sudo ss -tlnp | grep 9100
```

### Prueba de conexión

Desde `monitor`:

```sh
for ip in 49 50 51 53; do
  echo -n "10.33.199.$ip: "
  wget -T 3 -qO- http://10.33.199.$ip:9100/metrics >/dev/null && echo OK || echo FALLA
done
```

El propio monitor se prueba desde el contenedor de Prometheus:

```sh
cd /opt/nodo-sur-monitoring
docker compose exec prometheus wget -T 3 -qO- http://10.33.199.52:9100/metrics | grep '^node_uname_info'
```

## 3. Agregar el job en Prometheus

Como root en `monitor`, respaldar la configuración:

```sh
cd /opt/nodo-sur-monitoring
cp prometheus/prometheus.yml prometheus/prometheus.yml.bak
```

En `prometheus/prometheus.yml`, dentro de `scrape_configs:`:

```yaml
  - job_name: 'node'
    static_configs:
      - targets: ['10.33.199.49:9100']
        labels:
          host: 'dns'
      - targets: ['10.33.199.51:9100']
        labels:
          host: 'cms-1'
      - targets: ['10.33.199.50:9100']
        labels:
          host: 'cms-2'
      - targets: ['10.33.199.53:9100']
        labels:
          host: 'db'
      - targets: ['10.33.199.52:9100']
        labels:
          host: 'monitor'
```

## 4. Validar, reiniciar y verificar

```sh
cd /opt/nodo-sur-monitoring
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

Solo si responde `SUCCESS`:

```sh
docker compose restart prometheus
```

Esperar al menos un intervalo de recolección (30 s) y consultar:

```sh
docker compose exec prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=up%7Bjob%3D%22node%22%7D'
```

Deben aparecer `dns`, `cms-1`, `cms-2`, `db` y `monitor`, todos con valor `"1"`. También se puede revisar en <http://localhost:9090/targets> (por túnel SSH).

## 5. Importar el dashboard en Grafana

1. Entrar a <http://grafana.tas-06.arpa>.
2. Dashboards → New → Import.
3. Subir `configurations/grafana-maquinas.json`.
4. Elegir la fuente de datos Prometheus y confirmar.

El dashboard **Nodo Sur - Máquinas** (`nodo-sur-maquinas`) muestra:

| Panel | Qué indica |
|---|---|
| Estado de las máquinas | UP/DOWN por VM |
| Tiempo encendida | Tiempo desde el último arranque |
| CPU usada | Porcentaje de CPU ocupada |
| Memoria usada | Porcentaje de RAM no disponible |
| Disco raíz usado | Porcentaje ocupado de `/` |
| Carga del sistema | Carga promedio de 1 minuto |
| Red recibida / enviada | Tráfico por VM, sin interfaces de Docker |

## 6. Agregar las alertas (pendiente de aplicar)

En `/opt/nodo-sur-monitoring/prometheus/rules/` crear el archivo `maquinas.yml`:

```sh
cat > /opt/nodo-sur-monitoring/prometheus/rules/maquinas.yml <<'EOF'
groups:
  - name: maquinas
    rules:
      - alert: MaquinaCaida
        expr: up{job="node"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "La VM {{ $labels.host }} no responde"
          description: "Prometheus no puede consultar node_exporter en {{ $labels.instance }}."

      - alert: CpuAlta
        expr: 100 * (1 - avg by (host) (rate(node_cpu_seconds_total{job="node", mode="idle"}[5m]))) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU sobre 85% en {{ $labels.host }}"

      - alert: MemoriaAlta
        expr: 100 * (1 - node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes{job="node"}) > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Memoria sobre 90% en {{ $labels.host }}"

      - alert: DiscoLleno
        expr: 100 * (1 - node_filesystem_avail_bytes{job="node", mountpoint="/"} / node_filesystem_size_bytes{job="node", mountpoint="/"}) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disco raíz sobre 85% en {{ $labels.host }}"
EOF
```

Validar y reiniciar como en el paso 4. La validación debe informar `4 rules found` para `maquinas.yml`.

## 7. Prueba de caída (pendiente de ejecutar)

Detener el exporter en una VM Alpine, por ejemplo `cms-2`:

```sh
rc-service node-exporter stop
```

En un par de minutos `cms-2` debe aparecer en `DOWN` y la alerta `MaquinaCaida` en `firing`. Volver a levantarlo:

```sh
rc-service node-exporter start
```

> `DOWN` significa que Prometheus no logra consultar el exporter: la VM puede estar apagada, sin red, con el puerto bloqueado o con el exporter detenido.

## 8. Problemas encontrados

| Síntoma | Causa | Solución |
|---|---|---|
| `wget: download timed out` desde el monitor hacia `cms-2` | UFW no permitía el puerto 9100 | Agregar la regla desde `10.33.199.52` |
| `Permission denied` al instalar o editar | Sesión sin privilegios de root | Usar `su` |
| `no configuration file provided` o `nonexistent directory` | `su` ejecutado fuera de la carpeta del proyecto | `cd /opt/nodo-sur-monitoring` |
| Una VM nueva no aparece en la consulta justo tras reiniciar | Prometheus aún no la había consultado | Esperar 30 s y repetir |
| Una VM está en Prometheus pero no en el dashboard | Lista del filtro **Máquina** sin actualizar | Recargar la página y elegir **All** |
