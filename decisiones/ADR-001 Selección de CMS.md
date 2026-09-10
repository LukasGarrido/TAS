## Contexto

Nodo sur necesita de una plataforma que ayude a personal sin formación técnica publicar catálogo, gestionar pedidos, administrar reservas con cupos limitados y mantener contenidos, todo desde un único dominio
## Opciones consideradas

**WordPress + WooCommerce**

- Licenciamiento GPL, gratuito.
- Comunidad y documentación muy grandes, con ecosistema maduro de plugins de e-commerce y reservas.
- Curva de operación baja, administrable por personal sin equipo técnico.
- Límite conocido: el rendimiento depende de una buena configuración de caché cuando se usan muchos plugins.

**Joomla**

- Licenciamiento GPL, gratuito.
- Comunidad grande (tercer CMS más usado a nivel mundial), pero con un ecosistema de extensiones más pequeño que el de WordPress.
- Curva de operación media: requiere entender su estructura propia de artículos, categorías y menús, más rígida que WordPress.
- Límite conocido: no tiene un módulo de e-commerce/reservas tan maduro como WooCommerce; extensiones como VirtueMart o HikaShop están menos pulidas y bien integradas.

**Drupal**

- Licenciamiento GPL, gratuito.
- Comunidad grande pero orientada a desarrolladores y proyectos enterprise/gobierno, con menor foco en e-commerce.
- Curva de operación alta: requiere conocimientos técnicos serios de arquitectura de contenidos, módulos, y en ocasiones uso de Drush/CLI.
- Límite conocido: no tiene e-commerce/reservas nativo; requeriría Drupal Commerce y trabajo de desarrollo a medida, con un mantenimiento más costoso.

## Decisión

Se selecciona **WordPress + WooCommerce**, servido por **Nginx**

**Motivo de descarte Joomla:** el caso de negocio necesita catálogo, cupos y venta directa. Hacerlo funcionar en Joomla implica sumar extensiones de terceros poco integradas entre sí, agregando fragilidad sin un beneficio real sobre WordPress.

**Motivo de descarte Drupal:** Drupal está pensado para sitios complejos con lógica de contenido avanzada, no para una tienda con reservas simple. Usarlo exigiría un equipo de desarrollo dedicado, contradiciendo la necesidad de operación con personal sin equipo técnico permanente.

## Justificación técnica adicional (WordPress + Nginx)

- Nginx maneja mejor conexiones concurrentes con menos consumo de recursos que Apache, relevante porque el caso explícitamente menciona picos de tráfico en campañas de difusión (RNF-01, disponibilidad).
- WordPress + WooCommerce cubre en un solo stack: catálogo, pedidos, contenido (blog/páginas) y con el plugin adicional de reservas el flujo de talleres con cupos limitados.
- Al ser PHP + MySQL, es totalmente compatible con la arquitectura de referencia del enunciado (backend web separado de una base de datos independiente).

## Consecuencias

- Se depende del ecosistema de plugins de WordPress para cubrir reservas con cupos, su elección concreta debe evaluarse y documentarse en la Entrega 2.
- Se debe cuidar el rendimiento con una configuración de caché adecuada, ya que el caso anticipa picos de tráfico durante campañas de difusión.
- Queda descartado usar Joomla o Drupal como base, evitando sumar fragilidad por extensiones de terceros (Joomla) o exigir un equipo de desarrollo dedicado que la organización no tiene (Drupal).