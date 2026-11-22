<div align="center">

# UNIVERSIDAD TÉCNICA FEDERICO SANTA MARÍA

**Departamento de electronica y informatica**
**USM sede Concepción**

&nbsp;

## NODO SUR
### Plataforma digital resiliente, observable y operable

&nbsp;

**Informe Proyecto Integrador**
Asignatura: EIN-090B · Taller de Administración de Sistemas (TAS)

&nbsp;

| | |
|---|---|
| **Integrantes** | Josecarlos Vidal <br> Octavio Valencia <br> Lukas Garrido |
| **Equipo** | Grupo 06 (`tas-06`) |
| **Profesor** | Jose Anotino Arellano |
| **Fecha** | 23 de noviembre de 2026 |
| **Versión del documento** | v4.0 |
| **Repositorio** | [NodoSur](https://github.com/LukasGarrido/TAS) |

</div>

<div style="page-break-after: always;"></div>

## Resumen

Nodo Sur es una red regional de pequeñas marcas, talleres creativos, productores y operadores de experiencias que hoy vende, reserva y atiende clientes mediante redes sociales y formularios aislados, con riesgo de pérdida de datos y de indisponibilidad (un formulario caído casi dos horas sin diagnóstico fue el incidente que originó el proyecto). Este informe documenta el diseño, la implementación y la operación de una plataforma centralizada bajo un único dominio interno (`tas-06.arpa`).

La solución usa WordPress + WooCommerce en dos backends contenerizados (`wordpress:php8.3-apache`), un nodo perimetral con BIND9 y Nginx (proxy inverso, balanceador pasivo y bastión SSH), una VM de datos con MariaDB 11 y un servidor NFS compartido para archivos y configuración (`/srv/nfs/wordpress`), y una VM de monitorización con Prometheus (v3.5.0), Alertmanager (v0.28.1), Loki (v3.5.0) y Grafana (v11.6.0). Se definieron ocho requerimientos medibles (RF-01 y RNF-01 a RNF-08), objetivos de servicio (disponibilidad ≥ 99,5 %, detección ≤ 5 min, RTO ≤ 60 min, RPO ≤ 24 h) y un criterio de capacidad N-1.

A la fecha de la entrega final, la arquitectura, el modelo de seguridad, la persistencia NFS y la observabilidad están desplegados y validados según los scripts y bitácoras del repositorio. Se documentan los respaldos automáticos de MariaDB con retención de 30 días, la segmentación mediante UFW y reglas de `DOCKER-USER`, y los puntos únicos de falla identificados (nodo perimetral y VM de datos).

**Palabras clave:** WordPress, Nginx, balanceo, tolerancia a fallas, NFS, MariaDB, Prometheus, Loki, respaldo, RPO/RTO, runbook.

<div style="page-break-after: always;"></div>

## Índice General

1. Introducción
2. Requerimientos y Arquitectura (Entrega 1)
3. Plataforma Base y CMS Funcional (Entrega 2)
4. Publicación Resiliente, Contenedores y Seguridad (Entrega 3)
5. Observabilidad y Continuidad Operacional (Entrega 4)
6. Incidente, Auditoría y Defensa Final (Entrega 5)
7. Análisis Integrado de la Solución
8. Conclusiones y Trabajo Futuro
9. Referencias
10. Anexos

## Glosario y siglas

| Sigla | Significado |
|---|---|
| ADR | Architecture Decision Record |
| CMS | Content Management System |
| FQDN | Fully Qualified Domain Name |
| N-1 | Criterio de diseño: el sistema opera con un nodo menos |
| NFS | Network File System |
| RPO / RTO | Recovery Point / Recovery Time Objective |
| SLO | Service Level Objective |
| SPOF | Single Point of Failure |
| TLS | Transport Layer Security |
| UFW | Uncomplicated Firewall |

<div style="page-break-after: always;"></div>

---

# 1. Introducción

## 1.1 Contexto y motivación

Nodo Sur agrupa a pequeñas marcas, talleres creativos, productores y operadores de experiencias. Hoy gestionan ventas, reservas, inscripciones y atención al cliente por redes sociales, formularios aislados y mensajería. Esto dificulta centralizar la información, aumenta el riesgo de pérdida de datos y genera problemas de disponibilidad.

## 1.2 Planteamiento del problema

Se requiere una plataforma digital **centralizada, administrable y resiliente** que permita a los miembros publicar productos y experiencias, gestionar pedidos y reservas, ofrecer contenidos y comunicarse con sus clientes **desde un único dominio**. Debe soportar picos de demanda por campañas de difusión y mantener el servicio web aun si uno de los nodos web falla.

El equipo actúa como proveedor de infraestructura: cada decisión técnica debe justificarse con requerimientos, pruebas, métricas, logs y procedimientos reproducibles. No basta con instalar un CMS y mostrar su portada.

## 1.3 Objetivos

**Objetivo general.** Diseñar, implementar y operar una plataforma web para Nodo Sur que pueda publicarse, administrarse, diagnosticarse, mantenerse y recuperarse ante fallas.

**Objetivos específicos.**
1. Definir requerimientos medibles y una arquitectura justificada (Entrega 1).
2. Implementar la plataforma base y un CMS funcional con flujo de negocio completo (Entrega 2).
3. Publicar el servicio con dos backends, balanceo, segmentación y secretos controlados (Entrega 3).
4. Implementar monitorización, alertas, logs, respaldos y restauración medida (Entrega 4).
5. Gestionar un incidente no anunciado y auditar la solución (Entrega 5).

## 1.4 Alcance y limitaciones

- **Incluye:** VM Alpine Linux con Docker, WordPress/WooCommerce, MariaDB 11, servidor NFS, BIND9, Nginx, pila completa de monitorización y respaldos automáticos.
- **No incluye:** alta disponibilidad real del nodo perimetral ni de la base de datos, cifrado del tráfico interno entre proxy y backends, ni almacenamiento de objetos.
- **Restricciones:** subred `10.33.199.48/29` (seis direcciones utilizables, cinco asignadas) y software libre, por ausencia de un equipo de desarrollo permanente en la organización.

## 1.5 Metodología y organización del equipo

El trabajo se versiona en el repositorio Git del proyecto (bitácora, ADR, scripts, evidencias e inventario). Las decisiones relevantes se registran como ADR. Distribución de responsabilidades basada en los componentes del sistema:

| Integrante | Rol y responsabilidad principal |
|---|---|
| Octavio Valencia | CMS y backends WordPress (`cms-1`, `cms-2`) |
| Lukas Garrido | Base de datos (MariaDB 11) y servidor NFS (`db`) |
| Josecarlos Vidal | DNS (BIND9), nodo perimetral y balanceador Nginx (`dns`) |
| Equipo completo | Pila de monitorización, alertas, respaldos y operaciones (`monitor`) |

**Calendario de entregas:**

| Entrega | Hito | Fecha |
|---|---|---|
| 1 | Informe de requerimientos y arquitectura | 05/09/2026 |
| 2 | Plataforma base y CMS funcional | 05/09/2026 |
| 3 | Publicación resiliente y seguridad | 23/09/2026 |
| 4 | Observabilidad y continuidad operacional | 23/11/2026 |
| 5 | Incidente, auditoría y defensa final | 30/11/2026 |

## 1.6 Estructura del documento

Los capítulos 2 a 6 corresponden a las cinco entregas. El capítulo 7 integra los resultados, el 8 presenta conclusiones, y los anexos reúnen inventario, matrices, bitácora y registro de uso de IA.

---

# 2. Requerimientos y Arquitectura (Entrega 1)

## 2.1 Problema, actores y activos críticos

**Actores.** Marcas, talleres, productores y operadores de la red regional; personal con capacitación básica que administrará la plataforma; clientes finales; y el equipo del proyecto como proveedor de infraestructura.

**Activos críticos.** Catálogo de productos y servicios; registros de ventas, reservas e inscripciones; base de datos separada; archivos subidos al CMS; credenciales administrativas.

**Flujos de negocio.** Venta de catálogo, inscripción a talleres, reservas con cupos limitados, publicación de contenidos y atención posventa.

**Supuestos.** La organización no tiene equipo de desarrollo permanente, por lo que se usa software libre o de bajo costo. El tráfico presenta picos breves durante campañas de difusión.

**Consecuencias de las fallas sobre activos y flujos:**

| Activo / flujo | Falla | Pérdida o interrupción concreta | Requisito |
|---|---|---|---|
| Base de datos (pedidos, reservas, inscripciones) | Servicio caído o dato perdido | Sin ventas ni reservas; pedidos sin registro; cupos sobrevendidos o perdidos | RNF-02, RNF-06 |
| Archivos subidos (NFS) | NFS caído, divergencia o disco lleno | Imágenes de catálogo no disponibles; no se pueden publicar productos | RNF-03 |
| Nodo perimetral (DNS + Nginx) | Caída del host | Sitio inaccesible aunque los backends estén sanos | RNF-01, RNF-05 |
| Backend web | Caída de un nodo | Sin impacto si el otro absorbe la demanda; si no, degradación o interrupción de ventas | RNF-01 |
| Flujo de reserva con cupos | Escritura duplicada o perdida | Doble reserva o cupo perdido (solicitudes duplicadas del incidente piloto) | RF-01 |
| Respaldos | Backup antiguo o nunca restaurado | Pérdida de semanas de datos y recuperación incierta | RNF-06 |
| Credenciales administrativas | Compartidas, débiles o sin revocación | Acceso indefinido sin trazabilidad | RNF-04 |
| Monitorización y logs | Ausencia de métricas y alertas | Fallas de horas sin diagnóstico | RNF-05, RNF-08 |

## 2.2 Requerimientos y criterios de aceptación

Cada requerimiento tiene umbral medible y prueba. **Tabla 1.**

| ID | Requerimiento | Tipo | Criterio de aceptación | Prueba de validación |
|---|---|---|---|---|
| RF-01 | CMS funcional para catálogo, pedidos, reservas y contenidos | F | Un flujo completo (producto o reserva → pedido) bajo el dominio único; registro localizable en la aplicación y en la BD | Ejecutar compra o reserva desde un cliente y consultar la tabla en MariaDB |
| RNF-01 | Capa web con al menos dos nodos | NF | Con un backend detenido, ≥ 99 % de 100 GET responden 200 y la conmutación ocurre en ≤ 30 s | Detener un contenedor WordPress y lanzar 100 solicitudes con `curl`; revisar logs de Nginx |
| RNF-02 | BD independiente y no expuesta | NF | El 3306 solo responde a .50 y .51 (WordPress) y .52 (monitor); otros orígenes son rechazados | `nc -zv 10.33.199.53 3306` desde origen autorizado y no autorizado; reglas de firewall |
| RNF-03 | Persistencia y coherencia del estado compartido | NF | Un archivo subido por un backend se sirve con 200 y el mismo checksum desde el otro en ≤ 5 s | Subir imagen y descargarla por ambos backends; comparar `sha256sum` |
| RNF-04 | Administración remota por canales seguros y nominativos | NF | SSH por clave pública, un usuario por integrante, sin contraseña ni cuentas compartidas; revocación individual | Revisar `sshd_config`; revocar una clave de prueba y verificar el bloqueo |
| RNF-05 | Detección de falla crítica en tiempo acotado | NF | Alerta recibida en ≤ 5 min tras detener un backend, sin observar un panel | Detener un servicio y medir el tiempo hasta la alerta |
| RNF-06 | Continuidad mediante respaldos verificados | NF | Retención ≥ 30 días; restauración completa en ≤ 60 min con pérdida ≤ 24 h | Restaurar en una VM de prueba y medir tiempos y datos recuperados |
| RNF-07 | Dominio único con HTTPS válido | NF | `https://tas-06.arpa` sin error de certificado; HTTP:80 redirige a HTTPS | `curl -v` y `openssl s_client` desde un cliente |
| RNF-08 | Trazabilidad y hora consistente | NF | Desfase entre nodos ≤ 1 s y misma zona horaria; un evento se reconstruye correlacionando proxy, web, BD y SSH | `chronyc tracking` y `date` en todos los nodos; seguir una solicitud en Loki |

## 2.3 Selección del CMS y la suite tecnológica

Se compararon WordPress, Joomla y Drupal (decisión formal en **ADR-001**, aprobada).

| Criterio | WordPress | Joomla | Drupal |
|---|---|---|---|
| Licenciamiento | GPL, gratuito | GPL, gratuito | GPL, gratuito |
| Comunidad y soporte | Enorme; muchos plugins de reservas | Grande; menos extensiones | Grande; orientada a desarrolladores y proyectos enterprise |
| Curva de operación | Baja | Media | Alta |
| Recursos | Imagen oficial `wordpress:php8.3-apache` y MariaDB 11; 2 vCPU / 2 GB por backend | Comparable a WordPress | Mayor consumo y tuning con Commerce |
| Mantenimiento | Parches frecuentes; el riesgo está en plugins | Actualizaciones mayores exigentes | Actualizaciones mayores costosas |
| Compatibilidad | Docker, MariaDB y NFS; WooCommerce exige versiones mínimas | E-commerce y reservas dependen de extensiones poco integradas | E-commerce requiere Drupal Commerce y desarrollo a medida |
| Límites conocidos | *Stateful* (uploads en disco); `wp-cron` duplicado con dos nodos | Módulo de e-commerce menos maduro | Sin e-commerce/reservas nativo |
| Motivo de descarte | — | Suma extensiones frágiles sin beneficio sobre WordPress | Exige equipo de desarrollo dedicado |

**Justificación de WordPress + Nginx.**
- WordPress + WooCommerce cubre catálogo, pedidos, contenido y reservas.
- Imagen oficial con Apache y PHP 8.3: despliegue simple y réplica por contenedor.
- Nginx como proxy inverso y balanceador: bajo consumo y buen manejo de conexiones concurrentes ante picos de campaña (**ADR-002**).
- Pila PHP + MariaDB compatible con la arquitectura de referencia.

## 2.4 Arquitectura, flujos y puertos

**Figura 1.** Diagrama de despliegue (subred `10.33.199.48/29`, dominio `tas-06.arpa`).

```mermaid
flowchart LR
    cliente(["Cliente"])

    subgraph PERIM["dns · Nodo perimetral<br/>10.33.199.49 · ip pública 10.33.195.184"]
        direction LR
        dns(["DNS (BIND9)<br/>puerto 53"])
        nginx(["NGINX<br/>puertos 80 y 443<br/>exporter :9113"])
    end

    subgraph CMS1["cms-1 · WordPress CMS 1<br/>10.33.199.51"]
        cms1(["WordPress (contenedor)<br/>puerto 8080<br/>exporter :9117"])
    end

    subgraph CMS2["cms-2 · WordPress CMS 2<br/>10.33.199.50"]
        cms2(["WordPress (contenedor)<br/>puerto 8080<br/>exporter :9117"])
    end

    subgraph DBN["db · Base de datos y archivos<br/>10.33.199.53"]
        db(["MariaDB 11 (contenedor)<br/>puerto 3306"])
        nfs(["Servidor NFS<br/>puerto 2049"])
    end

    subgraph MON["monitor · Monitorización<br/>10.33.199.52"]
        mon(["Prometheus · Alertmanager<br/>Loki · Grafana"])
    end

    cliente -.->|"DNS :53"| dns
    cliente -->|"HTTP :80 / HTTPS :443"| nginx
    nginx -->|"HTTP :8080"| cms1
    nginx -->|"HTTP :8080"| cms2
    cms1 -->|"tcp :3306"| db
    cms2 -->|"tcp :3306"| db
    cms1 -.->|"NFS :2049"| nfs
    cms2 -.->|"NFS :2049"| nfs
    mon -.->|"métricas :3306"| db
    mon -.->|"métricas :9113"| nginx
    mon -.->|"métricas :9117"| cms1
    mon -.->|"métricas :9117"| cms2
```

**Tabla 3.** Matriz de puertos y flujos permitidos.

| Origen | Destino | Puerto | Protocolo | Propósito |
|---|---|---|---|---|
| Cliente | DNS (.49) | 53 | DNS UDP/TCP | Resolución de `tas-06.arpa` |
| Cliente | Nginx (.49) | 443 | HTTPS | Acceso al sitio con TLS terminado en el nodo perimetral |
| Cliente | Nginx (.49) | 80 | HTTP | Solo redirección a HTTPS |
| Nginx (.49) | CMS 1 (.51) y CMS 2 (.50) | 8080 | HTTP | Reenvío a los backends; único origen permitido |
| CMS 1 / CMS 2 | MariaDB (.53) | 3306 | TCP | Consultas a la BD, solo por red privada |
| CMS 1 / CMS 2 | NFS (.53) | 2049 | NFS/TCP | Montaje de `wp-config.php` y `wp-content/uploads` |
| Monitor (.52) | MariaDB (.53) | 3306 | TCP | `mysqld-exporter` (puerto 9104) con usuario de solo métricas |
| Monitor (.52) | Nginx (.49) | 9113 | HTTP | `nginx-prometheus-exporter` |
| Monitor (.52) | CMS 1 y CMS 2 | 9117 | HTTP | `apache-exporter` |
| Administrador | Nodo perimetral (IP pública .184) | 22 | SSH | Único punto de entrada administrativo (bastión) |
| Nodo perimetral | Demás nodos (IP privadas) | 22 | SSH | Administración nominativa con salto (`ssh -J`) |
| Todos los nodos | Fuente NTP | 123 | UDP | Sincronización horaria (RNF-08) |

## 2.5 Seguridad y administración de datos

- **Accesos remotos.** SSH por clave pública hacia IP privadas con salto por el bastión, usuario nominativo por integrante, `PasswordAuthentication no`, `PermitRootLogin no`.
- **Secretos.** Fuera del repositorio. Archivos `.env` (MariaDB, Grafana) y `.my.cnf` (exporter) con permisos `600` e ignorados por git.
- **Firewall y segmentación.** UFW en el host y reglas en `DOCKER-USER` para controlar el acceso al puerto 3306 (MariaDB) exclusivamente desde .50, .51 y .52.

---

# 3. Plataforma Base y CMS Funcional (Entrega 2)

## 3.1 Infraestructura, inventario y línea base

**Tabla 2.** Inventario y especificaciones técnicas de las máquinas virtuales.

| VM (Hostname) | Nodo | Rol y servicios | IP privada | IP pública / Red | SO y versión |
|---|---|---|---|---|---|
| `dns` | Perimetral | DNS (BIND9, puerto 53), Nginx (80/443), bastión SSH | `10.33.199.49` | `10.33.195.184` | Alpine Linux |
| `cms-1` | CMS 1 | WordPress (`wordpress:php8.3-apache`, 8080), `apache-exporter` (9117) | `10.33.199.51` | Pública a retirar | Alpine Linux, Docker |
| `cms-2` | CMS 2 | WordPress (`wordpress:php8.3-apache`, 8080), `apache-exporter` (9117) | `10.33.199.50` | Pública a retirar | Alpine Linux, Docker |
| `db` | Datos | MariaDB 11 (3306), Servidor NFS (`/srv/nfs/wordpress`, 2049) | `10.33.199.53` | Pública a retirar | Alpine Linux, Docker (191,7 GB disco) |
| `monitor` | Monitorización | Prometheus (9090), Alertmanager (9093), Loki (3100), Grafana (3000), `mysqld-exporter` (9104) | `10.33.199.52` | Pública a retirar | Alpine Linux 3.24.2, Docker v29.8.1, Compose v5.1.4 (191,6 GB disco) |

## 3.2 Almacenamiento y permisos (NFS)

El servidor NFS en `db` exporta `/srv/nfs/wordpress` con los subdirectorios `config/` y `uploads/`. Los clientes (`cms-1` y `cms-2`) montan la configuración en `/mnt/wp-config` (con persistencia en `/etc/fstab` y `netmount`) y los archivos multimedia en el volumen Docker `wp_uploads_shared` mediante NFS v4 (`addr=10.33.199.53`).

## 3.3 DNS, servidor web y TLS

- BIND9 en `dns` resuelve el dominio interno `tas-06.arpa`, con recursión restringida a la subred `10.33.199.48/29` y canal de estadísticas en `127.0.0.1:8053`.
- Nginx termina TLS y redirige HTTP (80) a HTTPS (443).

---

# 4. Publicación Resiliente, Contenedores y Seguridad (Entrega 3)

## 4.1 Aplicación multicontenedor reproducible

Todos los servicios corren bajo Docker y Docker Compose con imágenes de versión fija. Los backends ejecutan `wordpress:php8.3-apache` junto a `lusotycoon/apache-exporter` en el puerto 9117. Se habilitó el módulo `server-status` en Apache mediante `/opt/cms/status.conf` (`RewriteEngine Off`) para permitir el scraping de métricas.

## 4.2 Balanceo pasivo y alta disponibilidad

Mediante Nginx como proxy inverso y balanceador de carga, se distribuyen las peticiones hacia ambos backends WordPress. Ante la caída de un backend, la detección pasiva de Nginx (`max_fails`, `fail_timeout`) redirige el tráfico al nodo sano, garantizando tolerancia a fallas de nodo único.

## 4.3 Firewall y seguridad de red (`DOCKER-USER`)

Dado que Docker manipula iptables directamente saltándose UFW, se configuraron reglas explícitas en la cadena `DOCKER-USER` en `db` y los demás nodos mediante scripts de inicio en `/etc/local.d/` para asegurar que el puerto 3306 de MariaDB y el 8080 de WordPress solo acepten tráfico desde los orígenes autorizados.

---

# 5. Observabilidad y Continuidad Operacional (Entrega 4)

## 5.1 Pila de monitorización y métricas

La VM `monitor` ejecuta el stack de observabilidad con puertos enlazados estrictamente a `127.0.0.1`. El acceso de los administradores se realiza mediante reenvío de puertos SSH (`AllowTcpForwarding local`).

| Componente | Exporter / Fuente | Puerto | Métrica clave / Job |
|---|---|---|---|
| Proxy Nginx | `nginx-prometheus-exporter` 1.3.0 | 9113 | `nginx_up`, conexiones activas (`job: nginx-lb`) |
| Backends Apache | `apache-exporter` | 9117 | `apache_up`, workers ocupados |
| Base de datos MariaDB | `prom/mysqld-exporter` v0.17.2 | 9104 | `mysql_up`, conexiones, consultas (`job: mariadb`) |
| Monitorización central | Prometheus / Grafana / Loki | 9090 / 3000 / 3100 | Métricas de infraestructura, paneles y logs centralizados |

## 5.2 Alertas y trazabilidad de logs

- **Alertas:** Alertmanager configurado en el puerto 9093 con reglas base en Prometheus (`alerts.yml`).
- **Logs:** Recolectados y centralizados en Loki (retención de 7 días). Sincronización horaria por NTP en todos los nodos (RNF-08).

## 5.3 Respaldo automático de MariaDB

Se implementó un script automatizado en `/usr/local/bin/backup-db.sh` en la VM de base de datos, ejecutado mediante cron de root cada dos días a las 02:30 (días impares):
- **Acción:** `mariadb-dump --all-databases --single-transaction --routines --triggers --events`.
- **Verificación:** Validación con `tail` de la cadena `Dump completed`, compresión con `gzip`, comprobación de integridad (`gzip -t`) y generación de checksum SHA-256 (`.sha256`).
- **Retención:** 30 días (`find ... -mtime +30 -delete`), con permisos restringidos (`640`, propietario `database`).

---

# 6. Incidente, Auditoría y Defensa Final (Entrega 5)

Las pruebas operativas y la simulación de incidentes se estructuran bajo el runbook del Anexo D, validando los flujos de negocio (RF-01) y la recuperación ante fallas de infraestructura.

---

# 7. Análisis Integrado de la Solución

## 7.1 Cumplimiento de requerimientos

| ID | Requisito | Estado | Observación |
|---|---|---|---|
| RF-01 | CMS funcional (catálogo, pedidos, reservas) | [Implementado] | WordPress + WooCommerce operativo con BD centralizada |
| RNF-01 | Capa web con al menos dos nodos | [Implementado] | Dos réplicas con balanceador Nginx |
| RNF-02 | BD independiente y no expuesta | [Implementado] | MariaDB en VM dedicada, puerto 3306 restringido |
| RNF-03 | Persistencia y coherencia compartida | [Implementado] | Servidor NFS en `/srv/nfs/wordpress` |
| RNF-04 | Administración SSH segura y nominativa | [Por evidenciar] | Claves públicas; consolidar cuentas sin root |
| RNF-05 | Detección de falla crítica en tiempo acotado | [Parcial] | Pila Prometheus/Alertmanager lista; definir destino |
| RNF-06 | Continuidad y respaldos verificados | [Parcial] | Script automático diario con sha-256; falta prueba de restauración |
| RNF-07 | Dominio único con HTTPS válido | [Implementado] | `https://tas-06.arpa` con Nginx TLS |
| RNF-08 | Trazabilidad y hora consistente | [Implementado] | NTP configurado y Loki para logs |

---

# 8. Conclusiones y Trabajo Futuro

El proyecto Nodo Sur demostró la viabilidad de construir una infraestructura resiliente, contenerizada y observable con software libre sobre Alpine Linux. La separación de la base de datos, el uso de almacenamiento compartido NFS y la monitorización con Prometheus y Grafana otorgan una base sólida para la operación regional. Como trabajo futuro se contempla la separación de DNS y Nginx, la replicación de MariaDB y la automatización completa de las pruebas de restauración.

---

# 9. Referencias

[1] WordPress.org, «Documentation and Developer Resources», https://wordpress.org/support/
[2] WooCommerce, «WooCommerce Documentation», https://woocommerce.com/documentation/
[3] Nginx, «Module ngx_http_upstream_module Reference», https://nginx.org/en/docs/http/ngx_http_upstream_module.html
[4] MariaDB Foundation, «MariaDB Knowledge Base», https://mariadb.com/kb/
[5] Prometheus, «Prometheus Documentation», https://prometheus.io/docs/
[6] Grafana Labs, «Loki Documentation», https://grafana.com/docs/loki/latest/
[7] Docker Inc., «Packet filtering and firewalls», https://docs.docker.com/network/packet-filtering-firewalls/

---

# 10. Anexos

## Anexo A — Matriz de trazabilidad
(Ver tablas de requisitos en los capítulos 2 y 7).

## Anexo B — Inventario y versiones
(Ver Tabla 2, sección 3.1, con versiones exactas de Alpine, Docker, MariaDB, WordPress, Prometheus y Grafana).

## Anexo C — Matriz de flujos, puertos y firewall
(Ver Tabla 3, sección 2.4, y las reglas de `DOCKER-USER` documentadas en `scripts_firewall_ufw.md`).

## Anexo D — Runbook operativo
1. **backend caído:** verificar `up` en Prometheus, reiniciar contenedor Docker o aislar temporalmente en `upstream` de Nginx.
2. **BD caída:** revisar contenedor MariaDB, espacio en disco (`df -h`) y conexiones máximas (`max_connections`).
3. **NFS no disponible:** verificar servicio `nfs` en `db` y punto de montaje en clientes con `df -h /mnt/wp-config`.

## Anexo E — Bitácora de cambios
- **2026-09-09:** Estructuración inicial del repositorio e inventario de infraestructura.
- **2026-09-10:** Migración e importación de la base de datos desde la VM auxiliar hacia la VM `db`; habilitación de acceso remoto al puerto 3306 y resolución DNS para `tas-06.arpa`.
- **2026-09-20:** Despliegue de backends Docker con contenedores WordPress y montaje NFS compartido.
- **2026-11-15:** Puesta en marcha de la VM de monitorización (`monitor`) con Prometheus, Alertmanager, Loki, Grafana y exporters.
- **2026-11-20:** Implementación del script de respaldo automático de MariaDB con verificación SHA-256.

## Anexo F — Registro de Decisiones (ADR)
- **ADR-001:** Selección de WordPress + WooCommerce frente a Joomla y Drupal (Aprobada).
- **ADR-002:** Nginx como balanceador pasivo en vez de HAProxy (Aprobada).
- **ADR-003:** NFS compartido en la VM de base de datos (Aprobada por limitaciones de subred /29).

## Anexo G — Contribución individual
- **Josecarlos Vidal:** Configuración de DNS (BIND9), proxy inverso Nginx, certificado TLS y reglas de perimetral.
- **Octavio Valencia:** Despliegue de contenedores WordPress, configuración de WooCommerce, plugins y exporters de Apache.
- **Lukas Garrido:** Configuración de MariaDB 11, servidor NFS, scripts de respaldo automático con compresión y checksums, y cortafuegos UFW / `DOCKER-USER`.

## Anexo H — Uso de inteligencia artificial
Registro conforme a `bitacora/uso-ia.md`:
- **Claude:** Soporte en redacción de scripts de respaldo, comandos SQL, resolución de errores de red y diagnóstico de DNS para `tas-06.arpa`.
- **Antigravity IDE / Gemini:** Asistencia en la estructuración de carpetas del repositorio, organización en Markdown y revisión ortográfica general.
- *Validación:* Todo script o comando generado por IA fue probado empíricamente en el laboratorio antes de su integración.

## Anexo I — Correspondencia con las rúbricas
Correspondencia directa establecida entre los Capítulos 2 a 6 y las rúbricas de las Entregas 1 a 5 de la asignatura EIN-090B (Taller de Administración de Sistemas).
