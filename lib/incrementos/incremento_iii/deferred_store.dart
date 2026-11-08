import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:drapemind_mobile/incrementos/incremento_ii/offline/offline_store.dart';

class DeferredStore {
  final OfflineStore local;
  DeferredStore({OfflineStore? store}) : local = store ?? OfflineStore();
  Future<Map<String, dynamic>?> context(String owner) async {
    final rows = await (await local.database).query(
      'checkout_context',
      where: 'owner=?',
      whereArgs: [owner],
    );
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(jsonDecode(rows.first['data'] as String));
  }

  Future<void> saveContext(String owner, Map<String, dynamic> data) async {
    await (await local.database).transaction((tx) async {
      await tx.insert('checkout_context', {
        'owner': owner,
        'data': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, dynamic>>> purchases(String owner) async {
    final rows = await (await local.database).query(
      'checkout_pending',
      where: 'owner=?',
      whereArgs: [owner],
      orderBy: 'rowid DESC',
    );
    return rows
        .map(
          (row) => Map<String, dynamic>.from(jsonDecode(row['data'] as String)),
        )
        .toList();
  }

  Future<void> save(Map<String, dynamic> data) async {
    await (await local.database).transaction((tx) async {
      await tx.insert('checkout_pending', {
        'key': data['key'],
        'owner': data['owner'],
        'data': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
