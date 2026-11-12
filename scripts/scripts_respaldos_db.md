# Respaldo automático de MariaDB (VM `db`, 10.33.199.53)

## Resumen

- **Qué respalda:** todas las bases (`--all-databases`) del contenedor `mariadb` (imagen `mariadb:11`).
- **Cuándo:** 02:30, cada 2 días (días impares del mes), con cron de root.
- **Dónde queda:** `/home/database/backups` (misma VM de la BD).
- **Retención:** 30 días, aplicada automáticamente.
- **Verificación:** dump completo, gzip válido y checksum SHA-256 por archivo.
- **Pendiente:** copia fuera de la VM (nodo perimetral) y prueba de restauración.

---

## 1. Comprobar que el contenedor y la contraseña existen

```sh
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}'
docker exec mariadb env | grep -i root | cut -d= -f1
```

**Por qué:** confirma el nombre real del contenedor (`mariadb`) y que la variable `MARIADB_ROOT_PASSWORD` existe. El `cut -d= -f1` muestra solo el nombre de la variable y no su valor, para no exponer la contraseña en pantalla.

## 2. Comprobar la conexión a la base

```sh
docker exec mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES;"'
```

**Por qué:** la contraseña se lee desde dentro del contenedor (`$MARIADB_ROOT_PASSWORD`), así no queda escrita en el script ni en el historial. Debe listar `mydb` y `mysql`.

## 3. Dump de prueba (sin tocar los respaldos reales)

```sh
docker exec mariadb sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --all-databases --single-transaction --routines --triggers --events' > /tmp/prueba.sql
tail -c 200 /tmp/prueba.sql
ls -lh /tmp/prueba.sql
rm /tmp/prueba.sql
```

**Por qué:** valida que `mariadb-dump` funciona con las opciones definitivas. La última línea debe decir `-- Dump completed on ...`.

Opciones del dump:

| Opción | Motivo |
|---|---|
| `--all-databases` | Incluye `mydb` y `mysql` (usuarios y permisos). |
| `--single-transaction` | Dump consistente sin bloquear tablas InnoDB, para no frenar pedidos ni reservas. |
| `--routines --triggers --events` | Incluye procedimientos, disparadores y eventos. |

## 4. Zona horaria

```sh
date
TZ=America/Santiago date
```

**Por qué:** el contenedor trabaja en UTC y la VM en hora de Chile (-03). Si ambas salidas coinciden, el script puede fijar `TZ=America/Santiago` y los archivos y logs usan la hora local (RNF-08, trazabilidad). Si no coinciden, instalar `tzdata` con `apk add tzdata`.

## 5. Crear el script

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
| `set -eu` | El script se detiene ante cualquier error o variable no definida. |
| Archivo temporal `.part` | El respaldo solo recibe su nombre final si pasó todas las validaciones; nunca queda uno a medias que parezca bueno. |
| `grep "Dump completed"` | Detecta dumps cortados. |
| `gzip -t` | Verifica que el comprimido no esté corrupto. |
| `.sha256` | Permite comprobar la integridad después (y en la copia externa). |
| `chown database` + `chmod 640` | El archivo es legible por el usuario `database` y su grupo, y nadie más. No se agrega `database` al grupo `docker` porque equivale a darle root. |
| Retención al final | Solo se borran respaldos viejos si el nuevo salió bien; un fallo nunca deja sin respaldos. |
| Contraseña desde el contenedor | No aparece en el script ni en el historial. |

## 6. Probar el script a mano

```sh
sh -n /usr/local/bin/backup-db.sh && echo "sintaxis OK"
/usr/local/bin/backup-db.sh
tail /var/log/backup-db.log
ls -lh /home/database/backups
cd /home/database/backups && sha256sum -c *.sha256
```

**Por qué:** antes de automatizar hay que comprobar que funciona. Resultado esperado: `Inicio`, `OK` y `Fin` en el log, archivo `.sql.gz` de ~1 MB con dueño `database`, y `OK` en el checksum.

## 7. Programar con cron (cada 2 días)

```sh
which flock || apk add util-linux
rc-update add crond default
rc-service crond start
rc-service crond status
```

```sh
cat <<'EOF' | crontab -
# do daily/weekly/monthly maintenance
# min   hour    day     month   weekday command
*/15    *       *       *       *       run-parts /etc/periodic/15min
0       *       *       *       *       run-parts /etc/periodic/hourly
0       2       *       *       *       run-parts /etc/periodic/daily
0       3       *       *       6       run-parts /etc/periodic/weekly
0       5       1       *       *       run-parts /etc/periodic/monthly

# Respaldo de MariaDB: 02:30, cada 2 dias (dias impares del mes)
30 2 */2 * * flock -n /tmp/backup-db.lock /usr/local/bin/backup-db.sh
EOF
crontab -l
```

**Por qué:**
- Corre como **root** porque necesita acceder a Docker; el script entrega los archivos a `database`.
- `flock -n` evita que dos ejecuciones se pisen entre sí.
- Las líneas `run-parts` son las tareas estándar de Alpine y se mantienen.
- `*/2` en el día del mes cuenta días impares (1, 3, 5... 31). El 31 y el 1 caen seguidos, así que una vez al mes habrá un solo día entre respaldos.

## 8. Prueba opcional de que cron lo dispara

```sh
T=$(date -d "@$(( $(date +%s) + 180 ))" +"%M %H")
( crontab -l; echo "$T * * * flock -n /tmp/backup-db.lock /usr/local/bin/backup-db.sh # PRUEBA" ) | crontab -
crontab -l | tail -2
```

Pasados 3 minutos:

```sh
tail -5 /var/log/backup-db.log
ls -lh /home/database/backups
```

Limpiar la línea temporal:

```sh
crontab -l | grep -v 'PRUEBA' | crontab -
crontab -l
```

**Por qué:** evita esperar hasta la madrugada para saber si cron funciona. Error común: dejar `MM HH` literal en una línea del crontab es inválido; hay que escribir números reales.

## 9. Verificación diaria / mantenimiento

```sh
tail /var/log/backup-db.log
ls -lh /home/database/backups
cd /home/database/backups && sha256sum -c *.sha256
df -h /
```

El primer respaldo automático es el 11/nov a las 02:30.
