# Plan de Implementación y Trazabilidad — Nodo Sur

## 1. Plan de Implementación por Etapas

| Etapa | Entregable | Dependencias | Pruebas previstas | Criterio para avanzar | Reversión |
|---|---|---|---|---|---|
| **Entrega 2** | Docker en los nodos, MariaDB y WordPress en contenedores, DNS y Nginx, servidor NFS y VM de monitorización. | VMs y red listas; decisión sobre salida a internet (NAT). | Resolución DNS de `tas-06.arpa`, acceso HTTPS por nombre, flujo de compra/reserva, BD inaccesible desde fuera, NFS montado. | RF-01, RNF-02 y RNF-07 verificados. | Dump de la BD y respaldo de compose/nginx.conf; consola del hipervisor. |
| **Entrega 3** | Balanceo verificado entre backends, script de salud, firewall en `DOCKER-USER` y prueba de capacidad N-1. | Entrega 2 y ADR-003. | Distribución entre CMS 1 y CMS 2, retiro de un backend, checksum entre nodos, prueba de carga un solo backend. | RNF-01 y RNF-03 verificados; capacidad de un backend ≥ pico proyectado. | Quitar el segundo backend del `upstream` y volver a un solo nodo. |
| **Entrega 4** | Alertas con destino, exporter de BIND9, agente de logs hacia Loki, backups automatizados y restauración. | Entrega 3. | Degradación controlada, alerta ≤ 5 min, restauración ≤ 60 min en VM de prueba. | RNF-05, RNF-06 y RNF-08 verificados con marcas de tiempo. | Restaurar configuración anterior desde Git. |
| **Entrega 5** | Auditoría final e incidente no anunciado. | Entrega 4. | Recuperación validada con flujo de negocio, defensa individual. | Matriz de pruebas completa. | Etiqueta de versión estable del repositorio. |

---

## 2. Matriz de Trazabilidad

| Requisito | Componente principal | Prueba de validación | Evidencia esperada |
|---|---|---|---|
| RF-01 | WordPress + WooCommerce + MariaDB | Flujo de compra o reserva completo | Registro en la aplicación y en la BD |
| RNF-01 | Nginx (upstream) + 2 backends | Detener un backend y lanzar 100 solicitudes | Salida del bucle y logs de Nginx |
| RNF-02 | MariaDB + firewall (`DOCKER-USER`) | `nc` a 3306 desde origen autorizado y no autorizado | Salida de `nc`, reglas del firewall |
| RNF-03 | Servidor NFS (VM de BD) + montajes | Subir archivo y comparar `sha256sum` en ambos backends | Checksums idénticos |
| RNF-04 | `sshd` + usuarios nominativos | Revocar una clave y verificar bloqueo | `sshd_config`, `auth.log` |
| RNF-05 | Prometheus + Alertmanager | Detener servicio y medir tiempo hasta alerta | Marcas de tiempo de evento y alerta |
| RNF-06 | Backups (`backup-db.sh`, `pull-db.sh`) + VM de prueba | Restauración medida | Tiempos de RPO y RTO reales |
| RNF-07 | Nginx + certificado TLS | `curl -v` y `openssl s_client` | Salida sin errores de certificado |
| RNF-08 | NTP + Loki | `chronyc tracking`, `date` y correlación de solicitudes | Desfase ≤ 1 s, misma zona horaria y logs sincronizados |
