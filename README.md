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
├── G6_tas_NodoSur.md
├── index.md
├── README.md
├── assets/
│   └── universidad-tecnica-federico-santa-maria-seeklogo.png
├── bitacora/
│   ├── bitacora-general.md
│   ├── entorno-de-trabajo.md
│   ├── Infraestructura.md
│   └── uso-ia.md
├── decisiones/
│   ├── ADR-001 Selección de CMS.md
│   └── ADR-002 Nginx como balanceador en vez de HAProxy.md
├── docs/
│   ├── caso-de-negocio.md
│   ├── G6_tas_NodoSur.pdf
│   ├── plan-implementacion.md
│   ├── Proyecto_Integrador_TAS_2026_Nodo_Sur.pdf
│   ├── reproduccion-entorno.md
│   ├── riesgos.md
│   └── entrega-1/
│       ├── Diagrama de despliegue.md
│       ├── E1_grupo06_informe.docx
│       └── E1_grupo06_informe.pdf
└── scripts/
    ├── respaldos-mariadb.md
    ├── scripts_DataBase-Grafana.md
    ├── scripts_docker.md
    ├── scripts_firewall_ufw.md
    ├── scripts_monitorización.md
    ├── scripts_Servidor_NFS.md
    ├── scripts_VM-Monitoreo.md
    ├── scripts_wordpress.md
    └── tarjeta_red_cms1.md
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

## 8. Referencias y Documentación Técnica

Para desplegar, administrar o auditar la plataforma, consulte los manuales específicos en la carpeta `scripts/`:
- `scripts/scripts_docker.md` — Instalación y despliegue de contenedores.
- `scripts/scripts_Servidor_NFS.md` — Configuración del servidor y volúmenes NFS.
- `scripts/scripts_firewall_ufw.md` — Endpoints, UFW y reglas `DOCKER-USER`.
- `scripts/scripts_monitorización.md` — Pila Grafana, Prometheus, Loki y Alertmanager.
- `scripts/respaldos-mariadb.md` — Arquitectura y operación de respaldos automáticos.
- `decisiones/` — Registros de Decisiones de Arquitectura (ADR-001 y ADR-002).

---

## 9. Licencia / Uso Académico

Proyecto desarrollado con fines académicos para la asignatura **EIN-090B · Taller de Administración de Sistemas**, Universidad Técnica Federico Santa María (Sede Concepción).
