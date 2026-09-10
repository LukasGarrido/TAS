# Instalación de WordPress en Ubuntu 24.04 con Nginx + PHP-FPM + MySQL

Partiendo de una VM con Node.js, MySQL y Nginx ya instalados.

## Instalación de PHP-FPM y extensiones

Ejecutar:

```bash
sudo apt update
sudo apt install php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip php8.3-intl -y
```

## Verificación del servicio PHP-FPM

Ejecutar:

```bash
sudo systemctl status php8.3-fpm
```

## Verificación del socket de PHP-FPM

Ejecutar:

```bash
ls /run/php/
```

Salida:

```
php8.3-fpm.sock
```

## Desactivación de Apache

Apache puede quedar instalado junto con `libapache2-mod-php` e intentar tomar el puerto 80, chocando con Nginx. Como no se usa, se desactiva:

```bash
sudo systemctl disable apache2
```

## Permisos de los archivos de WordPress

Con los archivos ya copiados en `/var/www/html`:

```bash
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;
```

## Creación de la base de datos y el usuario en MySQL

Ejecutar:

```bash
sudo mysql -u root -p
```

```sql
CREATE DATABASE octavio_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'octavio'@'localhost' IDENTIFIED BY '<hidden_password>';
GRANT ALL PRIVILEGES ON octavio_db.* TO 'octavio'@'localhost';
FLUSH PRIVILEGES;
SHOW DATABASES;
EXIT;
```

## Configuración del bloque de servidor en Nginx

Editar:

```bash
sudo nano /etc/nginx/sites-available/default
```

Cambios aplicados dentro del bloque `server { ... }`:

```nginx
index index.php index.html index.htm index.nginx-debian.html;

location / {
        try_files $uri $uri/ /index.php?$args;
}

location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
}
```

## Validación y recarga de Nginx

Ejecutar:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Salida:

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## Acceso al sitio

Ejecutar:

```bash
ip a
```

Abrir en el navegador:

```
http://10.33.195.212
```

