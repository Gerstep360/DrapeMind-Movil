# Paquetes funcionales móviles

La app Flutter agrupa negocio por paquete y caso de uso. `core/` conserva sólo
infraestructura transversal (configuración, HTTP/WebSocket, tema y métricas);
`compartido/componentes/` contiene piezas visuales sin reglas de negocio.

## Acceso y gestión de usuarios

- `registrar_cliente/`: onboarding, sucursal preferida y perfil inicial.
- `iniciar_sesion/`: acceso, restauración de sesión y bloqueo local.
- `gestionar_cuenta/`: perfil, direcciones, favoritos y preferencias.
- `dominio/` y `datos/`: modelos y servicios compartidos por esos flujos.

## Catálogo y comercialización

- `consultar_catalogo_prendas/`: escaparate y navegación del catálogo.
- `buscar_filtrar_prendas/`: estado, presets y algoritmo de filtros.
- `consultar_detalle_talla_color_variante/`: ficha, variantes y acceso a stock.
- `dominio/` y `datos/`: producto, categoría y acceso al catálogo.

## Carrito, pedidos y pagos

- `gestionar_carrito_perchero/`: selección, cantidades y resumen.
- `realizar_checkout_entrega_recojo/`: dirección y modalidad de entrega.
- `procesar_confirmar_pago_electronico/`: pago Stripe/mock y confirmación.
- `consultar_pedidos_historial_compras/`: pedidos y comprobantes.
- `dominio/` y `datos/`: carrito, pedido, pago y servicios asociados.

## Reservas y atención en tienda

- `reservar_varias_prendas_sucursal/`: reserva transaccional del perchero en
  la sucursal elegida durante onboarding.
- `consultar_qr_cancelar_reserva/`: listado, QR y cancelación.
- La creación de reserva se inicia desde la ficha o el vestidor y reutiliza
  `ReservationService`; no se duplica lógica de red en esas pantallas.

## Inteligencia artificial y asistencia de moda

- `consultar_asistente_altair/`: chat, sesiones, selector Mini/Dinámico/Gemma.
- `aplicar_recomendacion_carrito/`: traduce acciones verificadas de Altair a
  operaciones reales de carrito.
- Búsqueda natural, generación y ampliación de outfit usan el mismo canal
  `AiSocketService`; la UI no implementa respuestas prefabricadas del modelo.

## Realidad aumentada

- `utilizar_vestidor_virtual/`: cámara, geometría corporal, overlay de prenda y
  renderizadores separados de la pantalla.

## Sucursales, inventario y proveedores

- En móvil sólo aplica consultar disponibilidad por sucursal. Modelos y acceso
  remoto viven en este paquete y son consumidos desde detalle/onboarding.
- Gestión operativa de inventario permanece fuera del móvil porque su canal es
  Web según la matriz del proyecto.

Los CU exclusivamente Web (recibir/preparar reservas, convertir en venta,
inventario operativo, POS y gestión logística) no se duplican en Flutter.
