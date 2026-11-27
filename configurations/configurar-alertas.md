# Configurar alertas hacia Discord

Cadena de aviso: **reglas → Prometheus → Alertmanager → Discord**.

## Estado (27/11/2026)

| Elemento | Estado |
|---|---|
| Alertmanager con receptor Discord | Aplicado y validado con `amtool` |
| Reglas cargadas en Prometheus | 17: `alerts.yml` (1), `maquinas.yml` (4), `servicios.yml` (12) |
| Prueba de caída (`node_exporter` detenido en `cms-2`) | La alerta `MaquinaCaida` llegó a Discord |
| Aviso `RESOLVED` | **Pendiente de confirmar** |
| Prueba de las reglas de servicios | **Pendiente** |

## 1. Crear el webhook en Discord

En el canal de alertas: **Editar canal → Integraciones → Webhooks → Nuevo webhook → Copiar URL**.

> La URL es un secreto: cualquiera que la tenga puede publicar en el canal. No se guarda en el repositorio ni se comparte en chats. Si se expone, eliminar el webhook y crear otro.

## 2. Configurar Alertmanager

Como root en `monitor`:

```sh
cd /opt/nodo-sur-monitoring
cp alertmanager/alertmanager.yml alertmanager/alertmanager.yml.bak
```

Ejecutar solo este comando, pegar la URL y pulsar Enter (no se muestra en pantalla):

```sh
read -r -s WEBHOOK
```

Crear la configuración:

```sh
cat > alertmanager/alertmanager.yml <<EOF
global:
  resolve_timeout: 5m

route:
  receiver: discord
  group_by: [alertname]
  group_wait: 10s
  group_interval: 1m
  repeat_interval: 4h

receivers:
  - name: discord
    discord_configs:
      - webhook_url: '$WEBHOOK'
        send_resolved: true
        title: '{{ .Status | toUpper }}: {{ .CommonLabels.alertname }}'
        message: '{{ range .Alerts }}- {{ .Annotations.summary }} ({{ .Labels.severity }}){{ "\n" }}{{ end }}'
EOF
```

Proteger el archivo (el contenedor lo lee con el usuario `65534`), reiniciar y validar:

```sh
chown 65534:65534 alertmanager/alertmanager.yml
chmod 600 alertmanager/alertmanager.yml
unset WEBHOOK
docker compose restart alertmanager
docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```

## 3. Enviar una alerta de prueba

```sh
docker compose exec alertmanager amtool alert add PruebaDiscord severity=warning summary=prueba --alertmanager.url=http://localhost:9093
```

## 4. Cargar las reglas

Las reglas están versionadas en [`prometheus-rules/`](prometheus-rules/). Desde el equipo personal, en la raíz del repositorio (PowerShell):

```powershell
scp -o ProxyJump=<usuario_bastion>@10.33.195.184 configurations/prometheus-rules/*.yml <usuario_monitor>@10.33.199.52:/tmp/
```

Como root en `monitor`:

```sh
cd /opt/nodo-sur-monitoring
cp /tmp/maquinas.yml /tmp/servicios.yml prometheus/rules/
chmod 644 prometheus/rules/*.yml
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

Solo si todo responde `SUCCESS`:

```sh
docker compose restart prometheus
```

## 5. Reglas

### Máquinas ([`maquinas.yml`](prometheus-rules/maquinas.yml))

| Alerta | Condición | Espera | Severidad |
|---|---|---|---|
| `MaquinaCaida` | No responde `node_exporter` | 1 min | critical |
| `CpuAlta` | CPU > 85 % | 5 min | warning |
| `MemoriaAlta` | Memoria > 90 % | 5 min | warning |
| `DiscoLleno` | Disco raíz > 85 % | 5 min | warning |

### Servicios ([`servicios.yml`](prometheus-rules/servicios.yml))

| Alerta | Condición | Espera | Severidad |
|---|---|---|---|
| `ExporterCaido` | Prometheus no puede consultar un exporter de servicio | 1 min | critical |
| `SitioCaido` | La sonda HTTP falla | 1 min | critical |
| `SitioLento` | La respuesta tarda más de 3 s | 5 min | warning |
| `CertificadoPorVencer` | El certificado vence en menos de 14 días | 1 h | warning |
| `NginxCaido` | `nginx_up = 0` | 1 min | critical |
| `ApacheCaido` | `apache_up = 0` en una réplica | 1 min | warning |
| `SinReplicasWeb` | Ninguna réplica web disponible | 1 min | critical |
| `ApacheSaturado` | Más del 90 % de workers ocupados | 5 min | warning |
| `MariaDBCaida` | `mysql_up = 0` | 1 min | critical |
| `ConexionesMariaDBAltas` | Más del 80 % de las conexiones en uso | 5 min | warning |
| `ConsultasLentas` | Más de 10 consultas lentas en 5 min | 5 min | warning |
| `DNSCaido` | `bind_up = 0` | 1 min | critical |

`alerts.yml` conserva la regla `PrometheusTargetDown`. Ninguna alerta puede avisar si cae la propia VM `monitor`, porque allí se ejecutan Prometheus y Alertmanager.

## 6. Probar una caída

En `cms-2`, como root:

```sh
rc-service node-exporter stop
```

La alerta pasa por `pending` (detectada, esperando 1 minuto) y luego `firing`, momento en que se envía a Discord. Restaurar:

```sh
rc-service node-exporter start
```

Debe llegar el aviso `RESOLVED`.

## 7. Diagnóstico

Ejecutar en `monitor`, desde `/opt/nodo-sur-monitoring`:

| Pregunta | Comando |
|---|---|
| ¿Están cargadas las reglas? | `docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml` |
| ¿Prometheus disparó la alerta? | `docker compose exec prometheus wget -qO- http://localhost:9090/api/v1/alerts` |
| ¿Llegó a Alertmanager? | `docker compose exec alertmanager amtool alert query --alertmanager.url=http://localhost:9093` |
| ¿Falló el envío? | `docker compose logs --since 10m alertmanager` |

Antes de compartir registros, borrar cualquier URL de Discord.

### Problema encontrado

No llegaba ninguna alerta de máquinas ni de servicios porque en el monitor solo existía `alerts.yml`. Se copiaron `maquinas.yml` y `servicios.yml` y se reinició Prometheus.
