# Nodo Sur — Plataforma digital resiliente

**Asignatura:** EIN-090B · Taller de Administración de Sistemas
**Proyecto integrador 2026**
**Grupo:** 6
**Paralelo:** 701

**Integrantes:**
- Josecarlos Vidal
- Octavio Valencia
- Lukas Garrido


---

## 1. Descripción del proyecto

El proyecto tiene como propósito transformar un problema empresarial en una plataforma operable. El objetivo principal no es solamente instalar un CMS y mostrar su portada, sino construir una solución robusta que pueda ser publicada, administrada, diagnosticada, mantenida y recuperada ante posibles fallas. 

Para lograr esto, el equipo (JoseCarlos, Octavio, Lukas), deberán actuar como un proveedor de infraestructura. En este rol es fundamental justificar cada decisión técnica y sobre la arquitectura, mediante el establecimiento de requerimientos, la ejecución de pruebas, la recolección de métricas, el análisis de logs y la creación de procedimientos que sean completamente reproducibles.  

---

## 2. Estado del proyecto

| Entrega | Hito                                     | Estado       | Fecha |
| ------- | ---------------------------------------- | ------------ | ----- |
| 1       | Informe de requerimientos y arquitectura | 🔲 En curso  | 05/09 |
| 2       | Plataforma base y CMS funcional          | 🔲 Pendiente |       |
| 3       | Publicación resiliente y seguridad       | 🔲 Pendiente |       |
| 4       | Observabilidad y continuidad operacional | 🔲 Pendiente |       |
| 5       | Incidente, auditoría y defensa final     | 🔲 Pendiente |       |

---

## 3. Estructura del repositorio

```
nodo-sur/
├── README.md
├── docs/
│   ├── entrega-1/
│   ├── entrega-2/
│   ├── entrega-3/
│   ├── entrega-4/
│   └── entrega-5/
├── decisiones/
│   └── ADR-XXX-titulo-decision.md
├── infraestructura/
│   ├── inventario.md
│   └── (configs saneadas, IaC, compose files, etc. — se irán agregando)
├── scripts/
│   └── (scripts de instalación, validación, backup, etc.)
├── evidencias/
│   └── (capturas, logs, salidas de pruebas por entrega)
└── bitacora/
    ├── bitacora-general.md
    └── uso-ia.md
```

> _La arquitectura esta sujeta a cambios hasta fin de la entrega 1  (ojala xd)_

---

## 4. Caso de negocio

Nodo Sur es una red regional que agrupa pequeñas marcas, talleres creativos, productores y operadores de experiencias, quienes actualmente gestionan sus ventas, reservas, inscripciones y atención a clientes mediante las redes sociales, con formularios aislados y mensajería. Actualmente esta modalidad de operación dificulta la centralización de la información, aumenta el riesgo de perdida de datos y genera problemas de disponibilidad de servicios. 

El proyecto tiene como fin el diseñar e implementar una plataforma digital, la cual sea *centralizada, administrable* y *resiliente* que permita a distintos miembros de Nodo Sur publicar sus productos y experiencias, gestionar pedidos y reservas, ofrecer contenidos y mantener comunicación con sus clientes **desde un único dominio**.

La solucion propuesta debe ser capaz de soportar periodos de aumento de demanda asociados a campañas de difusión, manteniendo la continuidad del servicio incluso ante la falla de uno de los nodos. Para esto se plantea una arquitectura compuesta por servicios separados, incluyendo una aplicación o CMS, servidores web, una base de datos independiente, balanceo de carga, mecanismos de monitorización, gestión de logs y respaldos.

Este repositorio contiene la documentación, configuraciones, scripts, pruebas y evidencias asociadas al desarrollo de la plataforma como parte del proyecto integrador de **Taller de Administración de Sistemas (EIN-090B)** de la Universidad Técnica Federico Santa María.

---

## 5. Entrega 1 — Informe de requerimientos y arquitectura

### 5.1 Análisis del problema
- **Actores:** Pequeñas marcas, talleres creativos, productores y operadores de experiencias de la red regional. Adicionalmente, el personal con capacitación básica que administrará la plataforma y los clientes finales
- **Activos críticos:** El catálogo de productos y servicios, los registros de ventas e inscripciones a talleres, la base de datos separada y los archivos subidos al CMS.
- **Flujos de negocio:** Venta de catálogo, inscripción a talleres, reservas con cupos limitados, publicación de contenidos y atención posventa
- **Supuestos:** La organización no tiene un equipo de desarrollo permanente, por lo que la plataforma debe basarse en software libre o de bajo costo. El tráfico experimentará picos de demanda breves durante las campañas de difusión

### 5.2 Requerimientos

| ID     | Requerimiento                                                                                | Tipo (F/NF)  | Criterio de aceptación                                                                                                             |
| ------ | -------------------------------------------------------------------------------------------- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| RF-01  | Contar con un CMS funcional para catálogo, pedidos, reservas y administración de contenidos. | Funcional    | El CMS debe operar correctamente bajo un dominio unificado.                                                                        |
| RNF-01 | Mantener la disponibilidad del servicio mediante al menos dos nodos web                      | No funcional | Un proxy (HAProxy) debe distribuir las solicitudes, realizar health checks y no enviar tráfico a un nodo declarado como defectuoso |
| RNF-02 | Asegurar que la base de datos opere de manera independiente.                                 | No funcional | La base de datos debe ser accesible únicamente desde los orígenes, sin quedar expuesta a redes externas.                           |
| RNF-03 | Garantizar la persistencia y coherencia del estado compartido.                               | No funcional | Los archivos, imágenes y sesiones deben mantenerse coherentes y disponibles aunque falle uno de los nodos.                         |
| RNF-04 | Administración remota solo por canales seguros y nominativos                                 | No funcional | Acceso SSH por clave pública, un usuario por integrante, sin cuentas compartidas, revocable individualmente                        |
| RNF-05 | Detección de falla crítica en tiempo acotado                                                 | No funcional | Una alerta automática y verificable llega ante una falla, sin depender de que alguien esté observando un panel.                    |
| RNF-06 | Continuidad mediante respaldos verificados                                                   | No funcional | Existe un diseño de backup con retención ≥30 días y un procedimiento de restauración definido (Entrega 4 xd)                       |
| RNF-07 | Publicación bajo un dominio único con HTTPS válido                                           | No funcional | El sitio responde por nombre con certificado TLS válido.                                                                           |
| RNF-08 | Trazabilidad y hora consistente en logs                                                      | No funcional | Los eventos de proxy, web, BD y SSH pueden correlacionarse por timestamp gracias a sincronización horaria.                         |

### 5.3 Selección de CMS y suite

Evaluación de alternativas para el proyecto, comparando WordPress frente a Joomla y Drupal.
 
| Criterio | WordPress | Joomla | Drupal |
|---|---|---|---|
| **Licenciamiento** | GPL, gratuito | GPL, gratuito | GPL, gratuito |
| **Comunidad/soporte** | Enorme, documentación abundante, muchos plugins de reservas | Grande, tercer CMS más usado, pero ecosistema de extensiones más pequeño que WordPress | Grande pero orientada a desarrolladores y proyectos enterprise/gobierno, menos enfocada en e-commerce |
| **Curva de operación** | Baja, perfecta para personal sin equipo técnico | Media, requiere entender su estructura de artículos, categorías y menús, más rígida que WordPress | Alta, requiere conocimientos técnicos serios (arquitectura de contenidos, módulos, a veces Drush/CLI) |
| **Límites conocidos** | Rendimiento con muchos plugins, requiere buena config de caché | No tiene un módulo de e-commerce/reservas tan maduro como WooCommerce, extensiones como VirtueMart o HikaShop son menos pulidas | No tiene e-commerce/reservas nativo, requiere Drupal Commerce y trabajo de desarrollo a medida; mantenimiento más costoso |
| **Motivo de descarte** | — | El caso de negocio necesita catálogo, cupos y venta directa; hacerlo funcionar en Joomla implica sumar extensiones de terceros poco integradas entre sí, agregando fragilidad sin beneficio real sobre WordPress | Drupal está pensado para sitios complejos con lógica de contenido avanzada, no para una tienda con reservas simple; usarlo exigiría un equipo de desarrollo dedicado, contradiciendo la necesidad de operación con personal sin equipo técnico |


**Justificación técnica de por que WordPress + Nginx**: 
- Nginx maneja mejor conexiones concurrentes con menos consumo de recursos que Apache, relevante porque el caso explícitamente menciona picos de tráfico en campañas de difusión (RNF de disponibilidad).
- WordPress + WooCommerce cubre en un solo stack: catálogo, pedidos, contenido (blog/páginas) y con un plugin adicional de reservas (a definir, ej. Amelia/Bookly) el flujo de talleres con cupos limitados.
- Al ser PHP + MySQL, es totalmente compatible con la arquitectura de referencia del enunciado (backend web + base de datos separada).

### 5.4 Diagrama de despliegue
- Archivo: `docs/entrega-1/diagrama-despliegue.png` / `docs/entrega-1/Diagrama de despliegue.md`
- Subred de infraestructura: `10.33.199.48/29` (red: .48 · gateway: .52 · broadcast: .55 · host usables: .49–.54)
- Dominio interno: `tas-06.arpa`

```mermaid
flowchart LR
    cliente(["Cliente"])

    subgraph PERIM["Nodo perimetral — 10.33.199.49 · ip pública 10.33.195.184"]
        direction LR
        dns(["DNS<br/>puerto 53"])
        nginx(["NGINX<br/>puerto 80"])
        dns -.->|flujo interno| nginx
    end

    subgraph CMS1["WordPress CMS 1 — 10.33.199.51<br/>ip pública 10.33.196.212"]
        cms1(["CMS<br/>puerto 80"])
    end

    subgraph CMS2["WordPress CMS 2 — 10.33.199.50"]
        cms2(["CMS<br/>puerto 80"])
    end

    subgraph DBSQL["MySQL — 10.33.199.53"]
        db(["DB<br/>puerto 3306"])
    end

    cliente -->|"http://tas-06.arpa/"| dns
    nginx -->|"http://10.33.199.51/"| cms1
    nginx -->|"http://10.33.199.50/"| cms2
    cms1 -->|"tcp://10.33.199.53"| db
    cms2 -->|"tcp://10.33.199.53"| db

    linkStyle 0 stroke:#2e9e3f,stroke-width:2px
    linkStyle 2,3,4,5 stroke:#2166ac,stroke-width:2px
```


**Tabla de puertos y flujos:**

| Origen          | Destino                                    | Puerto | Protocolo   | Propósito                                                                      |
| --------------- | ------------------------------------------ | ------ | ----------- | ------------------------------------------------------------------------------ |
| Cliente         | DNS (nodo perimetral, 10.33.195.184 / .49) | 53     | DNS/UDP-TCP | Resolución del dominio `tas-06.arpa`                                           |
| Cliente         | Nginx (mismo nodo perimetral, .49)         | 80     | HTTP/TCP    | Acceso público al sitio; DNS y Nginx corren en el mismo host (flujo interno)   |
| Nginx           | WordPress CMS 1 (10.33.199.51)             | 80     | HTTP/TCP    | Reenvío de tráfico por red privada (upstream 1)                                |
| Nginx           | WordPress CMS 2 (10.33.199.50)             | 80     | HTTP/TCP    | Reenvío de tráfico por red privada (upstream 2)                                |
| WordPress CMS 1 | MySQL DB (10.33.199.53)                    | 3306   | TCP         | Consultas a la base de datos, solo por red privada                             |
| WordPress CMS 2 | MySQL DB (10.33.199.53)                    | 3306   | TCP         | Consultas a la base de datos, solo por red privada                             |
| Administrador   | Nodo DNS/Nginx, CMS 1, CMS 2, DB           | 22     | SSH/TCP     | Administración remota nominativa (RNF-04), a implementar sobre las IP privadas |

### 5.5 Dimensionamiento y objetivos de servicio
| Indicador                  | Meta propuesta | Justificación                                                                                                |
| -------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------ |
| Disponibilidad mensual     | ≥ 99,5%        | Con dos backends WordPress detrás de Nginx, una caída de un CMS no debería tumbar el servicio completo       |
| Detección de falla crítica | ≤ 5 min        | Evita repetir el incidente de 2h sin diagnóstico que originó el proyecto                                     |
| RTO servicio web           | ≤ 60 min       | Campaña de difusión no puede quedar caída más de 1h sin impacto comercial                                    |
| RPO general                | ≤ 24 h         | Aceptable en operación normal; a mejorar durante campañas con backups más frecuentes de la BD (10.33.199.53) |
| Retención de respaldos     | ≥ 30 días      | Cubre detección tardía de errores; ya existe script de respaldo de BD (`octavio_bd_backup.sql`) como base    |

**Puntos únicos de falla identificados:**
-

**Plan de crecimiento:**
-

### 5.6 Modelo de acceso, seguridad y operación
- **Accesos remotos:** SSH por clave pública hacia las IP privadas de cada nodo (10.33.199.49/50/51/53), usuario nominativo por integrante, sin cuentas compartidas.
- **Gestión de secretos:** contraseñas y credenciales fuera del repositorio (ver `script_DB.md`, donde ya se sanitizó con `<hidden_password>`); usar variables de entorno o archivo `.env` ignorado por git.
- **Firewall / segmentación:** solo el nodo DNS/Nginx (10.33.199.49) expone el puerto 80/443 hacia la red pública, el puerto 3306 de la BD (10.33.199.53) se restringe únicamente a las IP privadas .50 y .51. 
- **Logs y monitorización (diseño):** logs de acceso/error de Nginx, logs de PHP-FPM en ambos backends, slow query log de MySQL.
- **Backup (diseño):** dump programado de la base de datos (ya existe script base `octavio_bd_backup.sql`) más respaldo de `wp-content` (archivos/media) de ambos backends.
- **Respuesta a incidentes (diseño):**  detectar → contener → diagnosticar → corregir → validar → documentar → revertir

### 5.7 Plan de implementación por etapas

| Etapa     | Entregable                                                                                            | Pruebas previstas                                                                         | Responsable(s) |
| --------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | -------------- |
| Entrega 2 | WordPress + Nginx + PHP-FPM + MySQL funcionando en un primer nodo (según `script_cms.md`)             | Resolución DNS de `tas-06.arpa`, acceso HTTP, flujo de compra/reserva end-to-end          |                |
| Entrega 3 | Segundo backend WordPress (10.33.199.50) + balanceo real vía Nginx upstream + persistencia compartida | Distribución de tráfico entre CMS 1 y CMS 2, retiro de un backend, prueba de persistencia |                |
| Entrega 4 | Monitoreo, alertas y backups automatizados con restauración medida                                    | Degradación controlada, alerta recibida, restauración con RPO/RTO real                    |                |
| Entrega 5 | Incidente no anunciado + auditoría final                                                              | Recuperación validada, defensa individual                                                 |                |
### 5.8 Evidencias mínimas — checklist

- [x] Matriz requisito → componente → prueba → evidencia
- [ ] Diagrama legible y tabla de flujos/puertos
- [ ] Registro de decisiones de arquitectura (mínimo 2 alternativas comparadas)
- [ ] Inventario preliminar de VMs, CPU, RAM, disco, redes y dependencias
- [ ] Riesgos priorizados y tratamiento propuesto

---

## 6. Inventario preliminar de infraestructura

| VM/Host | Rol | CPU | RAM | Disco | Red | Dependencias |
|---|---|---|---|---|---|---|
| | | | | | | |

---

## 7. Riesgos

| Riesgo | Probabilidad | Impacto | Tratamiento propuesto |
|---|---|---|---|
| | | | |

---

## 8. Registro de decisiones de arquitectura (ADR)

Cada decisión relevante se documenta en `decisiones/ADR-XXX-titulo.md` con este formato mínimo:

```
# ADR-XXX: Título de la decisión

## Contexto
## Opciones consideradas
## Decisión
## Consecuencias
```

---

## 9. Bitácora de contribuciones por integrante

| Fecha | Integrante | Actividad | Entrega asociada |
|---|---|---|---|
| | | | |

---

## 10. Uso de inteligencia artificial

> Registro obligatorio según normativa del proyecto. Detalle en `bitacora/uso-ia.md`.

| Herramienta | Propósito | Fragmento relevante | Validación realizada | Cambios aplicados |
|---|---|---|---|---|
| | | | | |

_Nota: la respuesta de una IA no constituye evidencia técnica. Todo código o comando debe poder ser explicado por cualquier integrante del equipo._

---

## 11. Cómo reproducir / levantar el entorno

> _Se completa a partir de la Entrega 2 en adelante, cuando exista implementación._

---

## 12. Licencia / uso académico

Proyecto desarrollado con fines académicos para EIN-090B, Universidad Técnica Federico Santa María.
