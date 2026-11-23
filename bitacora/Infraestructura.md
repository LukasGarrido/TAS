<div align="center">

# Inventario de Infraestructura
**Asignatura:** EIN-090B · Taller de Administración de Sistemas (TAS)  
**Semestre:** 2026  
**Repositorio:** [LukasGarrido/TAS](https://github.com/LukasGarrido/TAS)


</div>

---


## Nodos - máquinas virtuales

| VM (hostname)    | Nodo    | Rol                        | IP privada   | Servicios                  |
| ---------------- | ------- | -------------------------- | ------------ | -------------------------- |
| `jose`    | DNS     | DNS y balanceador de carga | 10.33.199.49 | DNS (53), Nginx (80/443)   |
| `cms-1`      | CMS 1   | CMS principal              | 10.33.199.51 | WordPress                  |
| `cms-2`  | CMS 2   | CMS, segunda réplica       | 10.33.199.50 | WordPress                  |
| `monitor` | Monitor | Monitorización             | 10.33.199.52 | Grafana - Prometheus       |
| `database`    | DB      | Base de datos              | 10.33.199.53 | MariaDB (contenedor, 3306) + nfs |

### Gestión de credenciales

Las credenciales de las máquinas se resguardan en variables de entorno (archivo `.env` excluido del repositorio con `.gitignore`). 
