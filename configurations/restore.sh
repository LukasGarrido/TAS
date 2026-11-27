#!/bin/sh
# Restaura la base de WordPress. Se ejecuta como root en la VM db (.53).
# Busca el respaldo en esta maquina y, si no hay uno valido, lo trae del nodo dns.
#
#   restore.sh                 usa el respaldo valido mas reciente
#   restore.sh ARCHIVO.sql.gz  usa ese respaldo
#   restore.sh --remoto        ignora los locales y lo trae de dns
set -eu

LOCAL_DIR="${LOCAL_DIR:-/home/database/backups}"
REMOTE="${REMOTE:-jose@10.33.199.49}"
REMOTE_DIR="${REMOTE_DIR:-db}"          # relativo al home del usuario remoto
CONTAINER="${CONTAINER:-mariadb}"
DB="${DB:-mydb}"

TMP=""
trap '[ -z "$TMP" ] || rm -rf "$TMP"' EXIT

msg()  { echo "$(date -u '+%H:%M:%S UTC') $*"; }
fail() { msg "ERROR: $*" >&2; exit 1; }

SOLO_REMOTO=0
PEDIDO=""
case "${1:-}" in
  "")        ;;
  --remoto)  SOLO_REMOTO=1; PEDIDO="${2:-}" ;;
  -*)        fail "opcion desconocida: $1" ;;
  *)         PEDIDO="$1" ;;
esac
PEDIDO="${PEDIDO##*/}"
case "$PEDIDO" in
  "") ;;
  *[!A-Za-z0-9._-]*) fail "nombre de archivo no valido" ;;
  mariadb_all_*.sql.gz) ;;
  *) fail "el nombre debe ser mariadb_all_*.sql.gz" ;;
esac

# Valido = checksum correcto, gzip sano y contiene las entradas de WordPress.
# Lo ultimo descarta respaldos hechos despues de borrar la base.
valido() {
  [ -f "$1" ] && [ -f "$1.sha256" ] || return 1
  ( cd "$(dirname "$1")" && sha256sum -c "$(basename "$1").sha256" >/dev/null 2>&1 ) || return 1
  gzip -t "$1" 2>/dev/null || return 1
  gunzip -c "$1" | grep -q 'CREATE TABLE `wp_posts`'
}

# Deja en ELEGIDO el respaldo valido mas reciente (o el pedido) de una carpeta.
buscar() {
  ELEGIDO=""
  for f in $(ls -1 "$1"/${PEDIDO:-mariadb_all_*.sql.gz} 2>/dev/null | sort -r); do
    if valido "$f"; then ELEGIDO="$f"; return 0; fi
    msg "Descartado (no valido): $f"
  done
  return 1
}

[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = "true" ] \
  || fail "el contenedor $CONTAINER no esta en ejecucion (docker start $CONTAINER)"

ELEGIDO=""
if [ "$SOLO_REMOTO" -eq 0 ]; then
  msg "Buscando en local: $LOCAL_DIR"
  buscar "$LOCAL_DIR" || msg "No hay respaldo local valido"
fi

if [ -z "$ELEGIDO" ]; then
  msg "Buscando en $REMOTE:~/$REMOTE_DIR (pedira la clave de ese usuario)"
  TMP=$(mktemp -d /tmp/restore.XXXXXX)
  if [ -n "$PEDIDO" ]; then ARCHIVOS="$PEDIDO $PEDIDO.sha256"; else ARCHIVOS="mariadb_all_*"; fi
  ssh "$REMOTE" "cd $REMOTE_DIR && tar cf - $ARCHIVOS" \
    | tar xf - -C "$TMP" || fail "no se pudo traer el respaldo desde $REMOTE"
  buscar "$TMP" || fail "tampoco hay un respaldo valido en $REMOTE"
fi

msg "Respaldo elegido: $ELEGIDO"
echo "Se reemplazaran las tablas de '$DB'. Lo creado despues del respaldo puede perderse."
printf 'Escribe RESTAURAR para continuar: '
read -r RESP
[ "$RESP" = "RESTAURAR" ] || fail "cancelado, no se modifico nada"

# La clave se lee dentro del contenedor: no queda en este script ni en el historial.
sql() { docker exec -i "$CONTAINER" sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$@"' sh "$@"; }

INICIO=$(date +%s)
msg "Restaurando"
sql -e "CREATE DATABASE IF NOT EXISTS \`$DB\`;" || fail "no se pudo crear la base"
gunzip -c "$ELEGIDO" | sql --one-database "$DB" || fail "la restauracion fallo"
msg "Restauracion terminada en $(( $(date +%s) - INICIO )) s"

sql "$DB" -e "SELECT COUNT(*) AS tablas FROM information_schema.tables WHERE table_schema=DATABASE();
              SELECT COUNT(*) AS entradas FROM wp_posts;"
