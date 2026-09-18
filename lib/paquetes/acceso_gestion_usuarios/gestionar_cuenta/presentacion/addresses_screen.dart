import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/datos/servicios/address_service.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/dominio/modelos/address_models.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final AddressService _addressService = AddressService();
  List<Address> _addresses = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final list = await _addressService.getMyAddresses();
      if (mounted) {
        setState(() {
          _addresses = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Error al cargar direcciones de entrega.', danger: true);
      }
    }
  }

  void _showMessage(String text, {bool danger = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: danger ? AppColors.danger : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteAddress(Address address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paperLight,
        title: const Text('Eliminar dirección'),
        content: Text('Deseas eliminar "${address.alias}" de tus direcciones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _addressService.deleteAddress(address.id);
      _showMessage('Dirección eliminada correctamente.');
      await _loadAddresses();
    } catch (e) {
      _showMessage('No se pudo eliminar la dirección.', danger: true);
    }
  }

  Future<void> _setAsPrimary(Address address) async {
    if (address.esPrincipal) return;
    try {
      final input = AddressInput(
        alias: address.alias,
        departamento: address.departamento,
        ciudad: address.ciudad,
        zona: address.zona,
        direccion: address.direccion,
        referencia: address.referencia,
        telefonoContacto: address.telefonoContacto,
        esPrincipal: true,
      );
      await _addressService.updateAddress(address.id, input);
      _showMessage('Dirección principal actualizada.');
      await _loadAddresses();
    } catch (e) {
      _showMessage('No se pudo establecer como principal.', danger: true);
    }
  }

  Future<void> _showAddressForm([Address? address]) async {
    final formKey = GlobalKey<FormState>();
    final aliasCtrl = TextEditingController(text: address?.alias ?? 'Casa');
    final deptCtrl = TextEditingController(text: address?.departamento ?? 'La Paz');
    final cityCtrl = TextEditingController(text: address?.ciudad ?? 'La Paz');
    final zoneCtrl = TextEditingController(text: address?.zona ?? '');
    final streetCtrl = TextEditingController(text: address?.direccion ?? '');
    final refCtrl = TextEditingController(text: address?.referencia ?? '');
    final phoneCtrl = TextEditingController(text: address?.telefonoContacto ?? '');
    bool isPrimary = address?.esPrincipal ?? _addresses.isEmpty;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(ctx).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.lineStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      address == null
                          ? 'NUEVA DIRECCIÓN DE ENTREGA'
                          : 'MODIFICAR DIRECCIÓN',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: aliasCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Alias (ej. Casa, Oficina, Atelier)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: deptCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Departamento',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ciudad',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: zoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Zona o Barrio',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: streetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dirección exacta (Calle, Nro, Edificio)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 4)
                              ? 'Ingresa una dirección válida'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Referencia para entrega',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono de contacto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Marcar como dirección principal',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      value: isPrimary,
                      activeColor: AppColors.ink,
                      onChanged: (val) => setModalState(() => isPrimary = val),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.lime,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => _isSaving = true);
                              try {
                                final input = AddressInput(
                                  alias: aliasCtrl.text,
                                  departamento: deptCtrl.text,
                                  ciudad: cityCtrl.text,
                                  zona: zoneCtrl.text.isEmpty ? null : zoneCtrl.text,
                                  direccion: streetCtrl.text,
                                  referencia: refCtrl.text.isEmpty ? null : refCtrl.text,
                                  telefonoContacto: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                                  esPrincipal: isPrimary,
                                );
                                if (address == null) {
                                  await _addressService.createAddress(input);
                                } else {
                                  await _addressService.updateAddress(address.id, input);
                                }
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                setModalState(() => _isSaving = false);
                              }
                            },
                      child: Text(
                        address == null ? 'Guardar Dirección' : 'Actualizar Dirección',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      _showMessage(
        address == null
            ? 'Nueva dirección registrada con éxito.'
            : 'Dirección actualizada.',
      );
      await _loadAddresses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Direcciones de Entrega'),
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Añadir dirección',
            onPressed: () => _showAddressForm(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
          : _addresses.isEmpty
              ? _buildEmptyState()
              : _buildAddressList(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.lime,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () => _showAddressForm(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Añadir Nueva Dirección (CU-03)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.paperLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_outlined,
                size: 34,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No tienes direcciones guardadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Registra tu domicilio habitual o taller para despachos directos de tus compras.',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _addresses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _addresses[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.esPrincipal ? AppColors.ink : AppColors.line,
              width: item.esPrincipal ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.esPrincipal ? AppColors.ink : AppColors.paperLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.alias.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: item.esPrincipal ? AppColors.lime : AppColors.ink,
                      ),
                    ),
                  ),
                  if (item.esPrincipal) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'PRINCIPAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Editar dirección',
                    onPressed: () => _showAddressForm(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Eliminar dirección',
                    color: AppColors.danger,
                    onPressed: () => _deleteAddress(item),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.direccion,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (item.zona != null && item.zona!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.zona!,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                '${item.ciudad}, ${item.departamento}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              if (item.telefonoContacto != null &&
                  item.telefonoContacto!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      item.telefonoContacto!,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
              if (!item.esPrincipal) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _setAsPrimary(item),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Marcar como dirección predeterminada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
