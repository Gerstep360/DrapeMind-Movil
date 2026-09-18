import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:drapemind_mobile/compartido/componentes/estado/dm_empty_state.dart';
import 'package:drapemind_mobile/compartido/componentes/estructura/dm_section.dart';
import 'package:drapemind_mobile/compartido/componentes/retroalimentacion/dm_notice.dart';
import 'package:drapemind_mobile/core/core.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';
import 'package:drapemind_mobile/core/theme/app_svg.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/registrar_cliente/presentacion/onboarding_screen.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/consultar_detalle_talla_color_variante/presentacion/product_detail_screen.dart';
import 'package:drapemind_mobile/paquetes/acceso_gestion_usuarios/gestionar_cuenta/presentacion/addresses_screen.dart';
import 'package:drapemind_mobile/paquetes/catalogo_comercializacion/gestionar_favoritos/presentacion/favorites_screen.dart';
import 'package:drapemind_mobile/paquetes/sucursales_inventario_proveedores/datos/servicios/preferred_branch_store.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _addressService = AddressService();
  final _catalogService = CatalogService();
  final _branchService = BranchService();
  final _preferredBranchStore = PreferredBranchStore();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  List<Address> _addresses = [];
  List<Product> _favorites = [];
  List<Branch> _branches = [];
  StyleProfile? _styleProfile;
  int? _preferredBranchId;
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
        context.read<AuthService>().getStyleProfile(),
      ]);
      final branchId = await _preferredBranchStore.read();

      if (!mounted) return;
      setState(() {
        _addresses = results[0] as List<Address>;
        _favorites = results[1] as List<Product>;
        _branches = results[2] as List<Branch>;
        _styleProfile = results[3] as StyleProfile?;
        _preferredBranchId = branchId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'No pudimos sincronizar todos los datos de tu cuenta.';
        _loading = false;
      });
    }
  }

  Future<void> _setPreferredBranch(Branch branch) async {
    setState(() => _preferredBranchId = branch.id);
    try {
      await _preferredBranchStore.save(branch.id);
      if (mounted) {
        _showMessage('Showroom preferido: ${branch.nombre}');
      }
    } catch (_) {}
  }

  Future<void> _openOnboarding() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isReconfiguring: true),
      ),
    );
    if (updated == true || mounted) {
      await _loadAccount();
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
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException
            ? e.message
            : 'No se pudo actualizar el perfil.';
        _showMessage(msg, danger: true);
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _showServerDialog() async {
    final customController = TextEditingController();
    final currentHost = ApiConfig.defaultHost;

    final options = [
      {
        'label': 'VPS Oficial (Producción)',
        'host': ApiConfig.hostVPS,
        'desc': 'Nube pública en 167.86.106.105',
        'isDefault': true,
      },
      {
        'label': 'Wi-Fi LAN Local (Desarrollo)',
        'host': ApiConfig.hostLAN,
        'desc': 'IP local de oficina / laboratorio (${ApiConfig.hostLAN})',
        'isDefault': false,
      },
      {
        'label': 'Localhost / ADB Reverse',
        'host': ApiConfig.hostLocal,
        'desc': 'Túnel cableado reverse (${ApiConfig.hostLocal})',
        'isDefault': false,
      },
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.lineStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(
                        Icons.dns_outlined,
                        color: AppColors.forest,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'CONMUTADOR DE SERVIDOR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona el entorno backend al que deseas conectar la app:',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final optHost = opt['host'] as String;
                    final isSelected = currentHost == optHost;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.lime.withValues(alpha: 0.25)
                            : AppColors.white,
                        border: Border.all(
                          color: isSelected ? AppColors.forest : AppColors.line,
                          width: isSelected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        onTap: () async {
                          if (opt['isDefault'] == true) {
                            await ApiConfig.resetHost();
                          } else {
                            await ApiConfig.setCustomHost(optHost);
                          }
                          if (context.mounted) {
                            context
                                .read<AiSocketService>()
                                .reconnectWithCurrentConfig();
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            _showMessage('Conectado a ${opt['label']}');
                            setState(() {});
                            _loadAccount();
                          }
                        },
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? AppColors.forest
                              : AppColors.textMuted,
                        ),
                        title: Text(
                          opt['label'] as String,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: AppColors.ink,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${opt['desc']}\n${opt['host']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMutedStrong,
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Text(
                    'O especifica un Host / IP personalizado:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customController,
                          decoration: InputDecoration(
                            hintText: 'ej. 192.168.1.10:8000',
                            filled: true,
                            fillColor: AppColors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.line,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final txt = customController.text.trim();
                          if (txt.isEmpty) return;
                          await ApiConfig.setCustomHost(txt);
                          if (context.mounted) {
                            context
                                .read<AiSocketService>()
                                .reconnectWithCurrentConfig();
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            _showMessage(
                              'Conectado a host personalizado: $txt',
                            );
                            setState(() {});
                            _loadAccount();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Aplicar',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    customController.dispose();
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
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: AppSvg.raw(AppSvg.user, size: 14, color: AppColors.lime),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mi Perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.ink,
        onRefresh: _loadAccount,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1510110F),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.lime,
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
                            color: AppColors.paperDark,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            user?.rol.toServerString() ?? 'CLIENTE',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
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
              DmNotice(message: _error!, tone: DmNoticeTone.danger),
            ],
            const SizedBox(height: 16),
            DmSection(
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
            DmSection(
              eyebrow: 'CU-19 / CU-20 · ADN DE ESTILO',
              title: 'Preferencias de estilo',
              trailing: TextButton.icon(
                onPressed: _openOnboarding,
                icon: const Icon(Icons.edit_note, size: 18),
                label: Text(_styleProfile != null ? 'Modificar' : 'Configurar'),
              ),
              child: _loading
                  ? const LinearProgressIndicator()
                  : _styleProfile == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Aún no has configurado tu perfil de estilo. Completa el onboarding para recibir recomendaciones hiper-personalizadas de Altair.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _openOnboarding,
                          icon: const Icon(Icons.auto_awesome, size: 17),
                          label: const Text('Iniciar Onboarding de Estilo →'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_styleProfile!.siluetaPreferida != null ||
                            _styleProfile!.genero != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.acid,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _styleProfile!.siluetaPreferida ??
                                      'Silueta Estándar',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              if (_styleProfile!.genero != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.paperDark,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _styleProfile!.genero!.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.paperLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    'TOP',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _styleProfile!.tallaSuperior ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                color: AppColors.line,
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'BOTTOM',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _styleProfile!.tallaInferior ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 26,
                                color: AppColors.line,
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'CALZADO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _styleProfile!.tallaCalzado ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_styleProfile!.estilosPreferidos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'ESTILOS DECLARADOS:',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMutedStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _styleProfile!.estilosPreferidos
                                .map(
                                  (st) => Chip(
                                    label: Text(
                                      st,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor: AppColors.paperDark,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    side: BorderSide.none,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (_styleProfile!.coloresFavoritos.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'PALETAS FAVORITAS:',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMutedStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _styleProfile!.coloresFavoritos
                                .map(
                                  (col) => Chip(
                                    label: Text(
                                      col,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: AppColors.paperLight,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    side: const BorderSide(
                                      color: AppColors.line,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (_styleProfile!.presupuestoHabitual != null &&
                            _styleProfile!.presupuestoHabitual! > 0) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                'PRESUPUESTO HABITUAL: ',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMutedStrong,
                                ),
                              ),
                              Text(
                                'Hasta Bs ${_styleProfile!.presupuestoHabitual!.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.forest,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _openOnboarding,
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text(
                            'Modificar respuestas en Onboarding',
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            DmSection(
              eyebrow: 'CU-03 · LOGÍSTICA DE ENVÍO',
              title: 'Direcciones de entrega',
              trailing: TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  );
                  if (mounted) _loadAccount();
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Administrar'),
              ),
              child: _loading
                  ? const LinearProgressIndicator()
                  : _addresses.isEmpty
                  ? const DmEmptyCopy(
                      text:
                          'Guarda una dirección para agilizar tu próxima compra.',
                    )
                  : Column(
                      children: [
                        ..._addresses.map(
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
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.forest,
                                        letterSpacing: 0.6,
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
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddressesScreen(),
                                ),
                              );
                              if (mounted) _loadAccount();
                            },
                            icon: const Icon(Icons.tune, size: 16),
                            label: const Text('Ver pantalla completa de direcciones (CU-03)'),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            DmSection(
              eyebrow: 'CU-08 · SELECCIÓN PERSONAL',
              title: 'Favoritos',
              trailing: TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  );
                  if (mounted) _loadAccount();
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Ver galería'),
              ),
              child: _favorites.isEmpty
                  ? const DmEmptyCopy(
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
            DmSection(
              eyebrow: 'SHOWROOMS',
              title: 'Dónde encontrarnos',
              child: _branches.isEmpty
                  ? const DmEmptyCopy(
                      text:
                          'Las sucursales aparecerán cuando el servidor esté disponible.',
                    )
                  : Column(
                      children: _branches.map((branch) {
                        final isPreferred = _preferredBranchId == branch.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isPreferred
                                ? AppColors.lime.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isPreferred
                                  ? AppColors.forest
                                  : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => _setPreferredBranch(branch),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            leading: Icon(
                              isPreferred
                                  ? Icons.store
                                  : Icons.storefront_outlined,
                              color: isPreferred
                                  ? AppColors.forest
                                  : AppColors.ink,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    branch.nombre,
                                    style: TextStyle(
                                      fontWeight: isPreferred
                                          ? FontWeight.w900
                                          : FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isPreferred)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.lime,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'PREFERIDO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${branch.direccion}\n${branch.ciudad ?? ''}${branch.departamento == null ? '' : ', ${branch.departamento}'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 14),
            DmSection(
              eyebrow: 'CONEXIÓN',
              title: 'Servidor configurado',
              trailing: TextButton.icon(
                onPressed: _showServerDialog,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Conmutar'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Host activo: ${ApiConfig.defaultHost}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    'API: ${ApiConfig.baseUrl}\nIA WebSocket: ${ApiConfig.aiWsUrl}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMutedStrong,
                      height: 1.4,
                    ),
                  ),
                ],
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
