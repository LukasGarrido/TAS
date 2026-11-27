<div align="center">

# Guía de Preparación de la Defensa — Nodo Sur

**Asignatura:** EIN-090B · Taller de Administración de Sistemas (TAS) · Grupo 06 (`tas-06`)
**Integrantes:** Josecarlos Vidal · Octavio Valencia · Lukas Garrido

</div>

---

## 0. Cómo usar este documento

La defensa es una **demostración en vivo** en seis etapas. Cada sección siguiente corresponde a una etapa e incluye: qué mostrar, comandos listos para ejecutar, la evidencia mínima y las preguntas probables.

Los comandos están basados en la documentación del repositorio. Lo que **no está documentado o no existe todavía** está marcado como `[CONFIRMAR]` o listado en la sección 8 (pendientes previos a la defensa).

> **Diferencia con el enunciado:** el enunciado habla de HAProxy como punto de entrada. Nuestro punto de entrada es **Nginx** en el nodo perimetral (ADR-002). Donde la rúbrica diga "si la IP corresponde a HAProxy", nosotros debemos decir "la IP corresponde a Nginx, que cumple el rol de punto de entrada y balanceador".

---

## 1. Datos de referencia (tener a mano)

| VM (hostname real) | Alias | IP privada | IP pública | Servicios |
|---|---|---|---|---|
| `tas-06-jose` | `dns` / nodo perimetral | `10.33.199.49` | `10.33.195.184` | BIND9 (:53), Nginx (:80/:443), `nginx-exporter` (:9113), bastión SSH, `pull-db.sh` |
| `tas-06-02` | `cms-1` | `10.33.199.51` | `10.33.195.212` | WordPress (:8080), `apache-exporter` (:9117) |
| `tas-06-cms-02` | `cms-2` | `10.33.199.50` | `10.33.195.193` | WordPress (:8080), `apache-exporter` (:9117) |
| `tas-06-lukas` | `db` | `10.33.199.53` | `10.33.195.178` | MariaDB 11 en contenedor `mariadb` (:3306), NFS (:2049), `mysqld-exporter` (:9104) |
| `tas-06-monitor` | `monitor` | `10.33.199.52` | `10.33.195.245` | Prometheus (:9090), Alertmanager (:9093), Loki (:3100), Grafana (:3000) |

- **Dominio:** `tas-06.arpa` (HTTPS con certificado firmado por OpenSSL; HTTP redirige a HTTPS).
- **Subred:** `10.33.199.48/29`.
- **Acceso a la BD por SSH:** solo desde el `.49` (salto): `ssh -J usuario@10.33.195.184 usuario@10.33.199.53`.
- **Directorios de trabajo:** CMS en `/opt/cms`, monitoreo en `/opt/nodo-sur-monitoring`.
- **Zonas horarias (ojo en la defensa):** VM `db` en hora de Chile (UTC-3); nodo perimetral `.49` y contenedores en UTC. Al leer marcas de tiempo, decir siempre en qué zona están.
- **Diagrama:** [Diagrama de despliegue](E01/Diagrama%20de%20despliegue.md).

---

## 2. Preparación previa (el día anterior y 30 min antes)

### 2.1 Checklist

- [ ] Todas las VM encendidas y accesibles por SSH (bastión `.49`).
- [ ] Cliente de demostración definido, con su DNS apuntando a `10.33.199.49` (o entrada en `hosts` si va por VPN, ver 3.4).
- [ ] Cada integrante tiene su pestaña de terminal abierta en la VM que le toca.
- [ ] Grafana abierto con los dashboards de servicios (`nodo-sur-overview`) y de máquinas (`nodo-sur-maquinas`); Alertmanager (`:9093`), Loki (Explore en Grafana) y el canal de alertas de Discord abiertos. Acceso por túnel SSH (los puertos no son públicos).
- [ ] **Respaldo reciente identificado** (ver 5.1). Los dumps automáticos son cada 2 días a las 02:30 (hora Chile); hoy el automático corre el **24/nov**, pero un dato creado después no estaría en él, por eso se hace un respaldo manual.
- [ ] **Dato de prueba creado antes del respaldo** (ver 5.1).
- [ ] Reglas de alerta cargadas (17) y envío a Discord probado ese mismo día (ver [Configurar alertas](../configurations/configurar-alertas.md)).
- [ ] Relojes sincronizados: `chronyc tracking` y `date` en todos los nodos.
- [ ] Guion cronometrado y reparto de roles ensayado al menos una vez completa, **incluida la restauración con `time`**.

### 2.2 Operación de prueba del CMS (dependiente de la BD)

Se necesita una operación que falle cuando la BD está caída y que sirva para ver el dato restaurado. Opciones, de la más simple a la más visible:

1. **Consultar un producto de prueba** desde el navegador: `https://tas-06.arpa/?post_type=product&s=PRODUCTO-DEFENSA`.
2. **Crear un registro** (pedido/reserva de prueba o entrada en el panel `wp-admin`).
3. Por línea de comandos (para evidencia con marca de tiempo):

```sh
# Desde el cliente
curl -ksS -o /dev/null -w "%{http_code} %{time_total}s\n" "https://tas-06.arpa/?s=PRODUCTO-DEFENSA"
date -u
```

> Con la BD caída WordPress responde "Error establishing a database connection" (HTTP 500/503 según configuración). Anotar el código real durante el ensayo.

---

## 3. Etapa 1 — Servicios operativos

**Objetivo:** ubicar componentes en la topología, mostrar estado de servicios y ejecutar una operación del CMS que dependa de la BD.

### 3.1 Qué decir

Mostrar el diagrama de despliegue y recorrer el flujo: `Cliente → DNS (.49) → Nginx (.49) → cms-1 / cms-2 (:8080) → MariaDB (.53:3306)`, más NFS (`.53:2049`) para archivos compartidos y `monitor` (`.52`) consultando exporters.

### 3.2 Estado de los servicios (un comando por VM)

```sh
# Nodo perimetral (.49)
systemctl is-active named nginx          # en Ubuntu puede llamarse bind9: systemctl is-active bind9 nginx
ss -tlnp | grep -E ':(53|80|443|9113)\b'

# CMS 1 y CMS 2 (.51 y .50)
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
curl -sI http://localhost:8080 | head -1

# Base de datos (.53)
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker exec mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SELECT NOW(), @@hostname; SHOW DATABASES;"'
showmount -e localhost                    # exportación NFS

# Monitor (.52)
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

Además, en Prometheus (`:9090/targets`) todos los targets deben estar en **UP**: `node` (cinco VMs), `nginx-lb`, `bind9-dns`, `apache-wordpress`, `blackbox-wordpress`, `mariadb`, `prometheus`.

### 3.3 Operación funcional que depende de la BD

Ejecutar desde el **cliente** (no desde una VM del clúster), ver 2.2. Capturar: resultado en el navegador + salida de `curl`.

### 3.4 Nota de red

Desde la VPN institucional el nombre `tas-06.arpa` no resuelve por conflicto de sufijo de búsqueda. Solución usada en la bitácora: entrada en `hosts` del cliente (`10.33.195.184 tas-06.arpa`) y `curl -k` por el certificado autofirmado. **Para la etapa 2 hay que consultar al DNS directamente** (`dig @10.33.199.49` o `nslookup tas-06.arpa 10.33.199.49`), no confiar en el `hosts`.

### 3.5 Evidencia mínima

- [ ] Salida de estado de los servicios de cada VM.
- [ ] Captura/salida de la operación del CMS funcionando.

### 3.6 Preguntas probables

- ¿Qué pasa si cae `cms-1`? → Nginx lo marca caído por detección pasiva (`max_fails`/`fail_timeout`) y envía todo a `cms-2` (conmutación ≤ 30 s, RNF-01).
- ¿Por qué la BD está en una VM aparte y no expuesta? → RNF-02: puerto 3306 restringido con UFW y `DOCKER-USER`, solo `.50` y `.51` (y `.52` para el exporter).
- ¿Cómo comparten archivos los dos WordPress? → NFS en `.53:/srv/nfs/wordpress` montado como volumen Docker (RNF-03).

---

## 4. Etapa 2 — Registro A del DNS

**Objetivo:** mostrar el registro A, consultarlo desde un cliente, explicar a qué componente pertenece la IP y abrir el CMS por nombre.

### 4.1 Configuración del registro (en `.49`)

```sh
# Ubicar la zona y mostrar el registro A
sudo grep -rn "tas-06" /etc/bind/ | head
sudo cat /etc/bind/db.tas-06.arpa        # [CONFIRMAR] nombre real del archivo de zona
sudo named-checkconf && sudo named-checkzone tas-06.arpa /etc/bind/db.tas-06.arpa
```

Lo esperado en la zona (verificar contra el archivo real): un registro A cuyo nombre `tas-06.arpa` (o `www`) apunta a `10.33.199.49`.

### 4.2 Consulta desde el cliente

```sh
# Linux / macOS / Git Bash
dig @10.33.199.49 tas-06.arpa A +noall +answer +stats

# Windows (PowerShell)
nslookup tas-06.arpa 10.33.199.49
Resolve-DnsName tas-06.arpa -Server 10.33.199.49 -Type A
```

Y abrir el CMS por nombre:

```sh
curl -kvI https://tas-06.arpa 2>&1 | grep -E "Connected to|HTTP/|subject:|issuer:"
```

### 4.3 Qué explicar

- La IP devuelta, `10.33.199.49`, es el **nodo perimetral**. Ahí corre **Nginx**, que es el punto de entrada único: termina TLS, redirige HTTP→HTTPS y balancea por round-robin hacia `cms-1` y `cms-2`. (En la referencia del enunciado ese rol lo cumple HAProxy; nosotros usamos Nginx por ADR-002, con detección pasiva en lugar de health checks activos.)
- El DNS (BIND9) y Nginx comparten VM: es un **punto único de falla** conocido (ver riesgos).
- La recursión de BIND está restringida a la subred `10.33.199.48/29`.
- Un dominio `.arpa` no puede validarse con CA pública, por eso el certificado lo firmamos con OpenSSL.

### 4.4 Evidencia mínima

- [ ] Archivo de zona con el registro A.
- [ ] Salida de `dig`/`nslookup` apuntando al DNS del proyecto.
- [ ] Acceso al CMS por nombre (navegador o `curl`).

---

## 5. Etapa 3 — Observabilidad e incidente

**Objetivo:** mostrar señales normales, provocar una falla controlada de la BD, repetir la operación y localizar en métricas, logs y alertas qué cambió y cuándo.

### 5.0 Señales en estado normal (antes de la falla)

Mostrar y **anotar la hora** (con zona):

| Señal | Dónde | Valor normal |
|---|---|---|
| `mysql_up` | Grafana / Prometheus (`mysql_up{job="mariadb"}`) | `1` |
| Conexiones/consultas de MariaDB | Dashboard MariaDB | Actividad estable |
| Targets | Prometheus `:9090/targets` | Todos UP |
| Códigos HTTP de Nginx | Dashboard Nginx / logs | 200 |
| Logs | Loki en Grafana Explore | Sin errores de BD |
| Alertas | Alertmanager `:9093` y canal de Discord | Sin alertas activas |

### 5.1 Preparación del dato de prueba y del respaldo (**antes** de la falla)

Se hace una vez, minutos antes de iniciar la demostración, y se explica al evaluador:

```sh
# En la VM db (.53), como root. 1) Crear el dato de prueba
docker exec mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" mydb -e "
  CREATE TABLE IF NOT EXISTS defensa_test (id INT PRIMARY KEY AUTO_INCREMENT, texto VARCHAR(100), creado DATETIME DEFAULT NOW());
  INSERT INTO defensa_test (texto) VALUES (\"DATO-DEFENSA-2026\");
  SELECT * FROM defensa_test;"'

# 2) Respaldo manual identificado (usa el mismo script del cron)
/usr/local/bin/backup-db.sh
tail -3 /var/log/backup-db.log
ls -lh /home/database/backups | tail -4
cd /home/database/backups && sha256sum -c $(ls -t *.sha256 | head -1)
```

Anotar el **nombre del archivo** (`mariadb_all_AAAA-MM-DD_HHMMSS.sql.gz`) y su fecha. También verificar que el `.49` lo trae: `~/pull-db.sh && ls -lh ~/db | tail -3`.

> Si se prefiere no tocar la base real, el dato de prueba puede crearse en la copia de evaluación (ver 6.2).

### 5.2 Falla controlada (momento acordado con el evaluador)

```sh
# En la VM db (.53). Anotar la hora justo antes y justo después
date '+%F %T %Z'
docker stop mariadb
date '+%F %T %Z'
```

Opcional, para que la restauración tenga sentido (el dato "desaparece"):

```sh
# Solo si se levanta la BD de nuevo antes de restaurar, simular pérdida del dato:
docker start mariadb
docker exec mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" mydb -e "DELETE FROM defensa_test;"'
```

> Alternativa más limpia: dejar la BD detenida durante el diagnóstico y, al restaurar, usar una copia de evaluación donde el dato **no** existe antes (ver 6.2).

### 5.3 Repetir la operación del CMS (debe fallar)

```sh
curl -ksS -o /dev/null -w "%{http_code} %{time_total}s\n" "https://tas-06.arpa/?s=PRODUCTO-DEFENSA"
date -u
```

Evidencia: código HTTP de error / mensaje "Error establishing a database connection", con hora.

### 5.4 Localizar qué cambió y cuándo

| Fuente | Qué buscar | Cómo |
|---|---|---|
| **Métricas** | `mysql_up` pasa de 1 a 0; target `mariadb` DOWN | Grafana/Prometheus, ajustar el rango a ±10 min |
| **Métricas** | Aumento de 5xx en Nginx / `blackbox-wordpress` en `probe_success = 0` | Dashboard Nginx / WordPress |
| **Logs** | Errores de conexión a la BD en los WordPress; 5xx en el access log de Nginx; log de Docker de `mariadb` mostrando el apagado | Loki en Grafana Explore (filtrar por host y por texto `database`/`error`) |
| **Alertas** | `MariaDBCaida` activa en Alertmanager (`:9093`) con `startsAt`, y mensaje en Discord | Alertmanager UI y Discord |

Consultas útiles:

```promql
mysql_up{job="mariadb"}
up{job="mariadb"}
probe_success
sum(rate(nginx_http_requests_total[1m]))
```

```sh
# En db: ver cuándo se detuvo el contenedor
docker inspect -f '{{.State.Status}} {{.State.FinishedAt}}' mariadb
docker logs --tail 30 mariadb
# En .49 (Nginx): errores recientes
sudo tail -20 /var/log/nginx/error.log; sudo tail -20 /var/log/nginx/access.log
```

### 5.5 Diagnóstico a explicar

1. El cliente recibe error → el fallo está **detrás** de Nginx (Nginx y DNS responden).
2. Los dos WordPress fallan por igual → no es un nodo CMS, es el componente compartido.
3. `mysql_up = 0` desde `HH:MM:SS` y `docker inspect` confirma que el contenedor está detenido → causa raíz: **MariaDB detenida**.
4. NFS y los demás exporters siguen UP → el impacto está acotado a la BD.

### 5.6 Evidencia mínima

- [ ] Prueba fallida desde el cliente (con hora).
- [ ] Gráfico de métricas con el cambio y hora.
- [ ] Logs con marcas de tiempo.
- [ ] Alerta activa y mensaje recibido en Discord, con hora (si no llega, ver sección 10).

### 5.7 Preguntas probables

- ¿Cuánto tardó la alerta en dispararse y por qué? → depende de `scrape_interval` (30 s), `evaluation_interval` (30 s) y `for:` de la regla (1 min en `MariaDBCaida`), más `group_wait` (10 s) de Alertmanager. RNF-05 exige ≤ 5 min.
- ¿Por qué el balanceador no ayuda aquí? → El balanceo protege la capa web, no la BD; la BD es un punto único de falla (RNF-02 solo la aísla, no la replica).
- ¿Qué diferencia hay entre una alerta de métrica y un log? → La métrica dice *que* algo cambió y *cuándo*; el log explica *por qué*.

---

## 6. Etapa 4 — Restauración de datos

**Objetivo:** tras diagnosticar y estabilizar, restaurar desde un respaldo identificado y demostrar que un dato ausente reaparece.

### 6.1 Estabilizar el motor

```sh
# En db (.53)
docker start mariadb
docker ps --filter name=mariadb
docker logs --tail 20 mariadb
docker exec mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SELECT 1;"'
```

### 6.2 Identificar el respaldo

```sh
# En db (.53)
ls -lh /home/database/backups | tail -6
cd /home/database/backups
R=mariadb_all_AAAA-MM-DD_HHMMSS.sql.gz          # <-- el respaldo identificado en 5.1
sha256sum -c $R.sha256                           # integridad (debe decir OK)
gzip -t $R && echo "gzip OK"
stat -c '%y %s bytes' $R                         # fecha del respaldo
```

Mostrar también que existe la copia externa en el `.49` (`ls -lh ~/db`), que es la razón de ser de RNF-06.

### 6.3 Comprobar el dato **antes**

```sh
docker exec mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" mydb -e "SELECT * FROM defensa_test;"'
# Esperado: tabla vacía o inexistente (ERROR 1146)
```

### 6.4 Restaurar

**Opción A (recomendada para la rúbrica): copia de evaluación en contenedor aparte**, tal como está en `configurations/respaldos-mariadb.md` sección 7. No toca producción y mide el tiempo (RNF-06: ≤ 60 min):

```sh
free -m
docker run -d --name mdb-eval -e MARIADB_ROOT_PASSWORD=<clave_de_prueba> mariadb:11
sleep 15
docker exec mdb-eval mariadb -uroot -p<clave_de_prueba> -e "SELECT 1;"

time (gunzip -c /home/database/backups/$R \
  | docker exec -i mdb-eval mariadb -uroot -p<clave_de_prueba>)

docker exec mdb-eval mariadb -uroot -p<clave_de_prueba> -e \
  "SHOW DATABASES; SELECT COUNT(*) AS tablas FROM information_schema.tables WHERE table_schema='mydb'; SELECT * FROM mydb.defensa_test;"
```

Resultado esperado: aparecen `mydb` y `mysql`, `mydb` con ~52 tablas, y la fila `DATO-DEFENSA-2026`.

**Opción B: restaurar sobre el motor del entorno de evaluación** (si el evaluador quiere ver el CMS recuperarse con la BD real):

```sh
time (gunzip -c /home/database/backups/$R \
  | docker exec -i mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD"')
```

El dump incluye `DROP TABLE IF EXISTS` / `CREATE TABLE`, por lo que sobrescribe las tablas. **Solo usar B en el entorno de evaluación**, nunca en producción real, y consultar al docente cuál opción espera. `[CONFIRMAR]`

### 6.5 Comprobar el dato **después**

```sh
docker exec mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" mydb -e "SELECT * FROM defensa_test;"'
# Esperado (opción B): la fila DATO-DEFENSA-2026 reaparece
```

### 6.6 Evidencia mínima

- [ ] Nombre y fecha del respaldo, checksum OK.
- [ ] Resultado de la restauración (y salida de `time`).
- [ ] Consulta del dato **antes** (ausente) y **después** (presente).

### 6.7 Preguntas probables

- ¿Cuánto dato podrían perder? → RPO: hasta 2 días (frecuencia del dump). Por eso el respaldo manual previo a la defensa.
- ¿Y si se pierde la VM `db` entera? → La copia externa en `.49:~/db` con retención de 30 días y checksum verificado.
- ¿Por qué el `.49` "jala" y la BD no "empuja"? → Si la BD se compromete no tiene credenciales para borrar la copia externa. Llave dedicada con `from=` y `restrict`.
- ¿Por qué `--single-transaction`? → Dump consistente de InnoDB sin bloquear tablas.
- ¿Qué no cubre el respaldo? → Los archivos del NFS y la configuración (`wp-config.php`, compose, `nginx.conf`) no están en el dump de la BD. `[CONFIRMAR]` si hay respaldo aparte.

---

## 7. Etapas 5 y 6 — Validación final y defensa individual

### 7.1 Etapa 5: Validación final

Repetir **exactamente** lo de la etapa 1 (misma operación, mismo comando):

```sh
# Desde el cliente, por nombre
curl -ksS -o /dev/null -w "%{http_code} %{time_total}s\n" "https://tas-06.arpa/?s=PRODUCTO-DEFENSA"
date -u
```

| Verificación | Esperado |
|---|---|
| CMS accesible por nombre | HTTP 200 por `https://tas-06.arpa` |
| Operación que falló | Funciona de nuevo |
| Dato restaurado | `SELECT * FROM defensa_test;` devuelve la fila |
| Métricas | `mysql_up = 1`, targets UP, 5xx de Nginx vuelve a 0 |
| Alerta | Pasa a *resolved* en Alertmanager (`endsAt`) y llega el aviso `RESOLVED` a Discord |
| Logs | Se ve el reinicio de MariaDB y el retorno de 200 |

Cerrar con una **línea de tiempo** del incidente (en un solo slide o en la terminal):

| Hora | Evento |
|---|---|
| HH:MM:SS | Estado normal verificado |
| HH:MM:SS | `docker stop mariadb` |
| HH:MM:SS | Primer error en el cliente |
| HH:MM:SS | `mysql_up = 0` / alerta *firing* |
| HH:MM:SS | Diagnóstico: contenedor detenido |
| HH:MM:SS | `docker start mariadb` / inicio de restauración |
| HH:MM:SS | Fin de restauración (duración: `time`) |
| HH:MM:SS | Operación OK y alerta *resolved* |

### 7.2 Etapa 6: Defensa individual (reparto sugerido)

Cada integrante **ejecuta o interpreta una prueba** y responde **una pregunta**. Acordar quién hace qué antes de la defensa (ajustar según roles reales):

| Integrante | Prueba que ejecuta/interpreta | Tema de la pregunta |
|---|---|---|
| Josecarlos Vidal | Registro A, `dig`, Nginx/TLS, flujo de entrada (nodo perimetral) | Arquitectura de red, DNS, balanceo, ADR-002 |
| Octavio Valencia | Falla controlada y lectura de métricas/logs/alertas en Grafana, Loki, Alertmanager | Incidente, observabilidad, RNF-05/08 |
| Lukas Garrido | Restauración desde el respaldo, verificación del dato, cron y copia externa | Recuperación, RPO/RTO, RNF-06 |

> `[CONFIRMAR]` el reparto real; los nombres de VM (`jose`, `lukas`, `octavio`) sugieren responsabilidades pero hay que validarlas con el equipo.

**Banco de preguntas de riesgo** (todos deben poder responder al menos las de su área):

- ¿Cuál es el principal punto único de falla de la solución y cómo lo mitigarían? (BD única; nodo perimetral con DNS+Nginx.)
- ¿Por qué Nginx y no HAProxy? ¿Qué se pierde? (Health checks activos y panel de estadísticas.)
- ¿Qué verifica RNF-05 y cómo se mide? ¿Cumple hoy? (Ver sección 8.)
- ¿Qué riesgo tiene que las zonas horarias difieran entre VM y contenedores? (Correlación de logs, RNF-08.)
- ¿Qué expone cada exporter y cómo se limita? (UFW/origen `10.33.199.52`; `mysqld-exporter` escucha en `0.0.0.0:9104`, ver riesgos. En `dns` UFW está inactivo y `node_exporter` escucha solo en la IP privada.)
- ¿Qué pasa con los respaldos si el cron falla en silencio? (Hoy solo hay logs; no hay alerta de respaldo faltante.)
- ¿Cómo se restaura un nodo CMS? (Docker + compose + `wp-config.php` por NFS + montaje NFS: [reproducción del entorno](reproduccion-entorno.md).)

---

## 8. Pendientes y brechas antes de la defensa

Estos puntos salen de contrastar la rúbrica con lo documentado en el repositorio. Son los que más pueden romper la demostración.

| # | Brecha | Por qué importa | Acción |
|---|---|---|---|
| 1 | **Tiempo de detección sin medir**: las alertas llegan a Discord (probado deteniendo `node_exporter` en `cms-2`), pero no se cronometró ni se probó la caída de un servicio. | RNF-05 exige alerta en ≤ 5 min tras detener un backend. | Detener un backend y MariaDB, anotar hora de la falla, hora del mensaje y confirmar `RESOLVED`. |
| 2 | **UFW inactivo en `dns`**, aunque el README indica que está activo en las VMs. | Pregunta probable de seguridad; el nodo tiene la IP pública. | Activar UFW con las reglas de SSH, DNS, web y exporters, o corregir la documentación. |
| 3 | **Agente de logs hacia Loki no documentado** (Promtail/Alloy). | Sin él, no hay logs que mostrar de la caída. | Confirmar qué agente corre y qué etiquetas usa; probar una consulta LogQL de ensayo. |
| 4 | **Archivo de zona DNS** (ruta y contenido) no está en el repositorio. | Etapa 2 exige mostrar el registro A. | Documentar el archivo y dejar el `dig` de referencia en `configurations/`. |
| 5 | **Restauración "prevista, aún no probada"** según `respaldos-mariadb.md` sección 7. | Es la etapa con mayor riesgo de tiempo. | Ensayar completa antes, medir `time` y anotarlo. |
| 6 | **Dato de prueba y respaldo manual** no existen aún. | Sin ellos no hay "antes/después". | Ejecutar 5.1 el día de la defensa. |
| 7 | **Respaldo de archivos NFS y de configuración** pendiente. | Pregunta probable de RPO. | Declararlo como limitación o resolverlo. |
| 8 | **Health checks activos ausentes** (ADR-002). | Si cae un CMS, el primer usuario puede ver un error. | Mencionarlo como riesgo conocido. |
| 9 | **Zonas horarias mixtas** (Chile vs UTC). | Confunde la línea de tiempo del incidente. | Anotar siempre la zona; usar `date -u` en el cliente. |
| 10 | **Exporter en `0.0.0.0:9104`** en la VM `db`. | Posible pregunta de riesgo. | Tener respuesta: UFW solo permite `.52` en 9104. |

---

## 9. Guion sugerido con tiempos

| Min | Etapa | Responsable | Contenido |
|---|---|---|---|
| 0–4 | 1. Servicios operativos | Todos (reparto por VM) | Topología, estado de servicios, operación del CMS |
| 4–8 | 2. Registro A | Josecarlos | Zona, `dig`, explicación Nginx, acceso por nombre |
| 8–12 | 3a. Señales normales | Octavio | Grafana, Prometheus, Loki, Alertmanager |
| 12–16 | 3b. Falla y diagnóstico | Octavio | `docker stop mariadb`, prueba fallida, métricas/logs/alertas |
| 16–24 | 4. Restauración | Lukas | Estabilizar, identificar respaldo, restaurar, dato antes/después |
| 24–27 | 5. Validación final | Todos | Operación OK, dato, señales, línea de tiempo |
| 27+ | 6. Preguntas individuales | Cada integrante | Prueba + pregunta |

> Los tiempos son una propuesta; ajustar con el tiempo real asignado para la defensa. `[CONFIRMAR]`

---

## 10. Plan de contingencia durante la demo

| Si pasa... | Haz... |
|---|---|
| La alerta no llega | Mostrar la regla y su estado *pending/firing* en Prometheus (`/alerts`), consultar Alertmanager y sus registros (ver [diagnóstico](../configurations/configurar-alertas.md)). |
| `docker start mariadb` no levanta | `docker logs mariadb`; si el volumen está dañado, ir directo a la restauración en contenedor nuevo. |
| La restauración tarda más de lo esperado | Mostrar el avance (`SHOW PROCESSLIST;`) y comparar con el objetivo de RNF-06 (≤ 60 min). |
| `tas-06.arpa` no resuelve en el cliente | Usar `dig @10.33.199.49` para demostrar el DNS y la entrada en `hosts` para abrir el sitio (ver 3.4). |
| Falla el SSH al `.53` | Acceso por salto desde `.49` o consola de Proxmox. |
| El checksum no coincide | Usar la copia del `.49` (`~/db`) y explicar por qué existe la copia externa. |

---

## 11. Documentos de referencia

- [README](../README.md) — arquitectura, requerimientos y estado
- [Diagrama de despliegue](E01/Diagrama%20de%20despliegue.md)
- [Informe final](E05/G6_tas_NodoSur.md)
- [Respaldos de MariaDB](../configurations/respaldos-mariadb.md)
- [Configuración de la VM de monitoreo](../configurations/configurar-vm-monitoreo.md)
- [Configurar alertas](../configurations/configurar-alertas.md) · [Monitoreo de las máquinas](../configurations/configurar-grafana-maquinas.md)
- [Grafana + MariaDB](../configurations/configurar-grafana-mariadb.md), [Nginx](../configurations/configurar-grafana-nginx.md), [WordPress](../configurations/configurar-grafana-wordpress.md)
- [Riesgos](riesgos.md) · [Plan de implementación](plan-implementacion.md) · [Reproducción del entorno](reproduccion-entorno.md)
- [ADR-002: Nginx en vez de HAProxy](../decisions/ADR-002%20Nginx%20como%20balanceador%20en%20vez%20de%20HAProxy.md)
