# Android 1.2.1+15 — Incremento II

Incluye los CU-12 a CU-17 y CU-19: descarga por cuenta, catálogo offline, solicitudes de reserva, caja en efectivo, resultados de sincronización y retiros de reservas. El personal de tienda entra a Caja y reservas. Proveedores, revisión administrativa y cambios se gestionan en la web.

La cola SQLite guarda el cuerpo y UUID antes de enviar. Un cambio de sesión detiene los envíos y no permite cancelar solicitudes de otra cuenta. Una respuesta perdida conserva la operación y recupera su resultado sin duplicar cobros ni reservas.

- Backend: `https://167.86.106.105/DrapeMind`.
- Validación: 56 pruebas Flutter aprobadas; análisis sin incidencias.
- Compilación limpia de producción; URL y rutas de caja verificadas en el binario ARM64.
- Sin prueba manual en un teléfono físico.
- APK: `DrapeMind-1.2.1+15.apk`.
- SHA256: `ab9be05e4bb45605c7f19b5c1eb7f09d423c598ce52885c123d32ddc6921741f`.

[Descarga y manifiesto del release](https://github.com/Gerstep360/DrapeMind-Movil/releases/tag/v1.2.1).
