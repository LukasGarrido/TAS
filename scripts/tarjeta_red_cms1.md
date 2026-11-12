### 23-10-2026 · CMS 1 (10.33.199.51) · Prueba de baja de la tarjeta pública

**Objetivo:** dejar el CMS 1 con una sola tarjeta de red (privada) antes de quitar la pública en el hipervisor.

# Configuración de IP privada en Alpine Linux (VM)

## Diagnóstico y verificación
```bash
ip a                     # Ver interfaces y sus IPs
ip a show eth1           # Ver solo la interfaz eth1
ip route                 # Ver la tabla de rutas
ping -c 3 10.33.199.49   # Probar conectividad (3 paquetes)
```

## Edición de la configuración
```bash
vi /etc/network/interfaces   # Editar la config de red
```

## Aplicar cambios
```bash
rc-service networking restart   # Reiniciar el servicio de red
```

## Docker (verificación)
```bash
rc-service docker status   # Ver si Docker está corriendo
rc-service docker start    # Iniciarlo si estaba detenido
```

## Alternativas
```bash
setup-interfaces                                  # Asistente guiado de Alpine
echo "nameserver 8.8.8.8" > /etc/resolv.conf      # Configurar DNS
echo "nameserver 1.1.1.1" >> /etc/resolv.conf     # Agregar segundo DNS
```

## Configuración final en `/etc/network/interfaces`
```
auto lo
iface lo inet loopback
iface lo inet6 loopback

auto eth0
iface eth0 inet dhcp
iface eth0 inet6 auto

auto eth1
iface eth1 inet static
        address 10.33.199.51/29
iface eth1 inet6 auto
```

## Resumen del flujo
1. `ip a` para identificar la interfaz (`eth1`).
2. `vi /etc/network/interfaces` para definir la IP estática.
3. `rc-service networking restart` para aplicar.
4. `ip a show eth1` e `ip route` para verificar.
5. `ping -c 3 10.33.199.49` para probar la conectividad.

## Notas
- `eth0` obtiene IP por DHCP y maneja la salida (ruta `default`).
- `eth1` tiene la IP privada `10.33.199.51/29` sin gateway, para evitar el error `RTNETLINK answers: File exists` por rutas por defecto duplicadas.
- Si se exige gateway en `eth1`, agregar `gateway 10.33.199.49` y `metric 300`.