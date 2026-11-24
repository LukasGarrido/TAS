<div align="center">

# Documentación: UFW en `tas-06-lukas` con acceso administrativo solo desde `tas-06-jose`


</div>

## 1. Objetivo

Proteger el host `tas-06-lukas` (Alpine Linux, 10.33.199.53) con UFW de modo que:

- El **SSH (22)** solo pueda usarse desde la máquina admin `tas-06-jose` (bastión).
- El **3306** de MariaDB (contenedor Docker) siga accesible solo para los WordPress y el monitor.
- Todo lo demás quede **bloqueado**.

## 2. Entorno

| VM | IP | Rol |
|---|---|---|
| `tas-06-jose` | `<IP_JOSE>` | Admin / bastión SSH: único origen permitido al 22 |
| `tas-06-lukas` | 10.33.199.53 | MariaDB 11 en Docker (esta VM) |
| WP1 | 10.33.199.50 | Permitido al 3306 |
| WP2 | 10.33.199.51 | Permitido al 3306 |
| `tas-06-monitor` | 10.33.199.52 | Permitido al 3306 (mysqld-exporter) |

- Interfaz usada: `eth1`.
- Sin `sudo`: se trabaja como root con `su -`.

## 3. Decisión de diseño

Docker publica el 3306 saltándose UFW, por lo que hay dos capas independientes:

| Capa | Herramienta | Protege |
|---|---|---|
| Host | **UFW** | SSH y cualquier servicio del host |
| Contenedor | `iptables`, cadena `DOCKER-USER` | Puerto 3306 de MariaDB |

Las reglas de `DOCKER-USER` ya existían y **no se tocan** con UFW.

## 4. Pasos

### Paso 1: instalar UFW

```bash
apk add ufw
```

### Paso 2: definir la IP del admin

```bash
ADMIN=<IP_JOSE>
```

Para confirmar la IP de origen de tu sesión SSH:

```bash
netstat -tn | grep ':22 '
```

La IP de la columna derecha es la de origen. Si entras por el bastión, es la de `tas-06-jose`.

### Paso 3: temporizador de seguridad

```bash
nohup sh -c 'sleep 300; ufw disable; iptables -P INPUT ACCEPT; iptables -F INPUT' >/dev/null 2>&1 &
echo $!      # anotar el PID
```

A los 5 minutos desactiva UFW si algo sale mal. No toca `DOCKER-USER`, para no abrir el 3306.

### Paso 4: limpiar reglas manuales de `INPUT` (solo si existían)

```bash
iptables -F INPUT
iptables -P INPUT ACCEPT
```

### Paso 5: reglas de UFW

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow from $ADMIN to any port 22 proto tcp
ufw show added
ufw enable
ufw status verbose
```

`ufw show added` permite revisar la regla antes de activar. No cerrar la sesión actual.

### Paso 6: pruebas

- Abrir **otra** sesión SSH a `lukas` desde `tas-06-jose`: debe entrar.
- Intentar SSH desde otra VM: debe fallar (timeout).
- Verificar que el 3306 no cambió:

  ```bash
  iptables -L DOCKER-USER -n -v --line-numbers
  ```

  Los ACCEPT de .50, .51 y .52 siguen sobre el DROP.
- Prueba del 3306 desde cada origen:

  ```bash
  nc -w3 10.33.199.53 3306 </dev/null && echo "ABIERTO" || echo "CERRADO"
  ```

Si todo está bien, cancelar el temporizador: `kill <PID>`.

### Paso 7: persistencia

Activar UFW al arrancar:

```bash
rc-update add ufw default
```

Las reglas de `DOCKER-USER` se pierden al reiniciar, así que se guardan en un script que espera a Docker:

```bash
WP1=10.33.199.50
WP2=10.33.199.51
MON=10.33.199.52
IFACE=eth1

cat > /etc/local.d/firewall.start << EOF
#!/bin/sh
for i in \$(seq 1 60); do
  iptables -L DOCKER-USER -n >/dev/null 2>&1 && break
  sleep 2
done

iptables -F DOCKER-USER
iptables -A DOCKER-USER -i $IFACE -s $WP1 -p tcp -m conntrack --ctorigdstport 3306 --ctdir ORIGINAL -j ACCEPT
iptables -A DOCKER-USER -i $IFACE -s $WP2 -p tcp -m conntrack --ctorigdstport 3306 --ctdir ORIGINAL -j ACCEPT
iptables -A DOCKER-USER -i $IFACE -s $MON -p tcp -m conntrack --ctorigdstport 3306 --ctdir ORIGINAL -j ACCEPT
iptables -A DOCKER-USER -i $IFACE -p tcp -m conntrack --ctorigdstport 3306 --ctdir ORIGINAL -j DROP
iptables -A DOCKER-USER -j RETURN
EOF
chmod +x /etc/local.d/firewall.start
rc-update add local default
cat /etc/local.d/firewall.start
```

Revisar con `cat` que las IP salgan con números reales. El archivo debe ser un **archivo** (no una carpeta) dentro de `/etc/local.d/`.

### Paso 8: prueba de reinicio

Con otro temporizador armado (Paso 3), ejecutar `reboot`. Al volver, repetir las pruebas del Paso 6 y comprobar `ufw status`.

## 5. Estado final

| Servicio en `lukas` | Quién puede acceder | Mecanismo |
|---|---|---|
| SSH (22) | Solo `tas-06-jose` (admin) | UFW |
| MariaDB (3306) | WP1 (.50), WP2 (.51), monitor (.52) | `DOCKER-USER` |
| Resto de puertos del host | Nadie (NFS 2049 y exporters del host incluidos) | UFW `deny incoming` |

Resultado: la administración de la VM solo es posible desde `tas-06-jose`, y la base de datos solo responde a quienes la necesitan.

## 6. Cómo replicarlo en las demás VMs

El mismo patrón sirve para `tas-06-02`, `tas-06-cms-02` y `tas-06-monitor`: permitir el 22 solo desde `ADMIN` y abrir únicamente los puertos que cada una necesita.

| VM | Puertos a permitir además del 22 (desde `jose`) |
|---|---|
| WordPress (`tas-06-02`, `tas-06-cms-02`) | 8080 desde `jose` (Nginx); 9117 desde el monitor |
| `tas-06-monitor` | Los que use Grafana/Prometheus, según cómo se consulten |

Ejemplo de reglas adicionales:

```bash
ufw allow from <IP_JOSE> to any port 8080 proto tcp
ufw allow from 10.33.199.52 to any port 9117 proto tcp
```

Este apartado es una recomendación: no hay constancia en la conversación de que se haya aplicado en esas VMs.

## 7. Pendientes por confirmar

- [ ] IP real de `tas-06-jose` verificada y usada en `ADMIN`.
- [ ] UFW activo con la regla del 22 solo desde `jose`.
- [ ] `/etc/local.d/firewall.start` creado como archivo, ejecutable y con IP reales.
- [ ] Prueba tras reinicio superada.
- [ ] Decisión sobre NFS (2049) y exporters del host, que quedan cerrados.
- [ ] Reglas equivalentes aplicadas en las otras VMs.

## 8. Emergencia (consola web de la plataforma)

```bash
ufw disable
iptables -F INPUT
iptables -P INPUT ACCEPT
```