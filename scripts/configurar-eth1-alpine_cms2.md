# Dejar eth1 como única tarjeta de red (Alpine)

Aplicar en las 4 máquinas, todas menos la del DNS.

**DNS a usar en todas:** `10.33.195.184`

## 0. Antes de empezar

- Entra por la IP de **eth1** o por la consola de la VM, nunca por eth0 (la sesión se cortaría).
- Instala antes lo que necesites (`apk add ...`).
- Comprueba que el default ya sale por eth1:

```sh
ip a
ip route
```

Debe verse `default via <gateway> dev eth1`. Si sale por eth0, hay que ajustar el gateway antes de continuar.

## 1. Entrar como root

```sh
su
```

## 2. Evitar que DHCP sobrescriba resolv.conf

```sh
sed -i 's/^#RESOLV_CONF="no"/RESOLV_CONF="no"/' /etc/udhcpc/udhcpc.conf
cat /etc/udhcpc/udhcpc.conf | grep RESOLV
```

Debe salir `RESOLV_CONF="no"` sin `#` delante.

## 3. Fijar el DNS

```sh
echo "nameserver 10.33.195.184" > /etc/resolv.conf
cat /etc/resolv.conf
```

Prueba de que el DNS responde:

```sh
ping -c 3 10.33.195.184
nslookup google.com 10.33.195.184
```

## 4. Quitar eth0 de la configuración

```sh
vi /etc/network/interfaces
```

Debe quedar así:

```
auto lo
iface lo inet loopback
iface lo inet6 loopback

auto eth1
iface eth1 inet dhcp
iface eth1 inet6 auto
```

## 5. Bajar eth0

```sh
ip addr flush dev eth0
ip link set eth0 down
```

## 6. Verificar

```sh
ip a                      # eth0 DOWN y sin IP, eth1 con IP
ip route                  # solo default por eth1
cat /etc/resolv.conf      # nameserver 10.33.195.184
nslookup google.com
```

## 7. Reiniciar y comprobar

```sh
reboot
```

Reconéctate por la IP de eth1 y repite:

```sh
ip a
ip route
cat /etc/resolv.conf
docker ps                 # contenedores arriba
```

Si algún contenedor no arranca solo, añade `restart: unless-stopped` en el compose (o `--restart unless-stopped` en `docker run`).

## Resumen rápido (copiar y pegar como root)

```sh
sed -i 's/^#RESOLV_CONF="no"/RESOLV_CONF="no"/' /etc/udhcpc/udhcpc.conf
echo "nameserver 10.33.195.184" > /etc/resolv.conf
vi /etc/network/interfaces      # borrar el bloque de eth0
ip addr flush dev eth0
ip link set eth0 down
ip a && ip route && cat /etc/resolv.conf && nslookup google.com
```

## Notas

- Si eth1 cambia de IP tras el reinicio (DHCP), reconéctate por la nueva. Para evitarlo, usa IP estática en eth1.
