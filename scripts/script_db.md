## Copia de base de datos

Nombre de la copia: `octavio_bd_backup.sql`

## Script SQL para crear base y usuario

```sql
CREATE DATABASE octavio_bd;
CREATE USER 'octavio'@'localhost' IDENTIFIED BY '<hidden_password>';
GRANT ALL PRIVILEGES ON octavio_bd.* TO 'octavio'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

## Ver tablas en MySQL

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
| wp_postmeta           |
| wp_posts              |
| wp_term_relationships |
| wp_term_taxonomy      |
| wp_termmeta           |
| wp_terms              |
| wp_usermeta           |
| wp_users              |
+-----------------------+
```