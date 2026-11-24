# Respaldos automáticos de MariaDB: VM de base de datos y nodo perimetral

**Proyecto:** Nodo Sur · EIN-090B
**Requisito que cubre:** RNF-06 (respaldos verificados, retención ≥ 30 días, copia fuera del host de origen)

---

## 1. Resumen

El respaldo funciona en dos etapas, cada una en una máquina distinta:

| Etapa | Máquina | Qué hace | Cuándo |
|---|---|---|---|
| 1. Dump | `tas-06-lukas` (BD, 10.33.199.53) | Genera el respaldo de todas las bases, lo comprime y crea su checksum | 02:30 hora de Chile, días pares del mes |
| 2. Copia | `tas-06-jose` (nodo perimetral/DNS, 10.33.199.49) | Se conecta a la BD por SSH, trae los respaldos nuevos y verifica su checksum | 07:00 UTC (04:00 en Chile), todos los días |

```
   BD (.53)                                  Nodo perimetral (.49)
   ┌───────────────────────────┐             ┌──────────────────────────┐
   │ cron 02:30 (días pares)   │             │ cron 07:00 UTC (diario)  │
   │ backup-db.sh              │   scp/ssh   │ pull-db.sh               │
   │  └─ mariadb-dump + gzip   │ ◄────────── │  └─ trae lo nuevo        │
   │  └─ /home/database/backups│   (.49 → .53│  └─ verifica sha256      │
   │     retención 30 días     │    :22)     │  └─ ~/db, ret. 30 días   │
   └───────────────────────────┘             └──────────────────────────┘
```

**Por qué el nodo perimetral "jala" los respaldos y la BD no "empuja":**

- El firewall de la BD (ufw) solo acepta SSH entrante desde el .49, que es el modelo del README (el .49 es el bastión).
- Si la BD se compromete, no tiene credenciales para entrar al .49, así que la copia externa queda a salvo.
- No fue necesario abrir ninguna regla nueva en el firewall.

**Alcance:** este documento cubre solo la base de datos. El respaldo de los archivos del NFS y la prueba de restauración quedan pendientes (sección 8).

---

## 2. Parte 1: respaldo local en la VM de la base de datos (.53)

Todos los comandos de esta parte se ejecutaron como **root** en la VM `tas-06-lukas` (por consola de Proxmox o SSH con salto desde el .49).

### 2.1 Verificar el contenedor y la variable de la contraseña

```sh
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}'
docker exec mariadb env | grep -i root | cut -d= -f1
```

Salida:

```
mariadb                         mariadb:11      10.33.199.53:3306->3306/tcp
database-mysqld-exporter-1      prom/mysqld-exporter:v0.17.2    0.0.0.0:9104->9104/tcp, [::]:9104->9104/tcp
MARIADB_ROOT_PASSWORD
HOME
```

**Por qué:**

- Confirma el nombre real del contenedor (`mariadb`), que luego usa el script.
- Confirma que la contraseña de root está disponible como variable de entorno dentro del contenedor. El `cut -d= -f1` muestra solo el **nombre** de la variable y no su valor, para no exponer la contraseña en pantalla ni en el historial.
- `HOME` aparece solo porque su valor es `/root`, que contiene la palabra "root".

> Nota: el puerto 3306 solo escucha en `10.33.199.53`, pero el exporter de MySQL (9104) escucha en `0.0.0.0`. Ver pendientes (sección 8).

### 2.2 Probar la conexión a la base

```sh
docker exec mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES;"'
```

Salida:

```
Database
information_schema
mydb
mysql
performance_schema
sys
```

**Por qué:** la contraseña se lee desde **dentro** del contenedor (`$MARIADB_ROOT_PASSWORD`, entre comillas simples para que la expanda el contenedor y no el shell de la VM). Así no queda escrita en el script ni en el historial. Deben aparecer `mydb` (la base de WordPress) y `mysql` (usuarios y permisos).

### 2.3 Dump de prueba (sin tocar los respaldos reales)

```sh
docker exec mariadb sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --all-databases --single-transaction --routines --triggers --events' > /tmp/prueba.sql
tail -c 200 /tmp/prueba.sql
ls -lh /tmp/prueba.sql
rm /tmp/prueba.sql
```

Salida relevante:

```
-- Dump completed on 2026-11-10 13:07:04
-rw-r--r--    1 root     root        5.1M Nov 10 10:07 /tmp/prueba.sql
```

**Por qué:** valida que `mariadb-dump` funciona con las opciones definitivas antes de automatizar. La última línea `Dump completed` es la marca de que el dump terminó completo.

Opciones usadas:

| Opción | Motivo |
|---|---|
| `--all-databases` | Incluye `mydb` y `mysql` (usuarios y permisos) |
| `--single-transaction` | Dump consistente sin bloquear tablas InnoDB, para no frenar pedidos ni reservas mientras corre |
| `--routines --triggers --events` | Incluye procedimientos, disparadores y eventos |

**Hallazgo (zona horaria):** el dump registró `13:07:04`, pero el archivo en la VM marca `10:07`. El contenedor trabaja en UTC y la VM en hora de Chile (UTC-3). Es el mismo riesgo que el README ya anota en RNF-08 (zonas horarias distintas entre VM y contenedores). No rompe el respaldo, pero el script fija `TZ` para que nombres y logs usen hora de Chile.

### 2.4 Comprobar la zona horaria de la VM

```sh
date
TZ=America/Santiago date
```

Salida:

```
Tue Nov 10 10:08:19 -03 2026
Tue Nov 10 10:08:27 -03 2026
```

**Por qué:** si ambas salidas coinciden, la zona `America/Santiago` está disponible y el script puede usarla. Si la segunda saliera en UTC, habría que instalar `tzdata` (`apk add tzdata`).

### 2.5 Script de respaldo: `/usr/local/bin/backup-db.sh`

```sh
cat > /usr/local/bin/backup-db.sh <<'EOF'
#!/bin/sh
set -eu
export TZ=America/Santiago

CONTAINER="mariadb"
BACKUP_DIR="/home/database/backups"
RETENTION_DAYS=30
LOG="/var/log/backup-db.log"

TS=$(date +%F_%H%M%S)
BASE="mariadb_all_${TS}"
TMP="${BACKUP_DIR}/.${BASE}.sql.part"

log()  { echo "$(date '+%F %T') $*" >> "$LOG"; }
fail() { log "ERROR: $*"; rm -f "$TMP" "$TMP.gz"; exit 1; }

mkdir -p "$BACKUP_DIR"
log "Inicio $BASE"

docker exec "$CONTAINER" sh -c \
  'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --all-databases \
   --single-transaction --routines --triggers --events' > "$TMP" \
  || fail "mariadb-dump falló"

tail -c 300 "$TMP" | grep -q "Dump completed" || fail "dump incompleto"

gzip "$TMP" || fail "gzip falló"
gzip -t "${TMP}.gz" || fail "gzip corrupto"
mv "${TMP}.gz" "${BACKUP_DIR}/${BASE}.sql.gz"
( cd "$BACKUP_DIR" && sha256sum "${BASE}.sql.gz" > "${BASE}.sql.gz.sha256" )
chown database:database "${BACKUP_DIR}/${BASE}".*
chmod 640 "${BACKUP_DIR}/${BASE}".*
log "OK ${BASE}.sql.gz"

find "$BACKUP_DIR" -name 'mariadb_all_*' -mtime +"$RETENTION_DAYS" -delete
log "Fin"
EOF
chmod 755 /usr/local/bin/backup-db.sh
chown database:database /home/database/backups
chmod 750 /home/database/backups
```

**Por qué cada parte:**

| Parte | Motivo |
|---|---|
| `set -eu` | El script se detiene ante cualquier error o variable no definida |
| Archivo temporal `.part` | El respaldo solo recibe su nombre final si pasó todas las validaciones. Nunca queda uno a medias que parezca bueno |
| `grep "Dump completed"` | Detecta dumps cortados (disco lleno, contenedor detenido a mitad) |
| `gzip -t` | Comprueba que el comprimido no esté corrupto |
| `.sha256` | Permite verificar la integridad después, y en la copia externa |
| `chown database` + `chmod 640` | El archivo lo puede leer el usuario `database` (que usará el nodo perimetral) y nadie más. No se agregó `database` al grupo `docker`, porque equivale a darle root |
| Retención al final | Solo se borran respaldos viejos si el nuevo salió bien. Un fallo nunca deja la VM sin respaldos |
| Contraseña desde el contenedor | No aparece en el script, en el historial ni en el crontab |
| `export TZ` | Nombres de archivo y logs en hora de Chile (RNF-08) |

### 2.6 Prueba manual del script

```sh
sh -n /usr/local/bin/backup-db.sh && echo "sintaxis OK"
/usr/local/bin/backup-db.sh
tail /var/log/backup-db.log
ls -lh /home/database/backups
cd /home/database/backups && sha256sum -c *.sha256
```

Salida:

```
2026-11-10 10:10:10 Inicio mariadb_all_2026-11-10_101010
2026-11-10 10:10:11 OK mariadb_all_2026-11-10_101010.sql.gz
2026-11-10 10:10:11 Fin
...
-rw-r-----    1 database database    1.0M Nov 10 10:10 mariadb_all_2026-11-10_101010.sql.gz
-rw-r-----    1 database database     103 Nov 10 10:10 mariadb_all_2026-11-10_101010.sql.gz.sha256
mariadb_all_2026-11-10_101010.sql.gz: OK
```

**Por qué:** antes de programar nada hay que comprobar que funciona a mano. El dump de 5,1 MB se comprime a ~1 MB, el dueño es `database` y el checksum da `OK`.

### 2.7 Programar con cron

```sh
which flock || apk add util-linux
rc-update add crond default
rc-service crond start
rc-service crond status
```

Salida: `flock` ya existía (`/usr/bin/flock`), `crond` ya estaba en el runlevel `default` y en estado `started`.

Crontab de root (reemplazo completo, conservando las tareas estándar de Alpine):

```sh
cat <<'EOF' | crontab -
# do daily/weekly/monthly maintenance
# min   hour    day     month   weekday command
*/15    *       *       *       *       run-parts /etc/periodic/15min
0       *       *       *       *       run-parts /etc/periodic/hourly
0       2       *       *       *       run-parts /etc/periodic/daily
0       3       *       *       6       run-parts /etc/periodic/weekly
0       5       1       *       *       run-parts /etc/periodic/monthly

# Respaldo de MariaDB: 02:30, cada 2 dias
30 2 */2 * * flock -n /tmp/backup-db.lock /usr/local/bin/backup-db.sh
EOF
crontab -l
```

**Por qué:**

- Corre como **root** porque necesita ejecutar `docker exec`. El propio script entrega los archivos a `database`.
- `flock -n` evita que dos ejecuciones se pisen entre sí.
- Las líneas `run-parts` son las tareas estándar de Alpine y se conservan.
- Se corrigió un error inicial: se había dejado una línea con el texto literal `MM HH`, que es inválida en cron. Se reemplazó todo el crontab con el contenido de arriba.

**Hora y días:** `02:30` en hora de Chile, porque la VM tiene esa zona. La frecuencia de 2 días la decidió el equipo.

> **Aclaración sobre `*/2`:** en el día del mes, el cron de Alpine (BusyBox) lo interpreta como **días pares** (2, 4, 6... 30), no impares. Se comprobó con los respaldos reales, que son del 18, 20 y 22. Ocasionalmente, al cambiar de mes, pasan 3 días entre respaldos (por ejemplo del 30 al 2).

### 2.8 Resultado verificado

Respaldos generados automáticamente por cron:

```
mariadb_all_2026-11-18_023000.sql.gz   776.1K
mariadb_all_2026-11-20_023000.sql.gz   776.1K
mariadb_all_2026-11-22_023000.sql.gz   809.0K
```

---

## 3. Parte 2: acceso SSH del nodo perimetral a la BD

Para que el .49 pueda traer los respaldos necesita entrar por SSH a la BD con una llave dedicada y de alcance mínimo.

### 3.1 Firewall de la BD (ufw)

```sh
ufw status verbose
```

Salida:

```
Status: active
Default: deny (incoming), allow (outgoing), deny (routed)

22/tcp     ALLOW IN    10.33.199.49
3306/tcp   ALLOW IN    10.33.199.50
3306/tcp   ALLOW IN    10.33.199.51
2049/tcp   ALLOW IN    10.33.199.50
2049/tcp   ALLOW IN    10.33.199.51
9104/tcp   ALLOW IN    10.33.199.52
```

**Por qué importa:** el SSH a la BD **solo se acepta desde el .49**. Por eso:

- No se puede entrar directo desde un equipo personal ni por la IP pública. Hay que usar salto por el bastión: `ssh -J usuario@10.33.195.184 usuario@10.33.199.53`.
- El diseño del respaldo debe ir del .49 hacia la BD, que es el flujo que el firewall permite. No se modificó ninguna regla.

### 3.2 Llave SSH dedicada (en el .49, usuario `jose`)

```sh
mkdir -p ~/db && chmod 700 ~/db
ssh-keygen -t ed25519 -f ~/.ssh/id_pull -N "" -C "pull-db"
ls -l ~/.ssh/id_pull*
```

Salida:

```
-rw------- 1 jose jose 399 nov 22 16:37 /home/jose/.ssh/id_pull
-rw-r--r-- 1 jose jose  89 nov 22 16:37 /home/jose/.ssh/id_pull.pub
```

**Por qué:**

- Llave **dedicada** a esta tarea: si hay que revocarla, no afecta al resto de accesos (RNF-04).
- Sin contraseña (`-N ""`), porque cron no puede escribirla. Para compensarlo, la llave se limita en el destino (ver 3.5).
- `~/db` con permiso `700` es donde quedarán las copias.
- La llave privada (`id_pull`) nunca se copia ni se comparte. Solo la pública (`.pub`) se instala en la BD.

### 3.3 Problema encontrado: `ssh-copy-id` falló

```sh
ssh-copy-id -i ~/.ssh/id_pull.pub database@10.33.199.53
```

Salida:

```
database@10.33.199.53's password:
sh: can't create .ssh/authorized_keys: Permission denied
```

**Diagnóstico** (en la BD, como root):

```sh
grep '^database:' /etc/passwd
ls -la /home/database
ls -la /home/database/.ssh
```

```
database:x:1000:1000:database:/home/database:/bin/sh
drwxr-xr-x    5 root     root     ... .
drwx------    2 root     root     ... .ssh        (solo contiene known_hosts)
```

**Causa:** el home del usuario `database` es `/home/database`, que es **el mismo directorio que usa root** (el `~` de root apunta ahí). La carpeta `.ssh` pertenece a root con permisos `700`, así que `database` no podía escribir ni leer en ella.

**Decisión:** no instalar la llave en `/home/database/.ssh/authorized_keys`. Como esa carpeta es también la de root, la llave habría servido para entrar como **root**, y el README pide `PermitRootLogin no` y accesos nominativos. En su lugar se creó un archivo de llaves aparte, solo para `database`.

### 3.4 Configuración de sshd en la BD (antes del cambio)

```sh
grep -nEv '^\s*(#|$)' /etc/ssh/sshd_config
```

```
15:Include /etc/ssh/sshd_config.d/*.conf
45:AuthorizedKeysFile   .ssh/authorized_keys
92:AllowTcpForwarding no
93:GatewayPorts no
94:X11Forwarding no
116:Subsystem   sftp    internal-sftp
```

`/etc/ssh/sshd_config.d/` estaba vacío, así que nada podía pisar la regla nueva.

### 3.5 Archivo de llaves de `database` con alcance mínimo

```sh
mkdir -p /etc/ssh/authorized_keys.d
echo 'from="10.33.199.49",restrict ssh-ed25519 AAAA...(llave pública completa)... pull-db' > /etc/ssh/authorized_keys.d/database
chmod 755 /etc/ssh/authorized_keys.d
chmod 644 /etc/ssh/authorized_keys.d/database
cat /etc/ssh/authorized_keys.d/database
```

**Por qué cada parte:**

| Elemento | Efecto |
|---|---|
| `from="10.33.199.49"` | La llave solo sirve si la conexión viene del .49. Si alguien la robara, no funcionaría desde otro equipo |
| `restrict` | Desactiva terminal interactiva, reenvío de puertos, agente y X11. Siguen funcionando comandos puntuales y `scp`, que es lo único que necesita el respaldo |
| Archivo en `/etc/ssh/` (de root, no escribible por `database`) | El usuario no puede modificar sus propias llaves autorizadas |
| No se tocó `/home/database/.ssh` | Root conserva su `known_hosts` intacto |

### 3.6 Regla `Match User` en sshd

```sh
ls /etc/ssh/sshd_config.d/
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
cat >> /etc/ssh/sshd_config <<'EOF'

Match User database
    AuthorizedKeysFile /etc/ssh/authorized_keys.d/database
EOF
tail -5 /etc/ssh/sshd_config
sshd -t && echo "config OK"
```

Salida:

```
Match User database
    AuthorizedKeysFile /etc/ssh/authorized_keys.d/database
config OK
```

Luego se aplicó con `rc-service sshd reload`.

**Por qué:**

- `sshd_config.bak` es la copia de seguridad. Para revertir: `cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && rc-service sshd restart`.
- `Match` va **al final** del archivo, que es donde debe ir. Solo afecta al usuario `database`; root y los demás siguen usando su `.ssh/authorized_keys` como antes.
- `sshd -t` valida la sintaxis **antes** de aplicar, para que un error no deje la VM sin SSH.
- `reload` no corta las sesiones abiertas.
- La consola de Proxmox quedó disponible como vía de recuperación durante todo el cambio.

### 3.7 Prueba de acceso (desde el .49)

```sh
ssh -i ~/.ssh/id_pull database@10.33.199.53 "ls -lh /home/database/backups"
```

Salida: lista de los respaldos **sin pedir contraseña**.

```
-rw-r-----    1 database database  776.1K Nov 18 02:30 mariadb_all_2026-11-18_023000.sql.gz
-rw-r-----    1 database database     103 Nov 18 02:30 mariadb_all_2026-11-18_023000.sql.gz.sha256
...
```

---

## 4. Parte 3: copia automática en el nodo perimetral (.49)

Todos los comandos se ejecutaron como `jose` en `tas-06-jose` (Ubuntu 24.04, 88 GB libres).

### 4.1 Script de copia: `~/pull-db.sh`

```sh
cat > ~/pull-db.sh <<'EOF'
#!/bin/sh
set -eu
export TZ=America/Santiago

REMOTE="database@10.33.199.53"
RDIR="/home/database/backups"
DEST="$HOME/db"
KEY="$HOME/.ssh/id_pull"
RETENTION_DAYS=30
LOG="$HOME/pull-db.log"

log()  { echo "$(date '+%F %T') $*" >> "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }

mkdir -p "$DEST"
log "Inicio copia"

LISTA=$(ssh -i "$KEY" "$REMOTE" "ls $RDIR" | grep -E '^mariadb_all_.*\.sql\.gz\.sha256$') \
  || fail "no se pudo listar los respaldos de la BD"

NUEVOS=0
for sha in $LISTA; do
  gz="${sha%.sha256}"
  [ -f "$DEST/$gz" ] && continue
  scp -p -q -i "$KEY" "$REMOTE:$RDIR/$gz" "$REMOTE:$RDIR/$sha" "$DEST/" \
    || fail "scp falló con $gz"
  ( cd "$DEST" && sha256sum -c "$sha" >/dev/null 2>&1 ) \
    || { rm -f "$DEST/$gz" "$DEST/$sha"; fail "checksum inválido en $gz"; }
  log "Copiado y verificado: $gz"
  NUEVOS=$((NUEVOS+1))
done

find "$DEST" -name 'mariadb_all_*' -mtime +"$RETENTION_DAYS" -delete
log "Fin ($NUEVOS nuevos)"
EOF
chmod 700 ~/pull-db.sh
sh -n ~/pull-db.sh && echo "sintaxis OK"
```

**Por qué cada parte:**

| Parte | Motivo |
|---|---|
| Copia solo lo que no tiene | Se puede ejecutar las veces que se quiera sin duplicar ni gastar tráfico |
| `sha256sum -c` tras copiar | Verifica que el archivo llegó íntegro. Si no coincide, lo borra y deja el error en el log |
| `scp -p` | Conserva la fecha original del respaldo, para que la retención de 30 días cuente desde que se creó y no desde que se copió |
| Sin `--delete` ni borrado remoto | Si un respaldo desaparece en la BD, la copia del .49 se conserva. La copia externa no depende de la BD |
| Retención al final | Mismo criterio que en la BD |
| Sin contraseñas en el script | Usa la llave `id_pull` con alcance limitado |

Nota: el primer intento de ejecutar `sh -n ~/pull-db.sh` falló con `No such file` porque el bloque de creación aún no se había pegado. Se volvió a pegar y dio `sintaxis OK`.

### 4.2 Prueba manual

```sh
~/pull-db.sh
tail ~/pull-db.log
ls -lh ~/db
cd ~/db && sha256sum -c *.sha256; cd ~
```

Salida:

```
2026-11-22 13:52:11 Inicio copia
2026-11-22 13:52:12 Copiado y verificado: mariadb_all_2026-11-18_023000.sql.gz
2026-11-22 13:52:13 Copiado y verificado: mariadb_all_2026-11-20_023000.sql.gz
2026-11-22 13:52:13 Copiado y verificado: mariadb_all_2026-11-22_023000.sql.gz
2026-11-22 13:52:13 Fin (3 nuevos)

mariadb_all_2026-11-18_023000.sql.gz: OK
mariadb_all_2026-11-20_023000.sql.gz: OK
mariadb_all_2026-11-22_023000.sql.gz: OK
```

Segunda ejecución inmediata:

```
2026-11-22 13:52:36 Inicio copia
2026-11-22 13:52:37 Fin (0 nuevos)
```

**Por qué:** la primera ejecución demuestra que copia y verifica. La segunda (`0 nuevos`) demuestra que es seguro repetirla.

**Hallazgo (hora):** en `~/db` los archivos aparecen como `05:30` y en la BD como `02:30`. Es el mismo instante visto en otra zona. El .49 usa **UTC** y la BD usa hora de Chile. El log del script sí sale en hora de Chile porque el script fija `TZ`.

### 4.3 Zona horaria del .49

```sh
date
timedatectl | head -4
```

```
dom 22 nov 2026 16:52:43 UTC
               Time zone: Etc/UTC (UTC, +0000)
```

**Por qué importa:** cron usa la hora del sistema (UTC). Para que la copia ocurra **después** del dump de las 02:30 de Chile (05:30 UTC), la hora del cron se escribe en UTC. No se cambió la zona horaria del servidor, porque afectaría a Nginx, BIND y sus logs.

### 4.4 Programar con cron

```sh
( crontab -l 2>/dev/null; echo '0 7 * * * flock -n /tmp/pull-db.lock /home/jose/pull-db.sh' ) | crontab -
crontab -l
systemctl is-active cron
```

Salida:

```
0 7 * * * flock -n /tmp/pull-db.lock /home/jose/pull-db.sh
active
```

**Por qué esa hora y frecuencia:**

- `07:00 UTC` equivale a las **04:00 en Chile** (horario de verano, UTC-3) y a las **03:00** cuando cambie al horario de invierno (UTC-4). En ambos casos queda después del dump de las 02:30, sin reajustar.
- Corre **a diario**, aunque el dump sea cada 2 días: si no hay respaldo nuevo, el script responde `Fin (0 nuevos)` y no hace nada más. Así no se depende de la paridad de los días.
- `flock -n` evita ejecuciones simultáneas.

Antes de agregar la línea, `crontab -l` respondió `no crontab for jose`: el servicio `cron` estaba activo pero el usuario no tenía tareas, es decir, la copia aún no era automática.

### 4.5 Prueba de que cron la dispara

Se agregó una línea temporal a +3 minutos:

```sh
T=$(date -d '+3 minutes' +'%M %H')
( crontab -l; echo "$T * * * /home/jose/pull-db.sh # PRUEBA" ) | crontab -
```

Resultado en el log, a la hora programada:

```
2026-11-22 13:57:01 Inicio copia
2026-11-22 13:57:01 Fin (0 nuevos)
```

Luego se eliminó la línea de prueba:

```sh
crontab -l | grep -v 'PRUEBA' | crontab -
crontab -l
```

```
0 7 * * * flock -n /tmp/pull-db.lock /home/jose/pull-db.sh
```

**Por qué:** confirma que cron ejecuta el script sin intervención. `0 nuevos` era el resultado esperado, porque aún no había respaldos que no tuviera.

---

## 5. Estado final

| Componente | Ubicación | Estado |
|---|---|---|
| Dump automático (02:30 Chile, días pares) | BD (.53) | Funcionando, respaldos de los días 18, 20 y 22 |
| Verificación de integridad (gzip + SHA-256) | BD (.53) | Funcionando |
| Retención 30 días | BD (.53) | Programada en el script |
| Acceso SSH del .49 a la BD con llave restringida | BD (.53) y .49 | Funcionando |
| Copia automática (07:00 UTC, diaria) | Nodo perimetral (.49) | Programada y probada |
| Verificación SHA-256 de cada copia | Nodo perimetral (.49) | Funcionando |
| Retención 30 días | Nodo perimetral (.49) | Programada en el script |

### Cómo confirmar que el flujo completo funciona solo

El próximo dump es el **24/nov a las 02:30**. Ese día, después de las 04:00 hora de Chile:

```sh
# En la BD
tail /var/log/backup-db.log
ls -lh /home/database/backups

# En el .49
tail -5 ~/pull-db.log
ls -lh ~/db
```

Debe aparecer `mariadb_all_2026-11-24_023000.sql.gz` en ambas máquinas y `Copiado y verificado` en el log del .49.

### Revisión periódica

```sh
tail /var/log/backup-db.log                 # en la BD
cd /home/database/backups && sha256sum -c *.sha256
df -h /                                      # espacio en disco

tail ~/pull-db.log                           # en el .49
cd ~/db && sha256sum -c *.sha256; cd ~
```

---

## 6. Rutas y archivos de referencia

| Qué | Dónde |
|---|---|
| Script de dump | BD: `/usr/local/bin/backup-db.sh` |
| Log del dump | BD: `/var/log/backup-db.log` |
| Respaldos locales | BD: `/home/database/backups` (dueño `database`, permisos `640`) |
| Cron del dump | BD: `crontab -l` de root |
| Llaves autorizadas de `database` | BD: `/etc/ssh/authorized_keys.d/database` |
| Config SSH modificada | BD: `/etc/ssh/sshd_config` (copia: `sshd_config.bak`) |
| Script de copia | .49: `/home/jose/pull-db.sh` |
| Log de la copia | .49: `/home/jose/pull-db.log` |
| Copias externas | .49: `/home/jose/db` |
| Llave SSH | .49: `/home/jose/.ssh/id_pull` (privada, nunca compartir) |
| Cron de la copia | .49: `crontab -l` de `jose` |

---

## 7. Restauración (procedimiento previsto, aún no probado)

Se hace siempre en un contenedor aparte, sin tocar producción. Es el procedimiento que se medirá para RNF-06 (restauración ≤ 60 min).

```sh
# En la VM de la BD, como root
free -m
docker run -d --name mdb-test -e MARIADB_ROOT_PASSWORD=<clave_de_prueba> mariadb:11
docker exec mdb-test mariadb -uroot -p<clave_de_prueba> -e "SELECT 1;"

time (gunzip -c /home/database/backups/mariadb_all_AAAA-MM-DD_HHMMSS.sql.gz \
  | docker exec -i mdb-test mariadb -uroot -p<clave_de_prueba>)

docker exec mdb-test mariadb -uroot -p<clave_de_prueba> -e \
  "SHOW DATABASES; SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='mydb';"

docker rm -f mdb-test
```

Resultado esperado: aparecen `mydb` y `mysql`, `mydb` con 52 tablas (según el README), y el comando `time` entrega el tiempo real de restauración.

**Por qué en un contenedor aparte:** no publica puertos, no comparte volúmenes con el MariaDB real y se elimina al final. El único costo es memoria y CPU durante unos minutos.

---

## 8. Cambios de configuración para registrar en la bitácora

1. BD: creación de `/usr/local/bin/backup-db.sh` y de la tarea en el crontab de root.
2. BD: creación de `/etc/ssh/authorized_keys.d/database` y bloque `Match User database` agregado a `/etc/ssh/sshd_config` (copia previa en `sshd_config.bak`).
3. BD: `chown database:database` y `chmod 750` sobre `/home/database/backups`.
4. .49: creación de la llave `~/.ssh/id_pull`, de `~/pull-db.sh`, de `~/db` y de la tarea en el crontab de `jose`.
5. Ninguna regla de firewall, tarjeta de red ni contenedor de producción fue modificado.

---

## 9. Problemas encontrados y cómo se resolvieron

| Problema | Causa | Solución |
|---|---|---|
| `ssh-copy-id` fallaba con `Permission denied` al escribir `.ssh/authorized_keys` | El home de `database` es el mismo que el de root y `.ssh` es de root con permisos `700` | Archivo de llaves aparte en `/etc/ssh/authorized_keys.d/` y bloque `Match User database` |
| Línea `MM HH` inválida en el crontab | Se pegó el texto de ejemplo sin reemplazar | Se reemplazó el crontab completo con el contenido correcto |
| Respaldos en días pares y no impares | BusyBox interpreta `*/2` del día del mes como días pares | Se verificó con los respaldos reales; no requiere cambio |
| Archivos del .49 con hora distinta a la BD | El .49 está en UTC y la BD en hora de Chile | El script fija `TZ` para sus logs y el cron del .49 se escribió en UTC |
| `pull-db.sh` no existía al probar su sintaxis | El bloque de creación no se había pegado | Se volvió a pegar el bloque completo |
| El .49 no tenía crontab (`no crontab for jose`) | La tarea nunca se había agregado | Se agregó la línea de las 07:00 UTC |
