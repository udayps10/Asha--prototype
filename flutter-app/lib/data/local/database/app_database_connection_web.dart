import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    final fileSystem = await IndexedDbFileSystem.open(
      dbName: 'disaster_connect',
    );
    return WasmDatabase(
      sqlite3: sqlite3,
      path: 'disaster_connect',
      fileSystem: fileSystem,
    );
  });
}