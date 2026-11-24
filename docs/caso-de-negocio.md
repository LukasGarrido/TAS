# Caso de Negocio — Nodo Sur

## 1. Contexto y Problemática

Nodo Sur agrupa a pequeñas marcas, talleres creativos, productores y operadores de experiencias, quienes actualmente gestionan sus ventas, reservas, inscripciones y atención a clientes mediante las redes sociales, con formularios aislados y mensajería. Esta modalidad de operación dificulta la centralización de la información, aumenta el riesgo de pérdida de datos y genera problemas de disponibilidad de servicios.

El proyecto tiene como fin diseñar e implementar una plataforma digital *centralizada, administrable* y *resiliente* que permita a distintos miembros de Nodo Sur publicar sus productos y experiencias, gestionar pedidos y reservas, ofrecer contenidos y mantener comunicación con sus clientes **desde un único dominio**.

La solución propuesta debe soportar periodos de aumento de demanda asociados a campañas de difusión, manteniendo la continuidad del servicio web incluso ante la falla de uno de los nodos web.

---

## 2. Actores y Activos Críticos

- **Actores:** Pequeñas marcas, talleres creativos, productores y operadores de experiencias de la red regional; el personal con capacitación básica que administrará la plataforma; los clientes finales; y el equipo del proyecto, que actúa como proveedor de infraestructura.
- **Activos críticos:** El catálogo de productos y servicios, los registros de ventas, reservas e inscripciones a talleres, la base de datos separada, los archivos subidos al CMS y las credenciales administrativas.
- **Flujos de negocio:** Venta de catálogo, inscripción a talleres, reservas con cupos limitados, publicación de contenidos y atención posventa.
- **Supuestos:** La organización no tiene un equipo de desarrollo permanente, por lo que la plataforma debe basarse en software libre o de bajo costo. El tráfico experimentará picos de demanda breves durante las campañas de difusión.

---

## 3. Consecuencias de las Fallas

| Activo / flujo | Falla | Pérdida o interrupción concreta | Requisito cubierto |
|---|---|---|---|
| Base de datos (pedidos, reservas, inscripciones) | Servicio caído o dato perdido | Sin ventas ni reservas mientras dure la falla, pedidos o inscripciones sin registro, cupos sobrevendidos o perdidos | RNF-02, RNF-06 |
| Archivos subidos (servidor NFS) | Servidor NFS caído, divergencia o disco lleno | Imágenes de catálogo no disponibles en uno o ambos backends, imposibilidad de publicar productos | RNF-03 |
| Nodo perimetral (DNS + Nginx) | Caída del host | Sitio completo inaccesible aunque los backends estén sanos | RNF-01, RNF-05 |
| Backend web (CMS 1 o CMS 2) | Caída de un nodo | Sin impacto si el otro absorbe la demanda, si no la absorbe, degradación o interrupción de ventas | RNF-01 |
| Flujo de reserva con cupos | Escritura duplicada o perdida | Doble reserva o cupo perdido (caso de las solicitudes duplicadas del incidente piloto) | RF-01 |
| Respaldos | Backup antiguo o nunca restaurado | Pérdida de semanas de datos y recuperación incierta | RNF-06 |
| Credenciales administrativas | Compartidas, débiles, expuestas o sin revocación | Acceso indefinido de personas que ya no deberían tenerlo, sin trazabilidad | RNF-04 |
| Monitorización y logs | Ausencia de métricas y alertas | Fallas de horas sin diagnóstico | RNF-05, RNF-08 |
