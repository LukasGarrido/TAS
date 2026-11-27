<div align="center">

# Bitácora General del Proyecto — Grupo 06 (Nodo Sur)
**Asignatura:** EIN-090B · Taller de Administración de Sistemas (TAS)  
**Semestre:** 2026  
**Repositorio:** [LukasGarrido/TAS](https://github.com/LukasGarrido/TAS)

</div>

---

## 1. ¿Cómo arrancamos y de qué trata esto?

Esta bitácora cuenta nuestra historia paso a paso en el desarrollo de **Nodo Sur**. Aquí anotamos cómo nos organizamos, qué decisiones fuimos tomando, con qué dolores de cabeza nos tropezamos en el camino y cómo logramos armar y dejar funcionando la plataforma web para los talleres y marcas de la red regional.

---

## 2. El diario de viaje: Hitos y actividades principales

| Fecha | Momento / Hito | Qué hicimos y cómo lo vivimos | ¿Cómo comprobamos que funcionó? |
|---|---|---|---|
| **01/09/2026** | **El punto de partida (Entrega 1)** | Nos juntamos a definir qué problemas tenía la gente de Nodo Sur (formularios caídos, desorden, riesgo de perder ventas). Diseñamos el plan general y las reglas del juego para que el sitio web no se cayera fácilmente. | Quedó aprobado el diseño inicial del proyecto. |
| **05/09/2026** | **Eligiendo las herramientas** | Tuvimos que decidir con qué tecnología armaríamos la tienda. Evaluamos varias opciones (como WordPress, Joomla y Drupal) y nos decantamos por WordPress con WooCommerce porque era más amigable de administrar para los usuarios y más fácil de mantener para nosotros. | Firmamos los documentos de decisión (ADR). |
| **09/09/2026** | **Prendiendo los servidores y el directorio web** | Empezamos a levantar las máquinas virtuales en el servidor del laboratorio. Configuré el servicio de nombres (DNS) en el nodo principal para que el dominio `tas-06.arpa` por fin respondiera. | Lo probamos con comandos básicos de búsqueda (`nslookup`). |
| **10/09/2026** | **Base de datos** | Nos pusimos a armar la base de datos central en un servidor apartado. Trajimos la información de las pruebas anteriores, armamos los accesos y nos aseguramos de que nadie de afuera pudiera meterse a vitrinear los datos. | Consultamos las tablas directamente para ver que estuvieran ahí. |
| **15/09/2026** | **Compartiendo archivos entre servidores** | Nos dimos cuenta de que si teníamos dos servidores web, cada uno iba a guardar las fotos de los productos por su cuenta y se armaría un enredo. Solucionamos esto armando una carpeta compartida en red. | Verificamos que los servidores montaran bien la carpeta y leyeran lo mismo. |
| **20/09/2026** | **Montando las tiendas en contenedores** | Instalamos los dos servidores web usando contenedores (Docker). Conectamos ambos a la misma base de datos y a la carpeta compartida que armamos antes. ¡La tienda ya corría por duplicado! | Entramos a la página y probamos hacer una compra de prueba. |
| **25/09/2026** | **Seguridad** | Configuramos el servidor que recibe a los clientes en la entrada, encargándose de repartir la visita entre los dos servidores web y de ponerle el candado de seguridad (HTTPS). Además, blindamos los accesos para que estuvieran seguros. | Hicimos pruebas simulando fallas para ver si el sitio seguía respondiendo. |
| **15/11/2026** | **Monitorización** | Levantamos un servidor especial dedicado exclusivamente a vigilar la salud de toda la infraestructura. Armamos tableros visuales para ver si el procesador se ahoga, si la base de datos sufre o si los servidores web están felices. | Entramos a los tableros de control y revisamos que las alertas estuvieran activas. |
| **20/11/2026** | **Respaldos automáticos** | Programamos un sistema automático para que, cada dos días a la madrugada, el servidor guarde una copia completa de la base de datos, la comprima y verifique que no esté corrupta. | Revisamos los reportes y logs generados tras las ejecuciones de prueba. |
| **22/11/2026** | **Identidad visual y respaldos** | Incorporamos el logotipo oficial de la USM en la documentación e integramos los manuales detallados de respaldos automáticos en MariaDB y accesos seguros por SSH. | Verificación visual y pruebas de ejecución de respaldos. |
| **23/11/2026** | **Cierre y entrega final** | Juntamos todas las piezas, realizamos mejoras estructurales profundas en el informe NODO SUR, limpiamos archivos obsoletos y dejamos la plataforma lista para la defensa. | Todo el sistema quedó operativo y documentado. |
| **24/11/2026** | **Corrección del monitoreo (Grafana/Prometheus)** | El tablero mostraba todos los servicios caídos aunque funcionaban. La causa estaba en el firewall de la VM de monitoreo: al recargarse UFW se borraron las reglas de red que crea Docker (cadena `DOCKER-USER` y `MASQUERADE`), y los contenedores perdieron salida hacia la red 10.33.199.x. Reiniciamos Docker y levantamos de nuevo los contenedores con `docker compose up -d`, lo que recreó las reglas. Después, el panel "Site availability" seguía en rojo porque la sonda de blackbox-exporter no confiaba en el certificado HTTPS interno; creamos un `blackbox.yml` con `insecure_skip_verify` y timeout de 10 s, lo montamos en el compose con `restart: unless-stopped` y limitamos el puerto 9115 a `127.0.0.1`. | Todos los targets de Prometheus quedaron en `1`, `probe_success` en `1` (HTTP 200) y los paneles del tablero volvieron a mostrar datos. |
| **27/11/2026** | **Monitoreo de las máquinas** | Grafana mostraba el estado de los servicios, pero no el de las máquinas. Instalamos `node_exporter` en las cinco VMs, agregamos el job `node` en Prometheus e importamos el tablero **Nodo Sur - Máquinas**. En `cms-2` el firewall bloqueaba el puerto 9100 y lo permitimos solo desde el monitor. En `dns` encontramos UFW inactivo, así que dejamos el exporter escuchando solo en la IP privada. Quedaba pendiente revisar el firewall de `dns`. | La consulta `up{job="node"}` devolvió `1` para las cinco VMs. |
| **27/11/2026** | **Alertas a Discord** | Conectamos Alertmanager con un canal de Discord y cargamos las reglas de máquinas y servicios. Al principio no llegaba nada porque en el monitor solo existía `alerts.yml`. También corregimos los paneles de disponibilidad, que seguían en verde al apagar Docker en `cms-1` porque mostraban el último dato recibido. | Prometheus validó 17 reglas y, al detener `node_exporter` en `cms-2`, la alerta `MaquinaCaida` llegó a Discord. |

---

## 3. Los dolores de cabeza (Incidencias y cómo los salvamos)

En el camino no todo salió a la primera. Aquí están los tropiezos más notables y cómo los sacamos adelante:

* **El misterio del nombre que no respondía (10/09/2026):** Cuando nos conectábamos desde fuera usando la red institucional, el computador no encontraba el sitio `tas-06.arpa`. Como el sistema de red de la VPN se confundía con el sufijo, tuvimos que hacer un pequeño ajuste manual en el archivo de equipos de nuestros computadores (`hosts`) para que supiera exactamente a qué puerta tocar. ¡Santo remedio!
* **El colado de la base de datos (12/09/2026):** Aplicamos las reglas de seguridad en el cortafuegos del servidor principal, pero notamos que la base de datos seguía aceptando conexiones desde cualquier parte. Resulta que las herramientas de contenedores que usábamos pasaban por alto las reglas normales de seguridad del sistema. Tuvimos que ajustar las reglas internas del motor de red para cerrarle la puerta a cualquiera que no fuera de confianza.
* **Las fotos perdidas entre servidores (18/09/2026):** Al principio, si un usuario subía una foto de un producto, esta se guardaba solo en el servidor que lo atendió en ese momento, haciendo que el otro servidor no la encontrara. Al armar la carpeta compartida en red, logramos que ambos servidores vieran exactamente los mismos archivos al mismo tiempo.
* **El monitoreo que veía todo caído (24/11/2026):** El tablero de Grafana marcaba todos los servicios como caídos pese a estar operativos. Al recargar el cortafuegos (UFW), este eliminó las reglas que Docker había creado para la red de los contenedores, así que el servidor de monitoreo dejó de alcanzar al resto de las máquinas. Reiniciar Docker las recreó y todo volvió a la normalidad. Luego hubo que ajustar la sonda de disponibilidad para que aceptara el certificado interno del sitio. Queda pendiente dejar las reglas de Docker fijas para que no se repita tras un `ufw reload` o un reinicio de la VM.

---

## 4. Cuidando lo que hacemos

Para no romper nada por accidente, cada vez que queríamos cambiar la configuración de la red, de las páginas o de la seguridad, nos acostumbramos a probar primero que los comandos estuvieran bien escritos antes de aplicarlos en vivo. Así tuvimos todo bajo control de principio a fin.