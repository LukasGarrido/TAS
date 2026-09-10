## Contexto

El enunciado propone como referencia una arquitectura con HAProxy como punto de entrada único, encargado de terminar TLS, distribuir tráfico entre backends y ejecutar health checks activos que retiren automáticamente un nodo defectuoso (RNF-01). Como equipo, definimos la arquitectura de despliegue usando **Nginx** en el mismo nodo perimetral que el servicio DNS, actuando como proxy inverso hacia los dos backends WordPress.

## Opciones consideradas

**HAProxy** (referencia del enunciado)

- Diseñado específicamente para balanceo de carga y proxy TCP/HTTP.
- Health checks activos nativos, con retiro automático de backends no saludables y reintegración al recuperarse.
- Panel de estadísticas (`stats page`) que facilita observar en tiempo real qué backend atiende cada solicitud útil como evidencia en la Entrega 3.
- Requiere un servicio adicional dedicado exclusivamente a esta función.

**Nginx como proxy/balanceador** (opción elegida)

- Ya forma parte de la stack elegida como servidor web de cada backend (Nginx + PHP-FPM), por lo que el equipo tiene experiencia previa configurándolo.
- Soporta balanceo mediante bloques `upstream`, con varios algoritmos (round-robin, least_conn, etc.).
- Los health checks activos (que verifican periódicamente si un backend está sano sin esperar una solicitud real) no están disponibles en la versión open-source de Nginx, solo existen en NGINX Plus (de pago). En la versión libre solo se dispone de detección pasiva: un backend se marca como no disponible después de que una solicitud real falla, no antes.
- No cuenta con un panel de estadísticas equivalente al de HAProxy, la evidencia de distribución de tráfico debe obtenerse de los logs de acceso.

## Decisión

Se utiliza **Nginx** como proxy/balanceador hacia los dos backends WordPress, en lugar de HAProxy.
