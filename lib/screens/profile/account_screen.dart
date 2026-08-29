import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core.dart';
import '../../core/theme/app_colors.dart';
import '../catalog/product_detail_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _addressService = AddressService();
  final _catalogService = CatalogService();
  final _branchService = BranchService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  List<Address> _addresses = [];
  List<Product> _favorites = [];
  List<Branch> _branches = [];
  bool _loading = true;
  bool _savingProfile = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthService>().currentUser;
      _nameController.text = user?.nombre ?? '';
      _phoneController.text = user?.telefono ?? '';
      _loadAccount();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _addressService.getMyAddresses(),
        _catalogService.getFavorites(),
        _branchService.getBranches(),
      ]);
      if (!mounted) return;
      setState(() {
        _addresses = results[0] as List<Address>;
        _favorites = results[1] as List<Product>;
        _branches = results[2] as List<Branch>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos sincronizar todos los datos de tu cuenta.';
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().length < 2) {
      _showMessage('Escribe un nombre válido.', danger: true);
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await context.read<AuthService>().updateProfile(
        nombre: _nameController.text,
        telefono: _phoneController.text,
      );
      if (mounted) _showMessage('Perfil actualizado.');
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo actualizar el perfil.', danger: true);
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _removeFavorite(Product product) async {
    final previous = List<Product>.from(_favorites);
    setState(() => _favorites.removeWhere((item) => item.id == product.id));
    try {
      await _catalogService.removeFavorite(product.id);
      if (mounted) _showMessage('${product.nombre} salió de favoritos.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorites = previous);
      _showMessage('No se pudo cambiar el favorito.', danger: true);
    }
  }

  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: Text('¿Quieres eliminar “${address.alias}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Conservar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _addressService.deleteAddress(address.id);
      await _loadAccount();
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo eliminar la dirección.', danger: true);
      }
    }
  }

  Future<void> _showAddressEditor([Address? address]) async {
    final formKey = GlobalKey<FormState>();
    final alias = TextEditingController(text: address?.alias ?? 'Casa');
    final department = TextEditingController(
      text: address?.departamento ?? 'La Paz',
    );
    final city = TextEditingController(text: address?.ciudad ?? 'La Paz');
    final zone = TextEditingController(text: address?.zona ?? '');
    final street = TextEditingController(text: address?.direccion ?? '');
    final reference = TextEditingController(text: address?.referencia ?? '');
    final contact = TextEditingController(
      text: address?.telefonoContacto ?? '',
    );
    var isPrimary = address?.esPrincipal ?? _addresses.isEmpty;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperLight,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: AppColors.lineStrong,
                    ),
                    Text(
                      address == null ? 'NUEVA DIRECCIÓN' : 'EDITAR DIRECCIÓN',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(alias, 'Alias', required: true),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            department,
                            'Departamento',
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _field(city, 'Ciudad', required: true)),
                      ],
                    ),
                    _field(zone, 'Zona'),
                    _field(
                      street,
                      'Dirección exacta',
                      required: true,
                      minLength: 5,
                    ),
                    _field(reference, 'Referencia'),
                    _field(
                      contact,
                      'Teléfono de contacto',
                      keyboardType: TextInputType.phone,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.forest,
                      value: isPrimary,
                      onChanged: (value) =>
                          setSheetState(() => isPrimary = value ?? false),
                      title: const Text(
                        'Usar como dirección principal',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        final input = AddressInput(
                          alias: alias.text,
                          departamento: department.text,
                          ciudad: city.text,
                          zona: zone.text,
                          direccion: street.text,
                          referencia: reference.text,
                          telefonoContacto: contact.text,
                          esPrincipal: isPrimary,
                        );
                        try {
                          if (address == null) {
                            await _addressService.createAddress(input);
                          } else {
                            await _addressService.updateAddress(
                              address.id,
                              input,
                            );
                          }
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext, true);
                          }
                        } catch (_) {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo guardar la dirección.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        address == null
                            ? 'Guardar dirección'
                            : 'Aplicar cambios',
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

    for (final controller in [
      alias,
      department,
      city,
      zone,
      street,
      reference,
      contact,
    ]) {
      controller.dispose();
    }
    if (saved == true) await _loadAccount();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int minLength = 2,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => (value?.trim().length ?? 0) < minLength
                  ? 'Completa este campo'
                  : null
            : null,
      ),
    );
  }

  void _showMessage(String message, {bool danger = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: danger ? AppColors.danger : AppColors.forest,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('MI CUENTA EN EL ATELIER')),
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: _loadAccount,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.forestDark,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.acid,
                    child: Text(
                      (user?.nombre.isNotEmpty == true
                              ? user!.nombre.substring(0, 1)
                              : 'D')
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nombre ?? 'Cliente Atelier',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            color: AppColors.paper,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          user?.rol.toServerString() ?? 'CLIENTE',
                          style: const TextStyle(
                            color: AppColors.acid,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _Notice(message: _error!),
            ],
            const SizedBox(height: 16),
            _Section(
              eyebrow: 'DATOS PERSONALES',
              title: 'Tu perfil',
              trailing: _savingProfile
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _saveProfile,
                      child: const Text('Guardar'),
                    ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Section(
              eyebrow: 'ENTREGAS',
              title: 'Tus direcciones',
              trailing: TextButton.icon(
                onPressed: () => _showAddressEditor(),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Añadir'),
              ),
              child: _loading
                  ? const LinearProgressIndicator()
                  : _addresses.isEmpty
                  ? const _EmptyCopy(
                      text:
                          'Guarda una dirección para agilizar tu próxima compra.',
                    )
                  : Column(
                      children: _addresses
                          .map(
                            (address) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                address.esPrincipal
                                    ? Icons.home_filled
                                    : Icons.location_on_outlined,
                                color: AppColors.forest,
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      address.alias,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (address.esPrincipal)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text(
                                        'PRINCIPAL',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.forest,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                address.formattedAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) => action == 'edit'
                                    ? _showAddressEditor(address)
                                    : _deleteAddress(address),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 14),
            _Section(
              eyebrow: 'SELECCIÓN PERSONAL',
              title: 'Favoritos',
              child: _favorites.isEmpty
                  ? const _EmptyCopy(
                      text:
                          'Marca prendas con el corazón para encontrarlas aquí.',
                    )
                  : SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _favorites.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, index) {
                          final product = _favorites[index];
                          return SizedBox(
                            width: 150,
                            child: Material(
                              color: AppColors.paperLight,
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      productId: product.id,
                                    ),
                                  ),
                                ).then((_) => _loadAccount()),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          product.mainImageUrl.isEmpty
                                              ? const ColoredBox(
                                                  color: AppColors.paperDark,
                                                  child: Icon(
                                                    Icons.checkroom,
                                                    color: AppColors.forest,
                                                  ),
                                                )
                                              : Image.network(
                                                  product.mainImageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const ColoredBox(
                                                        color:
                                                            AppColors.paperDark,
                                                        child: Icon(
                                                          Icons.checkroom,
                                                        ),
                                                      ),
                                                ),
                                          Positioned(
                                            top: 5,
                                            right: 5,
                                            child: IconButton.filledTonal(
                                              onPressed: () =>
                                                  _removeFavorite(product),
                                              icon: const Icon(
                                                Icons.favorite,
                                                size: 17,
                                              ),
                                              tooltip: 'Quitar de favoritos',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.nombre,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            'Bs ${product.precio.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppColors.forest,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            _Section(
              eyebrow: 'SHOWROOMS',
              title: 'Dónde encontrarnos',
              child: _branches.isEmpty
                  ? const _EmptyCopy(
                      text:
                          'Las sucursales aparecerán cuando el servidor esté disponible.',
                    )
                  : Column(
                      children: _branches
                          .map(
                            (branch) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.storefront_outlined,
                                color: AppColors.forest,
                              ),
                              title: Text(
                                branch.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${branch.direccion}\n${branch.ciudad ?? ''}${branch.departamento == null ? '' : ', ${branch.departamento}'}',
                              ),
                              isThreeLine: true,
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 14),
            _Section(
              eyebrow: 'CONEXIÓN',
              title: 'Servidor configurado',
              child: SelectableText(
                '${ApiConfig.baseUrl}\n${ApiConfig.aiWsUrl}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedStrong,
                ),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              onPressed: auth.logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.forest,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const Divider(height: 20),
        child,
      ],
    ),
  );
}

class _EmptyCopy extends StatelessWidget {
  final String text;
  const _EmptyCopy({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.textMuted, height: 1.4),
    ),
  );
}

class _Notice extends StatelessWidget {
  final String message;
  const _Notice({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warningBg,
      border: Border.all(color: AppColors.warning),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.textMutedStrong),
    ),
  );
}
