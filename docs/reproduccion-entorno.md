# Guía de Reproducción y Levantamiento del Entorno — Nodo Sur

Los secretos nunca se versionan: cada nodo utiliza su propio archivo `.env` (con permisos `600`), creado a partir de los valores de referencia `.env.example`.

## Orden de Ejecución

1. **Docker en todos los nodos:**  
   Consulte `scripts/scripts_docker.md` para la instalación y configuración del motor Docker y Docker Compose.

2. **Base de datos y NFS (VM `db` · `10.33.199.53`):**  
   - Levantar MariaDB 11 mediante su compose y `.env`.  
   - Configurar el servidor NFS exportando `/srv/nfs/wordpress` según `scripts/scripts_Servidor_NFS.md`.

3. **Backends WordPress (`cms-1` · `10.33.199.51` y `cms-2` · `10.33.199.50`):**  
   - Montar el almacenamiento NFS compartido y desplegar WordPress con MariaDB remoto (`scripts/scripts_wordpress.md`).

4. **Nodo Perimetral (`dns` · `10.33.199.49`):**  
   - Configurar BIND9 para la resolución interna de `tas-06.arpa`.  
   - Configurar Nginx como proxy inverso, terminación TLS y balanceador de carga pasivo con round-robin hacia los backends.

5. **Monitorización (`monitor` · `10.33.199.52`):**  
   - Desplegar Prometheus, Alertmanager, Loki y Grafana (`scripts/scripts_VM-Monitoreo.md`).  
   - Configurar exporters para Nginx (`scripts/scripts_monitorización.md`), Apache y MariaDB (`scripts/scripts_DataBase-Grafana.md`).

6. **Red y Firewall (UFW y `DOCKER-USER`):**  
   - Aislar las interfaces de red y configurar UFW y las reglas persistentes en la cadena `DOCKER-USER` (`scripts/scripts_firewall_ufw.md`).

7. **Verificación:**  
   - Ejecutar las pruebas de validación de la matriz de trazabilidad y verificar flujos completos (RF-01, RNF-01 a RNF-08).
