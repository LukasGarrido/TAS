<div align="center">

<img src="assets/universidad-tecnica-federico-santa-maria-seeklogo.png" alt="Universidad Técnica Federico Santa María" width="220" />

**Departamento de Electrónica e Informática**
**USM Sede Concepción**

<br/>

# NODO SUR — Plataforma digital resiliente, observable y operable

**Asignatura:** EIN-090B · Taller de Administración de Sistemas (TAS)  
**Grupo:** 06 (`tas-06`)  
**Integrantes:** Josecarlos Vidal · Octavio Valencia · Lukas Garrido  
**Versión:** v4.0 (23 de noviembre de 2026)  
**Repositorio:** [NodoSur](https://github.com/LukasGarrido/TAS)

</div>

---

## 1. Descripción del proyecto

Nodo Sur agrupa a pequeñas marcas, talleres creativos, productores y operadores de experiencias que operaban mediante redes sociales y formularios aislados, con riesgos de pérdida de datos y caídas prolongadas. Este proyecto documenta el diseño, implementación y operación de una plataforma centralizada bajo el dominio interno único `tas-06.arpa`.

Como proveedores de infraestructura, el equipo ha justificado cada decisión técnica con requerimientos medibles, pruebas empíricas, métricas, logs centralizados y procedimientos de recuperación reproducibles.

---

## 2. Estado del proyecto

| Entrega | Hito | Fecha | Estado |
|---|---|---|---|
| 1 | Informe de requerimientos y arquitectura | 05/09/2026 | [Completado] |
| 2 | Plataforma base y CMS funcional | 05/09/2026 | [Completado] |
| 3 | Publicación resiliente y seguridad | 23/09/2026 | [Completado] |
| 4 | Observabilidad y continuidad operacional | 23/11/2026 | [Completado] |
| 5 | Incidente, auditoría y defensa final | 30/11/2026 | [Completado] |

---

## 3. Estructura del repositorio

```
nodo-sur/
├── .gitignore
├── index.md
├── README.md
├── assets/
│   └── universidad-tecnica-federico-santa-maria-seeklogo.png
├── binnacle/
│   ├── Infraestructura.md
│   ├── bitacora-general.md
│   ├── entorno-de-trabajo.md
│   └── uso-ia.md
├── configurations/
│   ├── configurar-grafana-maquinas.md
│   ├── grafana-maquinas.json
│   ├── configurar-grafana-mariadb.md
│   ├── configurar-grafana-nginx.md
│   ├── configurar-grafana-wordpress.md
│   ├── configurar-vm-monitoreo.md
│   ├── grafana.json
│   ├── respaldos-mariadb.md
│   ├── scripts_DataBase-Grafana.md
│   ├── scripts_docker.md
│   ├── scripts_firewall_ufw.md
│   ├── scripts_Servidor_NFS.md
│   ├── scripts_wordpress.md
│   └── tarjeta_red_cms1.md
├── decisions/
│   ├── ADR-001 Selección de CMS.md
│   └── ADR-002 Nginx como balanceador en vez de HAProxy.md
└── docs/
    ├── caso-de-negocio.md
    ├── plan-implementacion.md
    ├── reproduccion-entorno.md
    ├── riesgos.md
    ├── E01/
    │   └── Diagrama de despliegue.md
    ├── E05/
    │   └── G6_tas_NodoSur.md
    └── pdf/
        ├── E1_grupo06_informe.pdf
        ├── G6_tas_NodoSur.pdf
        └── Proyecto_Integrador_TAS_2026_Nodo_Sur.pdf
```

---

## 4. Arquitectura y Componentes Principales

La plataforma opera en la subred `10.33.199.48/29` y se compone de cinco máquinas virtuales con roles segregados:

| Host (VM) | Rol y servicios | IP privada | SO / Versión principal |
|---|---|---|---|
| `dns` | Nodo perimetral: DNS (BIND9, :53), Nginx (proxy inverso, balanceador pasivo round-robin, TLS, :80/:443), bastión SSH, copia externa de respaldos (`pull-db.sh`), `nginx-exporter` (:9113) | `10.33.199.49` | Ubuntu 24.04 LTS |
| `cms-1` | Backend WordPress 1 (`wordpress:php8.3-apache`, :8080), `apache-exporter` (:9117) | `10.33.199.51` | Alpine Linux, Docker |
| `cms-2` | Backend WordPress 2 (`wordpress:php8.3-apache`, :8080), `apache-exporter` (:9117) | `10.33.199.50` | Alpine Linux, Docker |
| `db` | Base de datos MariaDB 11 (:3306), servidor NFS compartido (`/srv/nfs/wordpress`, :2049) | `10.33.199.53` | Alpine Linux, Docker |
| `monitor` | Observabilidad centralizada: Prometheus (v3.5.0), Alertmanager (v0.28.1), Loki (v3.5.0), Grafana (v11.6.0), `mysqld-exporter` (:9104) | `10.33.199.52` | Alpine Linux 3.24.2, Docker v29.8.1 |

---

## 5. Requerimientos y Cumplimiento

| ID | Requerimiento | Tipo | Criterio de aceptación / Estado |
|---|---|---|---|
| RF-01 | CMS funcional (catálogo, pedidos, reservas, contenidos) | F | [Implementado] WordPress + WooCommerce operativo bajo dominio único. |
| RNF-01 | Capa web con al menos dos nodos | NF | [Implementado] Dos backends con balanceador Nginx (conmutación en ≤ 30 s). |
| RNF-02 | Base de datos independiente y no expuesta | NF | [Implementado] MariaDB en VM dedicada; puerto 3306 restringido por UFW y `DOCKER-USER`. |
| RNF-03 | Persistencia y coherencia del estado compartido | NF | [Implementado] Servidor NFS en `/srv/nfs/wordpress` con volúmenes Docker NFS v4. |
| RNF-04 | Administración remota segura y nominativa | NF | [Parcial] SSH por clave pública y salto por bastión; llave dedicada `id_pull` para respaldos. |
| RNF-05 | Detección de falla crítica en tiempo acotado | NF | [Parcial] Stack Prometheus/Alertmanager configurado; pendiente definir destino de alertas. |
| RNF-06 | Continuidad mediante respaldos verificados | NF | [Implementado] Dump automático cada 2 días con gzip y SHA-256 en `db`, con copia externa diaria en nodo perimetral (retención 30 días). |
| RNF-07 | Dominio único con HTTPS válido | NF | [Implementado] `https://tas-06.arpa` con Nginx TLS y redirección HTTP. |
| RNF-08 | Trazabilidad y hora consistente | NF | [Parcial] NTP y Loki configurados; diferencias de zona horaria entre VMs y contenedores documentadas. |

---

## 6. Seguridad y Red (`DOCKER-USER`)

- **Segmentación de red:** UFW activo en las VMs con denegación por defecto y acceso SSH limitado al bastión.
- **Protección de contenedores (`DOCKER-USER`):** Dado que Docker manipula iptables directamente, las reglas para restringir el acceso al puerto 3306 (MariaDB) y 8080 (backends) se aplican mediante la cadena `DOCKER-USER` y se persisten al reinicio a través de `/etc/local.d/firewall.start`.
- **Credenciales y secretos:** Archivos `.env` y `.my.cnf` con permisos `600`, fuera del control de versiones.

---

## 7. Continuidad Operacional y Respaldo (MariaDB)

El sistema de respaldo implementa una estrategia de dos etapas que cumple con la retención de 30 días y la copia fuera del host de origen:
1. **Etapa 1 (Dump en VM `db`):** Script `/usr/local/bin/backup-db.sh` ejecutado por cron a las 02:30 (días pares) mediante `mariadb-dump` con `--single-transaction`, compresión gzip, verificación con `gzip -t` y checksum SHA-256.
2. **Etapa 2 (Copia externa en nodo perimetral):** Script `~/pull-db.sh` ejecutado diariamente a las 07:00 UTC, que se conecta mediante SSH con una llave ed25519 dedicada y restringida (`from`, `restrict`), verifica el SHA-256 y mantiene sincronizada la copia externa.

---

## 8. Rutas de Acceso

### 8.1 Aplicaciones

| Servicio | URL |
|---|---|
| CMS (WordPress) | <http://tas-06.arpa/> |
| Grafana: dashboard `nodo-sur-maquinas` (estado de las VMs) | <http://grafana.tas-06.arpa/d/nodo-sur-maquinas/nodo-sur-maquinas?orgId=1&from=now-6h&to=now&timezone=browser&var-host=$__all&refresh=5s> |
| Grafana: dashboard `nodo-sur-overview` | <http://grafana.tas-06.arpa/d/nodo-sur-overview/60c97ed?orgId=1&from=now-6h&to=now&timezone=browser&var-instance=mysqld-exporter:9104&var-replica=$__all&refresh=5s> |

### 8.2 Prometheus (por túnel SSH)

Prometheus escucha solo en `127.0.0.1:9090` de la VM `monitor`. Abrir el túnel desde el equipo personal, reemplazando `<usuario_bastion>` y `<usuario_monitor>`, y mantener la sesión abierta:

```sh
ssh -J <usuario_bastion>@10.33.195.184 -L 9090:127.0.0.1:9090 <usuario_monitor>@10.33.199.52
```

| Endpoint | URL |
|---|---|
| Estado de los targets | <http://localhost:9090/targets> |
| Targets en JSON | <http://localhost:9090/api/v1/targets> |
| Configuración cargada | <http://localhost:9090/config> |

### 8.3 Targets que consulta Prometheus

Estas direcciones pertenecen a la red interna; se definen en `/opt/nodo-sur-monitoring/prometheus/prometheus.yml`.

| Job | Target | Qué mide |
|---|---|---|
| `prometheus` | `http://prometheus:9090/metrics` | El propio Prometheus |
| `nginx-lb` | `http://10.33.199.49:9113/metrics` | Nginx (balanceador) |
| `apache-wordpress` | `http://10.33.199.51:9117/metrics` | Apache en `cms-1` |
| `apache-wordpress` | `http://10.33.199.50:9117/metrics` | Apache en `cms-2` |
| `mariadb` | `http://mysqld-exporter:9104/metrics` | MariaDB |
| `blackbox-wordpress` | `http://blackbox-exporter:9115/probe?module=http_2xx&target=http://tas-06.arpa` | Disponibilidad HTTP del CMS |
| `bind9-dns` | `http://10.33.199.49:9119/metrics` | BIND9 (DNS) |
| `node` | `http://10.33.199.49:9100/metrics` | Estado de la VM `dns` |
| `node` | `http://10.33.199.51:9100/metrics` | Estado de la VM `cms-1` |
| `node` | `http://10.33.199.50:9100/metrics` | Estado de la VM `cms-2` |
| `node` | `http://10.33.199.53:9100/metrics` | Estado de la VM `db` |
| `node` | `http://10.33.199.52:9100/metrics` | Estado de la VM `monitor` |

Los nombres `prometheus`, `mysqld-exporter` y `blackbox-exporter` solo se resuelven dentro de la red de Docker Compose de `monitor`.

---

## 9. Referencias y Documentación Técnica

Para desplegar, administrar o auditar la plataforma, consulte los manuales específicos en la carpeta `configurations/`:
- `configurations/scripts_docker.md` — Instalación y despliegue de contenedores.
- `configurations/scripts_Servidor_NFS.md` — Configuración del servidor y volúmenes NFS.
- `configurations/scripts_firewall_ufw.md` — Endpoints, UFW y reglas `DOCKER-USER`.
- `configurations/configurar-vm-monitoreo.md` — Configuración de la VM de monitoreo.
- `configurations/configurar-grafana-maquinas.md` — Monitoreo de las máquinas con `node_exporter`.
- `configurations/scripts_DataBase-Grafana.md` — Integración de Bases de Datos y Grafana.
- `configurations/respaldos-mariadb.md` — Arquitectura y operación de respaldos automáticos.
- `decisions/` — Registros de Decisiones de Arquitectura (ADR-001 y ADR-002).

---

## 10. Licencia / Uso Académico

Proyecto desarrollado con fines académicos para la asignatura **EIN-090B · Taller de Administración de Sistemas**, Universidad Técnica Federico Santa María (Sede Concepción).

---

## Índice de Navegación por Directorios

Documentación, bitácoras, configuraciones y registros de arquitectura del repositorio.

- **[binnacle/](binnacle/)** — Bitácora e infraestructura del proyecto:
  - [`Infraestructura.md`](binnacle/Infraestructura.md)
  - [`bitacora-general.md`](binnacle/bitacora-general.md)
  - [`entorno-de-trabajo.md`](binnacle/entorno-de-trabajo.md)
  - [`uso-ia.md`](binnacle/uso-ia.md)

- **[configurations/](configurations/)** — Scripts y manuales de configuración de servicios:
  - [`configurar-grafana-maquinas.md`](configurations/configurar-grafana-maquinas.md)
  - [`grafana-maquinas.json`](configurations/grafana-maquinas.json)
  - [`configurar-grafana-mariadb.md`](configurations/configurar-grafana-mariadb.md)
  - [`configurar-grafana-nginx.md`](configurations/configurar-grafana-nginx.md)
  - [`configurar-grafana-wordpress.md`](configurations/configurar-grafana-wordpress.md)
  - [`configurar-vm-monitoreo.md`](configurations/configurar-vm-monitoreo.md)
  - [`grafana.json`](configurations/grafana.json)
  - [`respaldos-mariadb.md`](configurations/respaldos-mariadb.md)
  - [`scripts_DataBase-Grafana.md`](configurations/scripts_DataBase-Grafana.md)
  - [`scripts_docker.md`](configurations/scripts_docker.md)
  - [`scripts_firewall_ufw.md`](configurations/scripts_firewall_ufw.md)
  - [`scripts_Servidor_NFS.md`](configurations/scripts_Servidor_NFS.md)
  - [`scripts_wordpress.md`](configurations/scripts_wordpress.md)
  - [`tarjeta_red_cms1.md`](configurations/tarjeta_red_cms1.md)

- **[decisions/](decisions/)** — Registros de Decisiones de Arquitectura (ADR):
  - [`ADR-001 Selección de CMS.md`](decisions/ADR-001%20Selección%20de%20CMS.md)
  - [`ADR-002 Nginx como balanceador en vez de HAProxy.md`](decisions/ADR-002%20Nginx%20como%20balanceador%20en%20vez%20de%20HAProxy.md)

- **[docs/](docs/)** — Documentación general e informes:
  - [`caso-de-negocio.md`](docs/caso-de-negocio.md)
  - [`plan-implementacion.md`](docs/plan-implementacion.md)
  - [`reproduccion-entorno.md`](docs/reproduccion-entorno.md)
  - [`riesgos.md`](docs/riesgos.md)
  - **[docs/E01/](docs/E01/)** — Entrega 1:
    - [`Diagrama de despliegue.md`](docs/E01/Diagrama%20de%20despliegue.md)
  - **[docs/E05/](docs/E05/)** — Entrega 5:
    - [`G6_tas_NodoSur.md`](docs/E05/G6_tas_NodoSur.md)
  - **[docs/pdf/](docs/pdf/)** — Informes oficiales en PDF:
    - [`E1_grupo06_informe.pdf`](docs/pdf/E1_grupo06_informe.pdf)
    - [`G6_tas_NodoSur.pdf`](docs/pdf/G6_tas_NodoSur.pdf)
    - [`Proyecto_Integrador_TAS_2026_Nodo_Sur.pdf`](docs/pdf/Proyecto_Integrador_TAS_2026_Nodo_Sur.pdf)

- **[assets/](assets/)** — Recursos gráficos:
  - [`universidad-tecnica-federico-santa-maria-seeklogo.png`](assets/universidad-tecnica-federico-santa-maria-seeklogo.png)
