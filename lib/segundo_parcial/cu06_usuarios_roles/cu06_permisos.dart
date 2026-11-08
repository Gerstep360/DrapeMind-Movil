import 'package:flutter/material.dart';
import 'package:drapemind_mobile/core/network/api_client.dart';
import 'package:drapemind_mobile/core/network/api_exception.dart';

class UserAccessScreen extends StatefulWidget {
  final int userId;
  final String name;
  const UserAccessScreen({super.key, required this.userId, required this.name});
  @override
  State<UserAccessScreen> createState() => _AccessState();
}

class _AccessState extends State<UserAccessScreen> {
  final api = ApiClient();
  List<Map<String, dynamic>> catalog = [], roles = [];
  Map<String, bool> overrides = {};
  String? error, base;
  int? role;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await Future.wait([
        api.get('/team/users/${widget.userId}/access'),
        api.get('/team/roles'),
        api.get('/team/catalog'),
      ]);
      final data = result[0] as Map;
      if (mounted) {
        setState(() {
          role = data['role']?['id'];
          base = data['base_role'];
          overrides = Map<String, bool>.from(data['overrides']);
          roles = (result[1] as List)
              .map((v) => Map<String, dynamic>.from(v))
              .toList();
          catalog = ((result[2] as Map)['permissions'] as List)
              .where((v) => v['delegable'] == true)
              .map((v) => Map<String, dynamic>.from(v))
              .toList();
        });
      }
    } catch (e) {
      error = e is ApiException
          ? e.message
          : 'No pudimos consultar sus permisos.';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await api.put(
        '/team/users/${widget.userId}/access',
        body: {'rol_empresa_id': role, 'permisos': overrides},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e.message
              : 'No pudimos guardar los permisos.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Acceso de ${widget.name}')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Asigna un rol de tu empresa y ajusta solo las excepciones necesarias. Los cambios se validan en el servidor.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (base == 'ADMIN')
          const Text('Los administradores conservan todos los permisos.'),
        DropdownButtonFormField<int>(
          value: roles.any((r) => r['id'] == role) ? role : null,
          decoration: const InputDecoration(labelText: 'Rol de la empresa'),
          items: [
            const DropdownMenuItem<int>(
              value: null,
              child: Text('Permisos del puesto habitual'),
            ),
            for (final r in roles)
              DropdownMenuItem<int>(value: r['id'], child: Text(r['nombre'])),
          ],
          onChanged: busy ? null : (v) => setState(() => role = v),
        ),
        for (final p in catalog)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: DropdownButtonFormField<String>(
              value: overrides.containsKey(p['key'])
                  ? (overrides[p['key']] == true ? 'allow' : 'deny')
                  : 'inherit',
              isExpanded: true,
              decoration: InputDecoration(labelText: p['label']),
              items: const [
                DropdownMenuItem(
                  value: 'inherit',
                  child: Text('Heredar del rol'),
                ),
                DropdownMenuItem(value: 'allow', child: Text('Permitir')),
                DropdownMenuItem(value: 'deny', child: Text('Bloquear')),
              ],
              onChanged: busy || base == 'ADMIN'
                  ? null
                  : (v) => setState(() {
                      if (v == 'inherit') {
                        overrides.remove(p['key']);
                      } else {
                        overrides[p['key']] = v == 'allow';
                      }
                    }),
            ),
          ),
        FilledButton(
          onPressed: busy || base == 'ADMIN' ? null : save,
          child: const Text('Guardar permisos'),
        ),
      ],
    ),
  );
}
