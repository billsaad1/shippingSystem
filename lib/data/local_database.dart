import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/document_models.dart';

class LocalDatabase {
  LocalDatabase._(this._database);

  final Database _database;

  static Future<LocalDatabase> open() async {
    sqfliteFfiInit();
    final directory = Directory(_applicationDataPath());
    await directory.create(recursive: true);
    return _open(p.join(directory.path, 'shipping_system.db'));
  }

  /// Opens an in-memory database for tests. It is never used by the app itself.
  static Future<LocalDatabase> openInMemory() async {
    sqfliteFfiInit();
    return _open(inMemoryDatabasePath);
  }

  static Future<LocalDatabase> _open(String path) async {
    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE invoices (
              invoice_number TEXT PRIMARY KEY,
              invoice_date TEXT NOT NULL,
              customer_name TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE receipts (
              receipt_number TEXT PRIMARY KEY,
              receipt_date TEXT NOT NULL,
              customer_name TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    return LocalDatabase._(database);
  }

  Future<void> saveInvoice(ShippingInvoice invoice) async {
    await _database.insert('invoices', {
      'invoice_number': invoice.invoiceNumber,
      'invoice_date': invoice.invoiceDate,
      'customer_name': invoice.customerName,
      'payload_json': jsonEncode(invoice.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ShippingInvoice>> recentInvoices({int limit = 30}) async {
    final rows = await _database.query(
      'invoices',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (row) => ShippingInvoice.fromJson(
            jsonDecode(row['payload_json']! as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> saveReceipt(ReceiptVoucher receipt) async {
    await _database.insert('receipts', {
      'receipt_number': receipt.receiptNumber,
      'receipt_date': receipt.receiptDate,
      'customer_name': receipt.customerName,
      'payload_json': jsonEncode(receipt.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReceiptVoucher>> recentReceipts({int limit = 30}) async {
    final rows = await _database.query(
      'receipts',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (row) => ReceiptVoucher.fromJson(
            jsonDecode(row['payload_json']! as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> close() => _database.close();
}

String _applicationDataPath() {
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return p.join(
      appData ?? p.join(home, 'AppData', 'Roaming'),
      'ShippingSystem',
    );
  }
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return p.join(home, 'Library', 'Application Support', 'ShippingSystem');
  }
  final dataHome = Platform.environment['XDG_DATA_HOME'];
  final home = Platform.environment['HOME'] ?? Directory.current.path;
  return p.join(dataHome ?? p.join(home, '.local', 'share'), 'shipping_system');
}
