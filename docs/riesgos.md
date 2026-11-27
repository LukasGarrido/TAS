# Análisis de Riesgos y Mitigaciones — Nodo Sur

| Riesgo | Probabilidad | Impacto | Tratamiento propuesto |
|---|---|---|---|
| Un backend no puede absorber el pico cuando cae el otro | Media | Alto | Criterio N-1 con prueba de carga; ajuste de `MaxRequestWorkers`, caché y `limit_req`. |
| Caída de la VM de la BD (MariaDB y NFS comparten host) | Media | Alto | Declarado como SPOF; backups verificados, y separar el NFS y replicar la BD como evolución. |
| Caída del nodo perimetral (DNS + Nginx en el mismo host y único bastión SSH) | Media | Alto | Declarado como SPOF; separar DNS y Nginx, evaluar segundo proxy con VRRP y mantener la consola del hipervisor como vía de emergencia. |
| Divergencia de plugins entre backends | Media | Medio | `DISALLOW_FILE_MODS` y despliegue desde archivos versionados. |
| Acceso directo a un backend que elude el punto de entrada (puerto 8080 abierto y IP pública en CMS 1, CMS 2, monitor y BD) | Alta | Medio | Dejar cada VM con una sola tarjeta (privada), publicar en IP privada y restringir en `DOCKER-USER`. |
| Endpoints de estado y métricas expuestos (`/server-status`, exporters, BIND9) | Alta | Medio | Restringir `/server-status` a la red interna de Docker, limitar los exporters al origen `10.33.199.52` y dejar BIND9 en `127.0.0.1`. |
| Resolvedor DNS abierto (recursión para cualquier origen) | Alta | Medio | Limitar `allow-recursion` y `allow-query-cache` a `10.33.199.48/29` y verificar `REFUSED` desde fuera. |
| Pérdida de avisos: Prometheus y Alertmanager viven en `monitor` y el único destino es Discord; si cae esa VM o su salida a internet, nadie es avisado | Media | Alto | Vigilancia externa de la VM `monitor`, un segundo canal de aviso y pruebas periódicas de entrega. |
| Falla no detectada a tiempo por health checks pasivos | Media | Alto | Script de comprobación activa con alerta y monitorización. |
| Pérdida de datos por una operación destructiva sin respaldo previo | Media | Alto | Dump antes de `docker compose down -v` y backups automatizados. |
| Respaldos solo manuales, en la misma VM y sin restauración probada | Alta | Alto | Prueba de restauración en un contenedor aparte, copia en el nodo perimetral, automatización con retención de 30 días y medición de RPO y RTO. |
| Zonas horarias distintas entre VM y contenedores | Media | Medio | Fijar `TZ` en los contenedores y sincronizar la hora de todos los nodos. |
| Credenciales débiles o compartidas en las cuentas de las VM | Alta | Alto | Usuarios nominativos con clave, `PasswordAuthentication no`, `PermitRootLogin no`, cambio inmediato de contraseñas y secretos fuera del repositorio. |
| Plugins desactualizados o vulnerables | Media | Medio | Política de actualización en pruebas, plugins mínimos e imágenes con etiqueta fija. |
