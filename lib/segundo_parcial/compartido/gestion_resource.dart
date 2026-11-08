import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';
import '../cu06_usuarios_roles/cu06_permisos.dart';

class EntryField {
  final String key, label;
  final bool number, required, secret, createOnly, multiple;
  final String? lookup;
  final List<String>? options;
  const EntryField(
    this.key,
    this.label, {
    this.number = false,
    this.required = true,
    this.secret = false,
    this.createOnly = false,
    this.multiple = false,
    this.lookup,
    this.options,
  });
}

class ResourceSpec {
  final String title, path, permission;
  final List<EntryField> fields;
  final List<String> preserve;
  final Map<String, dynamic> defaults;
  final String updateMethod;
  final String? listPath, updatePath;
  const ResourceSpec(
    this.title,
    this.path,
    this.permission,
    this.fields, {
    this.preserve = const [],
    this.defaults = const {},
    this.updateMethod = 'PUT',
    this.listPath,
    this.updatePath,
  });
}

class ResourceScreen extends StatefulWidget {
  final ResourceSpec spec;
  final ApiClient? api;
  final ValueChanged<Map<String, dynamic>>? onSecondary;
  const ResourceScreen({
    super.key,
    required this.spec,
    this.onSecondary,
    this.api,
  });
  @override
  State<ResourceScreen> createState() => _ResourceState();
}

class _ResourceState extends State<ResourceScreen> {
  late final api = widget.api ?? ApiClient();
  List<Map<String, dynamic>> rows = [];
  String? error;
  bool loading = true;
  String search = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await api.get(widget.spec.listPath ?? widget.spec.path);
      if (mounted) {
        setState(
          () => rows = (data is List ? data : data['items'] as List)
              .map((r) => Map<String, dynamic>.from(r))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No pudimos cargar la información.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ResourceForm(spec: widget.spec, row: row, api: api),
      ),
    );
    if (saved == true && mounted) load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.spec.title),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('Agregar'),
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v.toLowerCase()),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null) ...[
            Text(error!),
            TextButton(onPressed: load, child: const Text('Reintentar')),
          ],
          if (!loading && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no hay registros. Agrega el primero para comenzar.',
              ),
            ),
          for (final row in rows.where(
            (r) => r.values.join(' ').toLowerCase().contains(search),
          ))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              title: Text(
                '${row['nombre'] ?? row['nombre_empresa'] ?? row['codigo'] ?? row['sku'] ?? 'Registro'}',
              ),
              subtitle: Text(
                [
                  row['email'],
                  row['direccion'],
                  row['ciudad'],
                  if (row['precio'] != null) 'Bs ${row['precio']}',
                  if (row['activo'] == false) 'Pausado',
                  row['rol'],
                ].where((v) => v != null).join(' · '),
              ),
              trailing: widget.onSecondary != null
                  ? IconButton(
                      tooltip: 'Tallas y colores',
                      icon: const Icon(Icons.straighten),
                      onPressed: () => widget.onSecondary!(row),
                    )
                  : widget.spec.path == '/admin/users'
                  ? IconButton(
                      tooltip: 'Roles y permisos',
                      icon: const Icon(Icons.manage_accounts_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => UserAccessScreen(
                            userId: row['id'],
                            name: row['nombre'],
                          ),
                        ),
                      ),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => edit(row),
            ),
        ],
      ),
    ),
  );
}

class ResourceForm extends StatefulWidget {
  final ResourceSpec spec;
  final ApiClient? api;
  final Map<String, dynamic>? row;
  const ResourceForm({super.key, required this.spec, this.row, this.api});
  @override
  State<ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<ResourceForm> {
  final form = GlobalKey<FormState>();
  late final api = widget.api ?? ApiClient();
  final controllers = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  final lookups = <String, List<Map<String, dynamic>>>{};
  bool busy = false, loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    for (final f in widget.spec.fields) {
      final value = widget.row?[f.key] ?? widget.spec.defaults[f.key];
      values[f.key] = value;
      controllers[f.key] = TextEditingController(text: value?.toString() ?? '');
    }
    load();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      for (final f in widget.spec.fields.where((f) => f.lookup != null)) {
        final data = await api.get(f.lookup!);
        lookups[f.key] = (data as List)
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
      }
    } catch (e) {
      error = e is ApiException ? e.message : 'No pudimos cargar las opciones.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    if (busy || loading || !form.currentState!.validate()) return;
    final body = <String, dynamic>{
      ...widget.spec.defaults,
      for (final k in widget.spec.preserve)
        if (widget.row?.containsKey(k) == true) k: widget.row![k],
    };
    for (final f in widget.spec.fields) {
      if (widget.row != null && f.createOnly) continue;
      final v = controllers[f.key]!.text.trim();
      if (f.lookup != null) {
        body[f.key] = values[f.key];
      } else if (f.options != null) {
        body[f.key] = values[f.key];
      } else if (v.isNotEmpty) {
        body[f.key] = f.number ? num.parse(v) : v;
      } else if (!f.required) {
        body[f.key] = null;
      }
    }
    if (widget.row?.containsKey('activo') == true) {
      body['activo'] = widget.row!['activo'];
    }
    if (widget.spec.path.endsWith('/categories') && body['slug'] == null) {
      var value = '${body['nombre']}'.toLowerCase();
      for (final pair in {
        'á': 'a',
        'é': 'e',
        'í': 'i',
        'ó': 'o',
        'ú': 'u',
        'ñ': 'n',
      }.entries) {
        value = value.replaceAll(pair.key, pair.value);
      }
      body['slug'] = value
          .replaceAll(RegExp('[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.row == null) {
        await api.post(widget.spec.path, body: body);
      } else if (widget.spec.updateMethod == 'PATCH') {
        await api.patch(
          '${widget.spec.updatePath ?? widget.spec.path}/${widget.row!['id']}',
          body: body,
        );
      } else {
        await api.put(
          '${widget.spec.updatePath ?? widget.spec.path}/${widget.row!['id']}',
          body: body,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No se pudo guardar. Revisa los datos.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.row == null ? 'Agregar' : 'Editar'} · ${widget.spec.title}',
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          for (final f in widget.spec.fields.where(
            (f) => widget.row == null || !f.createOnly,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: f.multiple
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final choice in f.options ?? <String>[])
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(permissionLabel(choice)),
                            value: (values[f.key] as List? ?? []).contains(
                              choice,
                            ),
                            onChanged: busy
                                ? null
                                : (checked) {
                                    final next = List<String>.from(
                                      values[f.key] ?? [],
                                    );
                                    if (checked == true) {
                                      next.add(choice);
                                    } else {
                                      next.remove(choice);
                                    }
                                    setState(() => values[f.key] = next);
                                  },
                          ),
                      ],
                    )
                  : f.lookup != null || f.options != null
                  ? DropdownButtonFormField<dynamic>(
                      value:
                          (f.lookup != null
                              ? (lookups[f.key] ?? []).any(
                                  (v) => v['id'] == values[f.key],
                                )
                              : f.options!.contains(values[f.key]))
                          ? values[f.key]
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: f.label),
                      items: f.lookup != null
                          ? (lookups[f.key] ?? [])
                                .map(
                                  (v) => DropdownMenuItem<dynamic>(
                                    value: v['id'],
                                    child: Text(
                                      '${v['nombre'] ?? v['nombre_empresa'] ?? v['sku'] ?? v['codigo']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList()
                          : f.options!
                                .map(
                                  (v) => DropdownMenuItem<dynamic>(
                                    value: v,
                                    child: Text(optionLabel(v)),
                                  ),
                                )
                                .toList(),
                      onChanged: busy
                          ? null
                          : (v) => setState(() => values[f.key] = v),
                      validator: (v) => f.required && v == null
                          ? 'Selecciona una opción'
                          : null,
                    )
                  : TextFormField(
                      controller: controllers[f.key],
                      obscureText: f.secret,
                      enabled: !busy,
                      keyboardType: f.number
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: f.label),
                      validator: (v) {
                        if (f.required && (v ?? '').trim().isEmpty) {
                          return 'Completa este dato';
                        }
                        if (f.number &&
                            (v ?? '').isNotEmpty &&
                            num.tryParse(v!) == null) {
                          return 'Introduce un número válido';
                        }
                        return null;
                      },
                    ),
            ),
          if (widget.row?.containsKey('activo') == true)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Disponible'),
              value: widget.row!['activo'] == true,
              onChanged: busy
                  ? null
                  : (v) => setState(() => widget.row!['activo'] = v),
            ),
          FilledButton(
            onPressed: busy || loading ? null : save,
            child: Text(busy ? 'Guardando…' : 'Guardar cambios'),
          ),
        ],
      ),
    ),
  );
}

String permissionLabel(String key) =>
    const {
      'catalog.read': 'Consultar catálogo',
      'catalog.manage': 'Administrar prendas',
      'inventory.manage': 'Ajustar inventario',
      'branches.manage': 'Administrar sucursales',
      'pricing.manage': 'Precios y promociones',
      'suppliers.manage': 'Proveedores y abastecimiento',
      'sales.manage': 'Registrar ventas',
      'orders.manage': 'Atender pedidos',
      'reservations.manage': 'Atender reservas',
      'exchanges.manage': 'Cambios de prendas',
      'sync.review': 'Revisar sincronización',
      'offline.use': 'Operar sin conexión',
      'reports.view': 'Indicadores e informes',
      'reports.ai': 'Reportes con IA',
      'notifications.manage': 'Avisos a clientes',
    }[key] ??
    key;

String optionLabel(String key) =>
    const {
      'ADMIN': 'Administrador',
      'ENCARGADO': 'Encargado',
      'CAJERO': 'Cajero',
      'VENDEDOR': 'Vendedor',
      'PROVEEDOR': 'Proveedor',
      'CLIENTE': 'Cliente',
      'ACTIVO': 'Activo',
      'INACTIVO': 'Inactivo',
      'BLOQUEADO': 'Bloqueado',
      'MUJER': 'Mujer',
      'HOMBRE': 'Hombre',
      'UNISEX': 'Unisex',
      'PORCENTAJE': 'Porcentaje',
      'MONTO_FIJO': 'Monto fijo',
      'DOS_POR_UNO': 'Dos por uno',
      'COMPRA_MINIMA': 'Compra mínima',
    }[key] ??
    key;
