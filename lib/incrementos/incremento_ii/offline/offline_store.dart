import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

/// SQLite commits the queue before a request can leave the device.
class OfflineStore {
  final DatabaseFactory? factory;
  final String? databasePath;
  Future<Database>? _database;
  OfflineStore({this.factory, this.databasePath});
  Future<Database> get database => _database ??= _open();
  Future<Database> _open() async {
    final location =
        databasePath ??
        path.join(await getDatabasesPath(), 'drapemind_incremento_ii.db');
    return (factory ?? databaseFactory).openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE bundles(owner TEXT PRIMARY KEY, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE requests(key TEXT PRIMARY KEY, owner TEXT NOT NULL, data TEXT NOT NULL)',
          );
          await db.execute('CREATE INDEX requests_owner ON requests(owner)');
          await db.execute(
            'CREATE TABLE photos(owner TEXT NOT NULL, url TEXT NOT NULL, bytes BLOB NOT NULL, PRIMARY KEY(owner,url))',
          );
        },
      ),
    );
  }

  Future<OfflineBundle?> readBundle(String owner) async {
    final rows = await (await database).query(
      'bundles',
      where: 'owner=?',
      whereArgs: [owner],
    );
    return rows.isEmpty
        ? null
        : OfflineBundle.fromJson(jsonDecode(rows.first['data'] as String));
  }

  Future<void> saveBundle(String owner, OfflineBundle bundle) async {
    await (await database).transaction((txn) async {
      await txn.insert('bundles', {
        'owner': owner,
        'data': jsonEncode(bundle.data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<OfflineRequest>> requests(String owner) async {
    final rows = await (await database).query(
      'requests',
      where: 'owner=?',
      whereArgs: [owner],
      orderBy: 'rowid',
    );
    return rows
        .map(
          (row) => OfflineRequest.fromJson(jsonDecode(row['data'] as String)),
        )
        .toList();
  }

  Future<void> saveRequest(OfflineRequest record) async {
    await (await database).transaction((txn) async {
      await txn.insert('requests', {
        'key': record.key,
        'owner': record.owner,
        'data': jsonEncode(record.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> close() async {
    if (_database != null) await (await _database!).close();
  }

  Future<void> savePhoto(String owner, String url, Uint8List bytes) async {
    await (await database).insert('photos', {
      'owner': owner,
      'url': url,
      'bytes': bytes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Uint8List?> photo(String owner, String url) async {
    final rows = await (await database).query(
      'photos',
      where: 'owner=? AND url=?',
      whereArgs: [owner, url],
    );
    return rows.isEmpty ? null : rows.first['bytes'] as Uint8List;
  }
}
