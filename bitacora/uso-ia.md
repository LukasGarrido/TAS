# ERMITIDO CON TRAZABILIDAD

## Propósito
Documentar el uso de IA generativa en el proyecto, garantizando trazabilidad y validación de cada salida.

## Herramientas / Agentes de IA Utilizados
| Agente / Modelo             | Uso previsto                                    |
| --------------------------- | ----------------------------------------------- |
| `Claude sonnet5`            | `Ayuda con scripts, errores y análisis de logs` |
| `Gemini 36 flash - 3.1 pro` | `Redacción y corrección de faltas ortográficas` |
| `Antigravity IDE`           | `Estrutura y orden de directorios y ficheros`   |

## Registro de Uso
- **Fecha:** `<YYYY-MM-DD>`
- **Actividad:** `<Descripción de la actividad>`
- **Entrada a la IA:** `<Prompt o datos de entrada>`
- **Salida generada:** `<Resumen de la salida>`
- **Validación:** `<Cómo se validó la salida>`
- **Decisión:** `<Resultado o acción tomada>`
## Evidencia Técnica
> La respuesta de la IA *no* constituye evidencia técnica por sí sola. Se debe complementar con pruebas, revisiones y documentación adicional.> 

## Asistencia de Antigravity (Estructuración de Directorios y Ficheros)

- **Fecha:** 2026-09-09
- **Actividad:** Ayuda para estructurar los directorios y ficheros del proyecto TAS.
- **Entrada a la IA:** Solicitud de organizar la estructura del proyecto, incluyendo carpetas `bitacora`, `src`, etc.
- **Salida generada:** Propuesta de árbol de directorios y descripción de cada carpeta y archivo relevante.
- **Validación:** Revisada y aceptada por lukas
- **Decisión:** Adoptar la estructura propuesta por el agente, como base del proyecto.

## Asistencia de Claude (copia de base de datos de VM octavio a VM lukas)

- **Fecha:** 2026-09-09
- **Actividad:** Copiar la base de datos de WordPress (VM `octavio`) hacia la VM `lukas`, para que esta última sea la unica fuente de verdad, separando la dependencia entre ambas VMs.
- **Entrada a la IA:** Guía de comandos para crear la base y el usuario local en `lukas`(VM), importar el dump `octavio_bd_backup.sql` provisto por el usuario, y verificar las tablas importadas.
- **Salida generada:** Script SQL (`CREATE DATABASE`, `CREATE USER`, `GRANT`) e instrucciones de importación (`mysql ... < octavio_bd_backup.sql`).
- **Validación:** Se ejecuto `SHOW TABLES;` sobre `octavio_bd`, lo que nos confirmo la presencia de las 12 tablas esperadas desde la VM`octavio`  (`wp_posts`, `wp_options`, `wp_users`, etc.).
- **Decisión:** Se aceptó y ejecutó el script.

## Asistencia de Claude (acceso remoto a la base de datos desde la VM del CMS)

- **Fecha:** 2026-09-10
- **Actividad:** Habilitar que la VM del CMS WordPress (`octavio`, IP `10.33.199.51`) pueda conectarse remotamente a la base `octavio_bd` en la VM `lukas` (IP `10.33.199.53`), 
- **Entrada a la IA:**  Crear un usuario de base de datos con permisos de conexión remota, y verificar la conectividad extremo a extremo.
- **Salida generada:** Script SQL `CREATE USER 'octavio'@'10.33.199.51' ... GRANT ALL PRIVILEGES`, verificación de `ufw` (inactivo, sin reglas adicionales necesarias) y comando de prueba de conexión (`mysql -h 10.33.199.53 -u octavio -p octavio_bd`) a ejecutar desde la VM `octavio`.
- **Validación:** Prueba de conexión desde la VM `octavio` , validando con  `SHOW TABLES;` 
- **Decisión:**  Se aceptaron los scripts