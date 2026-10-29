# Incremento II: CU-11 a CU-14

| Caso | Implementación |
| --- | --- |
| CU-11 Proveedores y abastecimiento | Canal Web. proveedor_web_screen.dart abre el portal para el rol PROVEEDOR |
| CU-12 Descargar catálogo | offline/offline_service.dart, models.dart y offline_store.dart |
| CU-13 Consultar prendas y disponibilidad | offline/offline_screen.dart |
| CU-14 Registrar solicitudes sin conexión | cola SQLite y sincronización en offline/offline_service.dart |

Acceso desde Mi perfil, botón Sin conexión. Cuando falta señal o hay solicitudes pendientes también aparece un acceso en la tienda.

SQLite almacena catálogo, primeras fotografías y solicitudes por URL del servidor, tenant y usuario. Cambiar de tienda o cerrar sesión oculta el contexto anterior y conserva sus pendientes bajo su propietario. La descarga vence como máximo en 24 horas o al vencer la suscripción. No contiene contraseñas, tarjetas ni direcciones personales.

Cada solicitud tiene UUID estable y se guarda antes de enviarse. Tras una respuesta perdida se comprueba esa misma operación; no se permite cancelarla como si nunca se hubiera enviado. El backend confirma la reserva con stock y precios actuales. El QR se consulta en Reservas después de la confirmación.

Pruebas: test/incremento_ii_offline_test.dart incluye reapertura real de SQLite, separación de propietarios, respuesta perdida, caducidad y pantallas de 320/390 px. Evidencias visuales: qa/incremento-ii.

Compilación VPS: scripts/compilar_apk_vps.ps1; la URL HTTPS se fija mediante DRAPEMIND_API_URL.
