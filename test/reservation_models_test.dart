import 'package:flutter_test/flutter_test.dart';

import 'package:drapemind_mobile/paquetes/reservas_atencion_tienda/dominio/modelos/reservation_models.dart';

void main() {
  test(
    'serializa una variante para reserva múltiple con el contrato del API',
    () {
      const item = ReservationItemRequest(varianteId: 184, cantidad: 2);

      expect(item.toJson(), {'variante_id': 184, 'cantidad': 2});
    },
  );
}
