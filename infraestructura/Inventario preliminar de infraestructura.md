
> Subred de infraestructura: `10.33.199.48/29` (red: .48 · gateway: .52 · broadcast: .55 · host usables: .49–.54) Dominio interno: `tas-06.arpa`
>

| VM/Host         | Rol                                                    | IP privada   | IP pública    | CPU | RAM | Disco | Red                                                          | Dependencias                     |
| --------------- | ------------------------------------------------------ | ------------ | ------------- | --- | --- | ----- | ------------------------------------------------------------ | -------------------------------- |
| Nodo perimetral | DNS (puerto 53) + Nginx (puerto 80), proxy/balanceador | 10.33.199.49 | 10.33.195.184 |     |     |       | Pública + privada                                            | WordPress CMS 1, WordPress CMS 2 |
| WordPress CMS 1 | Backend web (Nginx + PHP-FPM + WordPress), puerto 80   | 10.33.199.51 | 10.33.196.212 |     |     |       | Privada (con salida pública directa a corregir, ver riesgos) | MySQL DB                         |
| WordPress CMS 2 | Backend web (Nginx + PHP-FPM + WordPress), puerto 80   | 10.33.199.50 | —             |     |     |       | Privada                                                      | MySQL DB                         |
| MySQL DB        | Base de datos (MySQL/MariaDB), puerto 3306             | 10.33.199.53 | —             |     |     |       | Privada, solo accesible desde .50 y .51                      | Backend 1, Backend 2             |
