# Comandos para la defensa — Nodo Sur (Grupo 06)

> Estos comandos faltan por probar en las máquinas: ensayarlos antes de la defensa.

```
Cliente → DNS (.49) → Nginx (.49) → cms-1 (.51) / cms-2 (.50) → MariaDB (.53)
monitor (.52): Prometheus → Alertmanager → Discord · Grafana
```

## 0. Conexiones

Desde el equipo personal (PowerShell), una pestaña por máquina.

`dns`:

```powershell
ssh jose@10.33.195.184
```

`db`:

```powershell
ssh -J jose@10.33.195.184 database@10.33.199.53
```

`cms-1`:

```powershell
ssh -J jose@10.33.195.184 cms-1@10.33.199.51
```

`cms-2`:

```powershell
ssh -J jose@10.33.195.184 cms-2@10.33.199.50
```

`monitor`, con túneles a Prometheus (9090), Grafana (3000) y Alertmanager (9093):

```powershell
ssh -J jose@10.33.195.184 -L 9090:127.0.0.1:9090 -L 3000:127.0.0.1:3000 -L 9093:127.0.0.1:9093 monitor@10.33.199.52
```

En `db`, `cms-1`, `cms-2` y `monitor` ejecutar `su -`.

## Preparación (antes de la demo)

### Instalar el script de restauración (una sola vez)

En el equipo personal, desde la raíz del proyecto:

```powershell
scp -J jose@10.33.195.184 configurations/restore.sh database@10.33.199.53:/tmp/restore.sh
```

En `db`:

```sh
sed 's/\r$//' /tmp/restore.sh > /usr/local/bin/restore.sh && chmod 700 /usr/local/bin/restore.sh && sh -n /usr/local/bin/restore.sh && echo INSTALADO
```

### Dato de prueba y respaldo

1. En `https://tas-06.arpa/wp-admin`, publicar una entrada con el título exacto `DATO-DEFENSA`.
2. En `db`, crear el respaldo:

```sh
/usr/local/bin/backup-db.sh; tail -3 /var/log/backup-db.log
```

3. En `dns`, traer la copia externa:

```sh
~/pull-db.sh; ls -lh ~/db
```

---

## 1. Servicios operativos

`dns`:

```sh
systemctl is-active named nginx
```

`cms-1` y `cms-2`:

```sh
docker ps
```

`db` (contenedores y carpetas compartidas por NFS):

```sh
docker ps; showmount -e localhost
```

`monitor`:

```sh
cd /opt/nodo-sur-monitoring && docker compose ps
```

Equipo personal (se espera `200`) y abrir la entrada en el navegador:

```powershell
curl.exe -ksS -o NUL -w "%{http_code}`n" "https://tas-06.arpa/?s=DATO-DEFENSA"
```

## 2. Registro A del DNS

`dns`, mostrar el archivo de zona:

```sh
F=$(sudo named-checkconf -p | grep -A4 'zone "tas-06.arpa"' | grep file | cut -d'"' -f2); echo $F; sudo cat $F
```

Equipo personal (si no responde, ejecutarlo en `cms-1`):

```powershell
nslookup tas-06.arpa 10.33.199.49
```

Abrir `https://tas-06.arpa`.

**Explicar:** `10.33.199.49` es el nodo perimetral. Nginx es el punto de entrada: termina TLS y reparte las solicitudes entre los dos WordPress. Cumple el rol que el enunciado asigna a HAProxy.

## 3. Observabilidad e incidente

### Estado normal

`monitor` (valores `"1"`):

```sh
cd /opt/nodo-sur-monitoring && for M in mysql_up probe_success; do docker compose exec prometheus wget -qO- "http://localhost:9090/api/v1/query?query=$M"; echo; done
```

Mostrar `http://localhost:9090/targets`, Grafana y Discord sin alertas.

### Falla controlada

`db`:

```sh
date -u; docker stop mariadb
```

### Evidencia

Equipo personal (se espera `500`):

```powershell
curl.exe -ksS -o NUL -w "%{http_code}`n" "https://tas-06.arpa/?s=DATO-DEFENSA"; (Get-Date).ToUniversalTime().ToString("HH:mm:ss")
```

`db` (apagado del motor):

```sh
docker logs -t --tail 15 mariadb
```

`cms-1`:

```sh
cd /opt/cms && docker compose logs -t --since 5m
```

`dns`:

```sh
sudo tail -15 /var/log/nginx/access.log
```

`monitor`: repetir el comando de estado normal (valores `"0"`) y, tras unos 2 minutos:

```sh
docker compose exec alertmanager amtool alert query --alertmanager.url=http://localhost:9093
```

Mostrar el mensaje en Discord.

**Diagnóstico:** DNS y Nginx responden y los dos WordPress fallan, así que el problema está en lo que comparten. `mysql_up` es 0 y el contenedor `mariadb` está detenido.

## 4. Restauración de datos

Todo en `db`, en la **misma sesión**. Se restaura en una copia de evaluación (`mdb-eval`), sin tocar la base real.

Levantar la base real:

```sh
date -u; docker start mariadb; sleep 10; docker ps --filter name=mariadb
```

Elegir los respaldos: el más reciente con el dato y el más reciente sin él.

```sh
cd /home/database/backups; NUEVO=; ANTERIOR=; for f in $(ls -1 mariadb_all_*.sql.gz | sort -r); do if gunzip -c $f | grep -q DATO-DEFENSA; then [ -z "$NUEVO" ] && NUEVO=$f; else [ -z "$ANTERIOR" ] && ANTERIOR=$f; fi; done; echo "NUEVO=$NUEVO ANTERIOR=$ANTERIOR"
```

Identificar y verificar (debe decir `OK`):

```sh
ls -lh $ANTERIOR $NUEVO; sha256sum -c $NUEVO.sha256
```

Crear la copia de evaluación:

```sh
docker rm -f mdb-eval 2>/dev/null; docker run -d --name mdb-eval -e MARIADB_ROOT_PASSWORD=eval123 -e MARIADB_DATABASE=mydb mariadb:11
```

```sh
until docker exec mdb-eval mariadb -h127.0.0.1 -uroot -peval123 -e "SELECT 1" >/dev/null 2>&1; do sleep 2; done; echo LISTA
```

Cargar el respaldo anterior. Ejecutar solo esta línea y escribir `RESTAURAR`:

```sh
CONTAINER=mdb-eval /usr/local/bin/restore.sh $ANTERIOR
```

**Antes** (sin filas):

```sh
docker exec mdb-eval mariadb -uroot -peval123 mydb -e "SELECT ID, post_title, post_date FROM wp_posts WHERE post_title='DATO-DEFENSA' AND post_status='publish';"; echo ANTES
```

Restaurar el respaldo identificado. Ejecutar solo esta línea y escribir `RESTAURAR`:

```sh
CONTAINER=mdb-eval /usr/local/bin/restore.sh $NUEVO
```

**Después** (aparece la fila):

```sh
docker exec mdb-eval mariadb -uroot -peval123 mydb -e "SELECT ID, post_title, post_date FROM wp_posts WHERE post_title='DATO-DEFENSA' AND post_status='publish';"; echo DESPUES
```

> No omitir `CONTAINER=mdb-eval`: sin eso, el script restaura sobre la base real.

## 5. Validación final

1. Repetir el `curl.exe` de la etapa 1 (`200`) y abrir la entrada.
2. Repetir la consulta **Después**.
3. Repetir el comando de estado normal en `monitor` (valores `"1"`).
4. Mostrar el aviso `RESOLVED` en Discord.
5. Limpiar en `db`:

```sh
docker rm -f mdb-eval
```

| Evento | Hora (UTC) |
|---|---|
| Falla (`docker stop`) | |
| Primer error en el cliente | |
| Alerta en Discord | |
| Motor levantado | |
| Restauración terminada | |
| Servicio verificado | |

## 6. Defensa individual (reparto propuesto)

| Integrante | Muestra | Debe poder explicar |
|---|---|---|
| Josecarlos Vidal | Etapas 1 y 2 | DNS, Nginx y qué pasa si cae un CMS |
| Octavio Valencia | Etapa 3 | Métricas, logs y por qué demora la alerta |
| Lukas Garrido | Etapas 4 y 5 | Respaldos y pérdida máxima de datos |

**Riesgos conocidos:**

- Base de datos y NFS comparten VM, igual que DNS y Nginx: son puntos únicos de falla.
- Se pueden perder hasta 2 días de datos (3 al cambiar de mes).
- No se respaldan las imágenes del NFS ni las configuraciones.
- Si cae la VM `monitor`, no hay alertas.
