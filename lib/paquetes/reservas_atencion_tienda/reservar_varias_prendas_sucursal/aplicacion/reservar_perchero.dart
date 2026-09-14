import 'package:drapemind_mobile/paquetes/reservas_atencion_tienda/datos/servicios/reservation_service.dart';
import 'package:drapemind_mobile/paquetes/reservas_atencion_tienda/dominio/modelos/reservation_models.dart';
import 'package:drapemind_mobile/paquetes/sucursales_inventario_proveedores/datos/servicios/preferred_branch_store.dart';

class ReservarPerchero {
  final ReservationService _reservations;
  final PreferredBranchStore _preferredBranch;

  ReservarPerchero({
    ReservationService? reservations,
    PreferredBranchStore? preferredBranch,
  }) : _reservations = reservations ?? ReservationService(),
       _preferredBranch = preferredBranch ?? PreferredBranchStore();

  Future<Reservation> call({String? observacion}) async {
    final branchId = await _preferredBranch.read();
    return _reservations.createReservationFromCart(
      sucursalId: branchId,
      observacion: observacion,
    );
  }
}
