# Nodo Sur — Plataforma digital resiliente

**Asignatura:** EIN-090B · Taller de Administración de Sistemas
**Proyecto integrador 2026**
**Grupo:** 6
**Paralelo:** 701

**Integrantes:**
- JoseCarlos Vidal
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

### 5.3 Selección de CMS y suite

| Criterio | Opción elegida | Alternativa descartada 1 | Alternativa descartada 2 |
|---|---|---|---|
| Licenciamiento | | | |
| Comunidad/soporte | | | |
| Curva de operación | | | |
| Límites conocidos | | | |
| **Motivo de descarte** | — | | |

### 5.4 Diagrama de despliegue
- Archivo: `docs/entrega-1/diagrama-despliegue.png`
- Tabla de puertos y flujos:

| Origen | Destino | Puerto | Protocolo | Propósito |
|---|---|---|---|---|
| | | | | |

### 5.5 Dimensionamiento y objetivos de servicio

| Indicador | Meta propuesta | Justificación |
|---|---|---|
| Disponibilidad mensual | ≥ 99,5% | |
| Detección de falla crítica | ≤ 5 min | |
| RTO servicio web | ≤ 60 min | |
| RPO general | ≤ 24 h | |
| Retención de respaldos | ≥ 30 días | |

**Puntos únicos de falla identificados:**
-

**Plan de crecimiento:**
-

### 5.6 Modelo de acceso, seguridad y operación
- **Accesos remotos:**
- **Gestión de secretos:**
- **Firewall / segmentación:**
- **Logs y monitorización (diseño):**
- **Backup (diseño):**
- **Respuesta a incidentes (diseño):**

### 5.7 Plan de implementación por etapas

| Etapa | Entregable | Pruebas previstas | Responsable(s) |
|---|---|---|---|
| Entrega 2 | | | |
| Entrega 3 | | | |
| Entrega 4 | | | |
| Entrega 5 | | | |

### 5.8 Evidencias mínimas — checklist

- [ ] Matriz requisito → componente → prueba → evidencia
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