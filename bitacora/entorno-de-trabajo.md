# Entorno de Trabajo del Proyecto

---

## Descripción General

Este documento describe los sistemas y herramientas de edición, documentación y asistencia inteligente que seleccionamos como equipo utiliza para trabajar en el proyecto. Abarca los entornos desde los cuales se redacta, documenta y gestiona el código y la documentación del repositorio.

---

## Sistemas de Trabajo

### 1. Antigravity IDE

| Campo                | Detalle                                                    |
| -------------------- | ---------------------------------------------------------- |
| **Tipo**       | IDE con agente de IA integrado (Google DeepMind)           |
| **Versión**   | Antigravity IDE (AGY)                                      |
| **Propósito** | Desarrollo asistido por IA, gestión de archivos y scripts |
| **Modelos IA** | Claude Sonnet, Gemini Flash/Pro (seleccionables)           |
| **Plataforma** | Windows (escritorio local)                                 |

#### ¿Qué hacemos con él?

- Estructurar y crear directorios y ficheros del repositorio.
- Generar y revisar scripts Bash, SQL y de configuración.
- Redactar y corregir documentación Markdown con asistencia del agente.
- Ejecutar comandos de PowerShell directamente desde el IDE.
- Registrar y trazabilizar el uso de IA (ver [`uso-ia.md`](uso-ia.md))

---

### 2. Obsidian

| Campo                | Detalle                                               |
| -------------------- | ----------------------------------------------------- |
| **Tipo**       | Editor de notas y documentación basado en Markdown   |
| **Versión**   | Obsidian (versión de escritorio)                     |
| **Propósito** | Documentación, bitácora y gestión del conocimiento |
| **Plataforma** | Windows (escritorio local)                            |
| **Vault**      | Directorio raíz del proyecto (`TAS/`)              |

#### ¿Qué hacemos con él?

- Escribir y revisar los archivos `.md` del repositorio (bitácoras, ADRs, informes).
- Navegar la estructura del proyecto mediante el panel de archivos y el grafo de vínculos.
- Vincular documentos entre sí usando la sintaxis `[[nombre-archivo]]` de Obsidian.
- Revisar previsualizaciones de tablas, diagramas y listas antes de hacer commit.

#### Configuración del vault

El vault de Obsidian apunta directamente a la carpeta raíz del proyecto `TAS/`. Esto significa que **todos los archivos `.md` del repositorio son visibles y editables** desde Obsidian sin configuración adicional. La carpeta `.obsidian/` (configuración interna) está presente en el repositorio.

---

### 3. Proxmox VE

| Campo                | Detalle                                                 |
| -------------------- | ------------------------------------------------------- |
| **Tipo**       | Hipervisor de virtualización (bare-metal)              |
| **Versión**   | Proxmox Virtual Environment (PVE)                       |
| **Propósito** | Alojar y gestionar las máquinas virtuales del proyecto |
| **Plataforma** | Servidor del laboratorio (infraestructura compartida)   |

#### ¿Qué hacemos con él?

- Crear, iniciar, detener y clonar las VMs del proyecto (ej. VM `lukas`, VM `octavio`).
- Asignar recursos de cómputo: vCPUs, RAM y almacenamiento a cada VM.

---



## Flujo de Trabajo Típico

```
Obsidian                    Antigravity IDE              Git (terminal)
──────────────              ───────────────              ──────────────
Redactar / editar .md  ──▶  Revisar / generar scripts ──▶  git add / commit / push
Enlazar documentos          Ejecutar comandos PowerShell    Sincronizar con remoto
Revisar previsualización    Validar salidas de IA
```

1. **Obsidian** se usa para la edición y organización de la documentación.
2. **Antigravity IDE** se usa para la parte técnica: scripts, comandos y asistencia IA.
3. **Git** (desde terminal o desde el IDE) se usa para versionar y publicar los cambios.

---

## Consideraciones

- Ambas herramientas trabajan sobre los **mismos archivos** del repositorio local, por lo que los cambios hechos en una se reflejan inmediatamente en la otra.
- El repositorio Git es la fuente de verdad.
- El uso de IA dentro del IDE está documentado y trazabilizado en [`uso-ia.md`](uso-ia.md).
