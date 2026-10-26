# 📱 DrapeMind Mobile App (Flutter)

Aplicación móvil oficial de **DrapeMind** para clientes y personal de tienda, desarrollada con **Flutter** y **Provider**.

## Acceso automático y tiendas · v1.0.11

El formulario solicita correo y contraseña. El backend identifica la empresa y el rol guardados; no hay selectores de administración ni campos de empresa. Las cuentas SaaS abren un resumen de empresas y las cuentas empresariales conservan su contexto. Los enlaces `drapemind://tienda/<slug>` permiten entrar directamente a una tienda.

Los clientes conservan una cuenta personal al visitar varias tiendas. «Cambiar de tienda» está en Mi perfil. Cada tienda mantiene su carrito, pedidos, conversaciones y disponibilidad; las preferencias declaradas y direcciones pertenecen a la cuenta personal. El recojo exige una sucursal y el checkout confirma el stock de esa sede. Los comprobantes recuperan la empresa y sucursal de la compra.

La compilación de producción usa `https://167.86.106.105/DrapeMind`. Las credenciales y los permisos se validan en el servidor. Los accesos genéricos de demostración no aparecen como botones en el formulario. Detalles del contrato de acceso: [documentación del backend](../backend/docs/ACCESO_UNIFICADO.md).

## Backend local y nueva arquitectura Altair

Abrir el panel con `python iniciar_backend.py` desde la raíz del proyecto. En emulador Android:

```powershell
flutter run --dart-define=DRAPEMIND_API_URL=http://10.0.2.2:8000
```

En teléfono físico, activar acceso LAN en el panel y usar la IP del PC. Para ADB Reverse, usar `http://127.0.0.1:8000`. La URL definida por compilación tiene prioridad; sin ella se conserva la configuración de servidor de la app.

Altair usa el proveedor del backend, sin claves ni selección de múltiples modelos en la app. El chat admite respuestas simultáneas identificadas por mensaje y descarta resultados cancelados. El onboarding guarda las preferencias y muestra una inferencia breve de estilo, con reintento si el proveedor falla. Detalles: [guía del backend](../backend/README.md).

---

## 🚀 Descarga y Versión de Producción (Release)

La compilación de distribución fija `https://167.86.106.105/DrapeMind` mediante `DRAPEMIND_API_URL`. Ese valor tiene prioridad sobre una dirección local guardada anteriormente en el teléfono.

### Compilar y compartir la APK actual

```powershell
powershell -ExecutionPolicy Bypass -File scripts/compilar_apk_vps.ps1
```

El script necesita Flutter en PATH; también acepta `-FlutterExecutable C:/Dev/flutter/bin/flutter.bat`. Genera `build/app/outputs/flutter-apk/DrapeMind-1.0.11+12.apk` y `release-vps.json` con versión, URL y SHA256, sin claves ni contraseñas. Comparte ese archivo con los usuarios de prueba. Las [publicaciones de GitHub](https://github.com/Gerstep360/DrapeMind-Movil/releases) anteriores a esta versión no contienen los cambios actuales; crear una compilación local no publica una nueva release automáticamente.

Si un acceso falla, comprueba primero la versión instalada y el mensaje del formulario. Las cuentas de demostración del seeder local no existen automáticamente en producción; un 401 indica que el servidor rechazó las credenciales. No es necesario reinstalar ni volver a ejecutar el seeder para validar una cuenta existente.

Desde Mi perfil, el cliente puede cambiar de tienda con una sola cuenta. `drapemind://tienda/<slug>` abre el contexto de una tienda en Android; los enlaces HTTPS abren actualmente la web, pues todavía no se han configurado Android App Links verificados. Preferencias y direcciones son personales; carrito, favoritos, pedidos y chats se mantienen por tienda.

### Historial v1.0.5 (Modularización, Pasarela Stripe y Vestidor RA)
* **Arquitectura Modular por Paquetes:** Reestructuración completa a arquitectura basada en paquetes de negocio (`lib/paquetes/`, `lib/compartido/`, `lib/navegacion/`) garantizando escalabilidad y modularidad limpia.
* **Pasarela de Pago Electrónico Stripe (CU-11):** Integración nativa de cobro con tarjeta de crédito/débito virtual en entorno sandbox, cálculo dinámico de recargos y confirmación de pago atómica.
* **Probador Virtual por Realidad Aumentada (CU-17):** Estimación de pose corporal on-device, calibración geométrica de prendas textiles y ajuste en tiempo real sobre la cámara.
* **Sincronización en Tiempo Real de Pedidos y Reservas:** Integración de sockets de eventos para actualización reactiva del estado de preparación y despacho de compras.
* **Reglas de Compilación R8 / Proguard:** Optimización de compilación con reglas específicas para SDKs nativos y compatibilidad con Android 12+ / 14+.

---

## 🌐 Configuración del Servidor (VPS Producción)

La aplicación viene configurada de fábrica en [`lib/core/config/api_config.dart`](lib/core/config/api_config.dart) para comunicarse automáticamente con el servidor en la nube:

* **Servidor VPS:** `https://167.86.106.105/DrapeMind`
* **API REST:** `https://167.86.106.105/DrapeMind/api/v1`
* **WebSockets Altair IA:** `wss://167.86.106.105/DrapeMind/api/v1/ws/ai`
* **WebSockets Eventos en Tiempo Real:** `wss://167.86.106.105/DrapeMind/api/v1/ws/events`

Para desarrollo local utiliza el comando `flutter run --dart-define=DRAPEMIND_API_URL=...` indicado arriba. La opción avanzada de conexión del login solo aparece en debug con `DRAPEMIND_DEV_CONNECTION=true`; la URL fijada en una APK de distribución tiene prioridad sobre la configuración guardada.

---

## 📲 Cómo Instalar el APK en Android

1. Copia al teléfono la APK actual `DrapeMind-1.0.11+12.apk`, generada mediante el script de compilación anterior.
2. Abre el archivo descargado. Si Android te solicita permisos, activa la opción **"Permitir desde esta fuente"** o **"Instalar aplicaciones de fuentes desconocidas"**.
3. Presiona **Instalar** y luego **Abrir**.
4. Abre la app e inicia sesión con una cuenta existente en el VPS o crea una cuenta personal. Los empleados acceden a su empresa; los clientes pueden visitar las tiendas disponibles.

---

## ✨ Funcionalidades Principales

* **Catálogo Omnicanal:** Exploración de prendas, filtros por talla, color, material, precio y género.
* **Asistente Inteligente Altair:** Chat conversacional mediante NVIDIA API desde FastAPI para asesoría de imagen, outfits personalizados y búsqueda con herramientas del catálogo.
* **Probador Virtual (Realidad Aumentada):** Superposición de prendas sobre la cámara frontal con calibración de escala y proporciones.
* **Perchero Digital & Carrito:** Gestión de prendas seleccionadas con cálculo de subtotal.
* **Reservas con Código QR:** Apartado de prendas en sucursal física con generación de código QR criptográfico y temporizador de expiración (TTL).
* **Escáner QR para Tienda:** Modo vendedor/encargado para validar y despachar reservas en tiempo real.
