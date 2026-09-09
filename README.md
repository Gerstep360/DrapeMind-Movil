# 📱 DrapeMind Mobile App (Flutter)

Aplicación móvil oficial de **DrapeMind** para clientes y personal de tienda, desarrollada con **Flutter** y **Riverpod**.

---

## 🚀 Descarga y Versión de Producción (Release)

La aplicación ya se encuentra compilada y preconfigurada para conectarse directamente al servidor VPS de producción.

### 📥 Enlaces de Descarga Directa:
* **[Descargar APK Release v1.0.2 (drapemind-release.apk)](https://github.com/Gerstep360/DrapeMind-Movil/releases/download/v1.0.2/drapemind-release.apk)** *(24 MB)*
* **[Descarga alternativa (app-release.apk)](https://github.com/Gerstep360/DrapeMind-Movil/releases/download/v1.0.2/app-release.apk)**
* **[Ver Release Oficial en GitHub (Tag v1.0.2)](https://github.com/Gerstep360/DrapeMind-Movil/releases/tag/v1.0.2)**

### 📋 Novedades v1.0.2 (Recepción/Ajustes CU-35 y Optimizaciones):
* **Gestión y Auditoría de Inventario (CU-35):** Soporte en cliente para recepción de mercadería (`ENTRADA`) y ajustes físicos (`AJUSTE`) con aislamiento y sincronización por sucursal.
* **Streaming de Respuestas en Tiempo Real:** Recepción de snapshots del campo público `answer` vía WebSockets conforme el modelo genera el texto, eliminando esperas completas y animación artificial de escritura por bloques.
* **Privacidad y Auditoría Limpia:** Filtrado de razonamiento interno (`reasoning_content`) y llamadas crudas a herramientas. La auditoría de acciones refleja exclusivamente consultas reales a herramientas con indicador fiel de éxito o error.
* **Sugerencias Interactivas del Modelo:** Soporte para botones de sugerencia contextuales generados por Altair para continuar el diálogo con un solo toque.
* **Optimización y Accesibilidad:** Ajustes de rendimiento para entornos de CPU y soporte para modo de movimiento reducido en indicadores.

---

## 🌐 Configuración del Servidor (VPS Producción)

La aplicación viene configurada de fábrica en [`lib/core/config/api_config.dart`](lib/core/config/api_config.dart) para comunicarse automáticamente con el servidor en la nube:

* **Servidor VPS:** `http://157.173.102.129/DrapeMind`
* **API REST:** `http://157.173.102.129/DrapeMind/api/v1`
* **WebSockets Altair IA:** `ws://157.173.102.129/DrapeMind/api/v1/ws/ai`
* **WebSockets Eventos en Tiempo Real:** `ws://157.173.102.129/DrapeMind/api/v1/ws/events`

> [!NOTE]
> **Cambio dinámico de servidor:** Desde la pantalla de Login o desde el Perfil de Usuario, puedes presionar el botón de configuración de red para cambiar manualmente la IP (ej. a una IP local `192.168.x.x:8000`) si deseas probar en entorno de desarrollo local.

---

## 📲 Cómo Instalar el APK en Android

1. Descarga el archivo [drapemind-release.apk](https://github.com/Gerstep360/DrapeMind-Movil/releases/download/v1.0.0/drapemind-release.apk) directamente en tu teléfono celular o emulador Android.
2. Abre el archivo descargado. Si Android te solicita permisos, activa la opción **"Permitir desde esta fuente"** o **"Instalar aplicaciones de fuentes desconocidas"**.
3. Presiona **Instalar** y luego **Abrir**.
4. ¡Listo! La app se conectará automáticamente al catálogo y servicios de IA en el VPS.

---

## ✨ Funcionalidades Principales

* **Catálogo Omnicanal:** Exploración de prendas, filtros por talla, color, material, precio y género.
* **Asistente Inteligente Altair:** Chat conversacional con IA (Google Gemini) para asesoría de imagen, outfits personalizados y búsqueda semántica en lenguaje natural.
* **Probador Virtual (Realidad Aumentada):** Superposición de prendas sobre la cámara frontal con calibración de escala y proporciones.
* **Perchero Digital & Carrito:** Gestión de prendas seleccionadas con cálculo de subtotal.
* **Reservas con Código QR:** Apartado de prendas en sucursal física con generación de código QR criptográfico y temporizador de expiración (TTL).
* **Escáner QR para Tienda:** Modo vendedor/encargado para validar y despachar reservas en tiempo real.
