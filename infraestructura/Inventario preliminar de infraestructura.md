
## Nodos - máquinas virtuales

| VM (hostname)    | Nodo    | Rol                        | IP privada   | Servicios                  |
| ---------------- | ------- | -------------------------- | ------------ | -------------------------- |
| `tas-06-jose`    | DNS     | DNS y balanceador de carga | 10.33.199.49 | DNS (53), Nginx (80/443)   |
| `tas-06-02`      | CMS 1   | CMS principal              | 10.33.199.51 | WordPress                  |
| `tas-06-cms-02`  | CMS 2   | CMS, segunda réplica       | 10.33.199.50 | WordPress                  |
| `tas-06-monitor` | Monitor | Monitorización             | 10.33.199.52 | Grafana - Prometheus       |
| `tas-06-****`    | DB      | Base de datos              | 10.33.199.53 | MariaDB (contenedor, 3306) |

### Gestión de credenciales

Las credenciales de las máquinas se resguardan en variables de entorno (archivo `.env` excluido del repositorio con `.gitignore`). 
