# Scripts de configuración de base de datos

## Copia de base de datos

Nombre de la copia: `octavio_bd_backup.sql`

### Script SQL para crear base y usuario

```sql
CREATE DATABASE octavio_bd;
CREATE USER 'octavio'@'localhost' IDENTIFIED BY '<hidden_password>';
GRANT ALL PRIVILEGES ON octavio_bd.* TO 'octavio'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### Ver tablas en MySQL

Ejecutar:

```bash
lukas@lukas:~$ sudo mysql -u octavio -p octavio_bd -e "SHOW TABLES;"
```

Salida:

```
+-----------------------+
| Tables_in_octavio_bd  |
+-----------------------+
| wp_commentmeta        |
| wp_comments           |
| wp_links              |
| wp_options            |
| wp_postmeta            |
| wp_posts              |
| wp_term_relationships |
| wp_term_taxonomy      |
| wp_termmeta           |
| wp_terms              |
| wp_usermeta           |
| wp_users              |
+-----------------------+
```

---

## Acceso remoto a la base de datos (desde la VM que aloja el CMS)

Objetivo: la VM de WordPress (`octavio`, IP `10.33.199.51`) necesita conectarse a la base `octavio_bd` que vive en la VM `lukas` (IP `10.33.199.53`).

### 1. Configurar MariaDB para escuchar en la interfaz correspondiente

Archivo: `/etc/mysql/mariadb.conf.d/50-server.cnf`

Cambiar:

```
bind-address = 127.0.0.1
```

por:

```
bind-address = 10.33.199.53
```

Reiniciar el servicio:

```bash
sudo systemctl restart mariadb
sudo systemctl status mariadb
```

Verificar que quedó escuchando en la IP correcta:

```bash
ss -tulpn | grep 3306
```

Salida esperada:

```
tcp LISTEN ... 10.33.199.53:3306 ...
```

### 2. Crear usuario con permiso de conexión remota

El usuario `'octavio'@'localhost'` creado originalmente **no** permite conexiones desde otra IP. Hace falta un usuario específico para el host remoto:

```bash
sudo mysql -u root -p
```

```sql
CREATE USER IF NOT EXISTS 'octavio'@'10.33.199.51' IDENTIFIED BY 'octavio';
GRANT ALL PRIVILEGES ON octavio_bd.* TO 'octavio'@'10.33.199.51';
FLUSH PRIVILEGES;
EXIT;
```

### 3. Firewall (ufw)

Se verificó que `ufw` está inactivo en la VM `lukas`, por lo que no fue necesario abrir el puerto 3306 explícitamente:

```bash
sudo ufw status
# Status: inactive
```

Si en el futuro se activa `ufw`, habrá que permitir el acceso puntual:

```bash
sudo ufw allow from 10.33.199.51 to any port 3306
```

### 4. Probar la conexión

**Importante:** este paso se ejecuta **desde la VM de WordPress (`octavio`)**, no desde `lukas`. Si se corre desde `lukas`, la conexión sale con origen `10.33.199.53` y no coincide con el `GRANT`, dando el error:

```
ERROR 2002 (HY000): Received error packet before completion of TLS handshake.
Host '10.33.199.53' is not allowed to connect to this MariaDB server
```

Desde la VM de WordPress:

```bash
# instalar cliente de mysql si no está
sudo apt install mysql-client -y

# probar conexión
mysql -h 10.33.199.53 -u octavio -p octavio_bd
```

Dentro del cliente, verificar tablas:

```sql
SHOW TABLES;
```

