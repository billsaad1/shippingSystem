import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/customer_models.dart';
import '../models/document_models.dart';
import '../services/money_minor_units.dart';

class LocalDatabase {
  LocalDatabase._(this._database);

  final Database _database;

  static const int _schemaVersion = 3;

  static Future<LocalDatabase> open() async {
    sqfliteFfiInit();
    final directory = Directory(applicationDataPath());
    await directory.create(recursive: true);
    return _open(p.join(directory.path, 'shipping_system.db'));
  }

  static String applicationDataPath() => _applicationDataPath();

  /// Opens an in-memory database for tests. It is never used by the app itself.
  static Future<LocalDatabase> openInMemory() async {
    sqfliteFfiInit();
    return _open(inMemoryDatabasePath);
  }

  /// Opens a database at a test path so schema upgrades can be exercised.
  static Future<LocalDatabase> openAtPathForTesting(String path) async {
    sqfliteFfiInit();
    return _open(path);
  }

  static Future<LocalDatabase> _open(String path) async {
    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _createFreshSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createCompanyProfileTable(db);
          if (oldVersion < 3) await _upgradeToCustomerLedger(db);
        },
      ),
    );
    return LocalDatabase._(database);
  }

  static Future<void> _createFreshSchema(DatabaseExecutor db) async {
    await _createCustomerTable(db);
    await db.execute('''
      CREATE TABLE invoices (
        invoice_number TEXT PRIMARY KEY,
        invoice_date TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE receipts (
        receipt_number TEXT PRIMARY KEY,
        receipt_date TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_id INTEGER REFERENCES customers(id),
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await _createCompanyProfileTable(db);
    await _createCustomerLedgerTables(db);
  }

  static Future<void> _createCustomerTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_number TEXT UNIQUE,
        name TEXT NOT NULL,
        english_name TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX customers_name_index ON customers(name COLLATE NOCASE)',
    );
  }

  static Future<void> _createCompanyProfileTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE company_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        payload_json TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createCustomerLedgerTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE customer_ledger_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        entry_date TEXT NOT NULL,
        currency TEXT NOT NULL CHECK (currency IN ('USD', 'YER')),
        entry_type TEXT NOT NULL,
        debit_minor INTEGER NOT NULL DEFAULT 0 CHECK (debit_minor >= 0),
        credit_minor INTEGER NOT NULL DEFAULT 0 CHECK (credit_minor >= 0),
        source_type TEXT NOT NULL,
        source_number TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        is_legacy INTEGER NOT NULL DEFAULT 0 CHECK (is_legacy IN (0, 1)),
        created_at TEXT NOT NULL,
        CHECK ((debit_minor > 0 AND credit_minor = 0) OR
               (credit_minor > 0 AND debit_minor = 0)),
        UNIQUE (source_type, source_number)
      )
    ''');
    await db.execute('''
      CREATE INDEX customer_ledger_customer_date_index
      ON customer_ledger_entries(customer_id, currency, entry_date, id)
    ''');
    await db.execute('''
      CREATE TABLE customer_receipt_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT NOT NULL REFERENCES receipts(receipt_number)
          ON UPDATE CASCADE ON DELETE CASCADE,
        invoice_number TEXT NOT NULL REFERENCES invoices(invoice_number)
          ON UPDATE CASCADE ON DELETE CASCADE,
        customer_id INTEGER NOT NULL REFERENCES customers(id),
        currency TEXT NOT NULL CHECK (currency IN ('USD', 'YER')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        created_at TEXT NOT NULL,
        UNIQUE (receipt_number, invoice_number)
      )
    ''');
    await db.execute('''
      CREATE INDEX customer_allocation_invoice_index
      ON customer_receipt_allocations(invoice_number)
    ''');
  }

  static Future<void> _upgradeToCustomerLedger(DatabaseExecutor db) async {
    await _createCustomerTable(db);
    await db.execute(
      'ALTER TABLE invoices ADD COLUMN customer_id INTEGER REFERENCES customers(id)',
    );
    await db.execute(
      'ALTER TABLE receipts ADD COLUMN customer_id INTEGER REFERENCES customers(id)',
    );
    await _createCustomerLedgerTables(db);
    await _backfillExistingDocuments(db);
  }

  static Future<void> _backfillExistingDocuments(DatabaseExecutor db) async {
    final invoices = await db.query('invoices');
    for (final row in invoices) {
      try {
        final invoice = ShippingInvoice.fromJson(
          _decodeJson(row['payload_json']! as String),
        );
        final customerId = await _findOrCreateCustomer(
          db,
          customerId: invoice.customerId,
          name: invoice.customerName,
          customerNumber: invoice.customerNumber,
        );
        if (customerId == null) continue;
        await db.update(
          'invoices',
          {'customer_id': customerId},
          where: 'invoice_number = ?',
          whereArgs: [row['invoice_number']],
        );
        final totalMinor = _invoiceTotalMinor(invoice);
        if (invoice.invoiceNumber.trim().isNotEmpty && totalMinor > 0) {
          await _upsertLedgerEntry(
            db,
            customerId: customerId,
            date: invoice.invoiceDate,
            currency: invoice.currency,
            entryType: 'invoice',
            debitMinor: totalMinor,
            creditMinor: 0,
            sourceType: 'invoice',
            sourceNumber: invoice.invoiceNumber,
            description: 'فاتورة أجور شحن رقم ${invoice.invoiceNumber}',
            isLegacy: true,
          );
        }
      } on Object {
        // A malformed old document remains available but cannot be posted.
      }
    }

    final receipts = await db.query('receipts');
    for (final row in receipts) {
      try {
        final receipt = ReceiptVoucher.fromJson(
          _decodeJson(row['payload_json']! as String),
        );
        final customerId = await _findOrCreateCustomer(
          db,
          customerId: receipt.customerId,
          name: receipt.customerName,
          customerNumber: '',
        );
        if (customerId == null) continue;
        await db.update(
          'receipts',
          {'customer_id': customerId},
          where: 'receipt_number = ?',
          whereArgs: [row['receipt_number']],
        );
        final amountMinor = MoneyMinorUnits.tryParse(receipt.amount) ?? 0;
        if (receipt.receiptNumber.trim().isNotEmpty && amountMinor > 0) {
          await _upsertLedgerEntry(
            db,
            customerId: customerId,
            date: receipt.receiptDate,
            currency: receipt.currency,
            entryType: 'receipt',
            debitMinor: 0,
            creditMinor: amountMinor,
            sourceType: 'receipt',
            sourceNumber: receipt.receiptNumber,
            description: _receiptLedgerDescription(receipt),
            isLegacy: true,
          );
          await _syncReceiptAllocation(
            db,
            receipt: receipt,
            customerId: customerId,
            amountMinor: amountMinor,
          );
        }
      } on Object {
        // A malformed old document remains available but cannot be posted.
      }
    }
  }

  Future<int?> saveInvoice(ShippingInvoice invoice) async {
    final now = DateTime.now().toIso8601String();
    return _database.transaction((txn) async {
      final existingRows = await txn.query(
        'invoices',
        where: 'invoice_number = ?',
        whereArgs: [invoice.invoiceNumber],
        limit: 1,
      );
      final priorCustomerId = existingRows.isEmpty
          ? null
          : (existingRows.single['customer_id'] as num?)?.toInt();
      final customerId = await _findOrCreateCustomer(
        txn,
        customerId: invoice.customerId ?? priorCustomerId,
        name: invoice.customerName,
        customerNumber: invoice.customerNumber,
      );
      final totalMinor = _invoiceTotalMinor(invoice);
      final allocated = await _allocatedMinor(
        txn,
        invoiceNumber: invoice.invoiceNumber,
      );
      if (allocated > 0 && existingRows.isNotEmpty) {
        final oldPayload = _decodeJson(
          existingRows.single['payload_json']! as String,
        );
        final oldInvoice = ShippingInvoice.fromJson(oldPayload);
        if (customerId != priorCustomerId ||
            invoice.currency != oldInvoice.currency) {
          throw StateError(
            'لا يمكن تغيير العميل أو العملة لفاتورة عليها سندات مرتبطة.',
          );
        }
        if (totalMinor < allocated) {
          throw StateError(
            'قيمة الفاتورة الجديدة أقل من المبلغ المسدد عليها بالفعل.',
          );
        }
      }

      final payload = invoice.toJson()..['customerId'] = customerId;
      final values = {
        'invoice_number': invoice.invoiceNumber,
        'invoice_date': invoice.invoiceDate,
        'customer_name': invoice.customerName,
        'customer_id': customerId,
        'payload_json': jsonEncode(payload),
        'updated_at': now,
      };
      await _insertOrUpdateDocument(
        txn,
        table: 'invoices',
        keyColumn: 'invoice_number',
        keyValue: invoice.invoiceNumber,
        values: values,
      );
      if (customerId != null && invoice.invoiceNumber.trim().isNotEmpty) {
        if (totalMinor > 0) {
          await _upsertLedgerEntry(
            txn,
            customerId: customerId,
            date: invoice.invoiceDate,
            currency: invoice.currency,
            entryType: 'invoice',
            debitMinor: totalMinor,
            creditMinor: 0,
            sourceType: 'invoice',
            sourceNumber: invoice.invoiceNumber,
            description: 'فاتورة أجور شحن رقم ${invoice.invoiceNumber}',
          );
        } else {
          await txn.delete(
            'customer_ledger_entries',
            where: 'source_type = ? AND source_number = ?',
            whereArgs: ['invoice', invoice.invoiceNumber],
          );
        }
      }
      return customerId;
    });
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
            _decodeJson(row['payload_json']! as String),
          ),
        )
        .toList();
  }

  Future<ShippingInvoice?> invoiceByNumber(String invoiceNumber) async {
    final rows = await _database.query(
      'invoices',
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ShippingInvoice.fromJson(
      _decodeJson(rows.single['payload_json']! as String),
    );
  }

  Future<int?> invoiceOutstandingMinor(String invoiceNumber) async {
    final invoice = await invoiceByNumber(invoiceNumber);
    if (invoice == null) return null;
    final allocated = await _allocatedMinor(
      _database,
      invoiceNumber: invoiceNumber,
    );
    final outstanding = _invoiceTotalMinor(invoice) - allocated;
    return outstanding > 0 ? outstanding : 0;
  }

  Future<List<CustomerInvoiceBalance>> customerOpenInvoices(
    int customerId,
  ) async {
    final rows = await _database.query(
      'invoices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    final invoices = <CustomerInvoiceBalance>[];
    for (final row in rows) {
      final invoice = ShippingInvoice.fromJson(
        _decodeJson(row['payload_json']! as String),
      );
      final totalMinor = _invoiceTotalMinor(invoice);
      final paidMinor = await _allocatedMinor(
        _database,
        invoiceNumber: invoice.invoiceNumber,
      );
      final outstandingMinor = totalMinor - paidMinor;
      if (outstandingMinor <= 0) continue;
      invoices.add(
        CustomerInvoiceBalance(
          invoiceNumber: invoice.invoiceNumber,
          invoiceDate: invoice.invoiceDate,
          currency: invoice.currency,
          totalMinor: totalMinor,
          paidMinor: paidMinor,
          outstandingMinor: outstandingMinor,
        ),
      );
    }
    invoices.sort((a, b) {
      final dateCompare = _normalizeDate(a.invoiceDate)
          .compareTo(_normalizeDate(b.invoiceDate));
      return dateCompare != 0
          ? dateCompare
          : a.invoiceNumber.compareTo(b.invoiceNumber);
    });
    return invoices;
  }

  Future<int?> saveReceipt(ReceiptVoucher receipt) async {
    final now = DateTime.now().toIso8601String();
    return _database.transaction((txn) async {
      final existingRows = await txn.query(
        'receipts',
        where: 'receipt_number = ?',
        whereArgs: [receipt.receiptNumber],
        limit: 1,
      );
      final priorCustomerId = existingRows.isEmpty
          ? null
          : (existingRows.single['customer_id'] as num?)?.toInt();
      final customerId = await _findOrCreateCustomer(
        txn,
        customerId: receipt.customerId ?? priorCustomerId,
        name: receipt.customerName,
        customerNumber: '',
      );
      final payload = receipt.toJson()..['customerId'] = customerId;
      final values = {
        'receipt_number': receipt.receiptNumber,
        'receipt_date': receipt.receiptDate,
        'customer_name': receipt.customerName,
        'customer_id': customerId,
        'payload_json': jsonEncode(payload),
        'updated_at': now,
      };
      await _insertOrUpdateDocument(
        txn,
        table: 'receipts',
        keyColumn: 'receipt_number',
        keyValue: receipt.receiptNumber,
        values: values,
      );

      if (customerId != null && receipt.receiptNumber.trim().isNotEmpty) {
        final amountMinor = MoneyMinorUnits.tryParse(receipt.amount) ?? 0;
        if (amountMinor > 0) {
          await _upsertLedgerEntry(
            txn,
            customerId: customerId,
            date: receipt.receiptDate,
            currency: receipt.currency,
            entryType: 'receipt',
            debitMinor: 0,
            creditMinor: amountMinor,
            sourceType: 'receipt',
            sourceNumber: receipt.receiptNumber,
            description: _receiptLedgerDescription(receipt),
          );
          await _syncReceiptAllocation(
            txn,
            receipt: receipt,
            customerId: customerId,
            amountMinor: amountMinor,
          );
        } else {
          await txn.delete(
            'customer_ledger_entries',
            where: 'source_type = ? AND source_number = ?',
            whereArgs: ['receipt', receipt.receiptNumber],
          );
          await txn.delete(
            'customer_receipt_allocations',
            where: 'receipt_number = ?',
            whereArgs: [receipt.receiptNumber],
          );
        }
      }
      return customerId;
    });
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
            _decodeJson(row['payload_json']! as String),
          ),
        )
        .toList();
  }

  Future<List<CustomerAccountSummary>> customerAccounts({
    String search = '',
    bool includeInactive = false,
  }) async {
    final query = search.trim();
    final customers = await _database.query(
      'customers',
      where: query.isEmpty
          ? (includeInactive ? null : 'is_active = 1')
          : '${includeInactive ? '1 = 1' : 'is_active = 1'} AND (name LIKE ? OR customer_number LIKE ? OR phone LIKE ?)',
      whereArgs: query.isEmpty ? null : ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name COLLATE NOCASE',
    );
    final totals = await _database.rawQuery('''
      SELECT customer_id, currency,
             COALESCE(SUM(debit_minor), 0) AS debit_minor,
             COALESCE(SUM(credit_minor), 0) AS credit_minor
      FROM customer_ledger_entries
      GROUP BY customer_id, currency
    ''');
    final balances = <int, Map<String, int>>{};
    for (final row in totals) {
      final id = (row['customer_id'] as num).toInt();
      final currency = row['currency']! as String;
      final debit = (row['debit_minor'] as num).toInt();
      final credit = (row['credit_minor'] as num).toInt();
      balances.putIfAbsent(id, () => {})[currency] = debit - credit;
    }
    return customers.map((row) {
      final customer = Customer.fromMap(row);
      final customerBalances = balances[customer.id] ?? const {};
      return CustomerAccountSummary(
        customer: customer,
        usdBalanceMinor: customerBalances['USD'] ?? 0,
        yerBalanceMinor: customerBalances['YER'] ?? 0,
      );
    }).toList();
  }

  Future<List<Customer>> customers({String search = ''}) async {
    final query = search.trim();
    final rows = await _database.query(
      'customers',
      where: query.isEmpty ? 'is_active = 1' : 'is_active = 1 AND (name LIKE ? OR customer_number LIKE ? OR phone LIKE ?)',
      whereArgs: query.isEmpty ? null : ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> customerById(int id) async {
    final rows = await _database.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Customer.fromMap(rows.single);
  }

  Future<int> saveCustomer(Customer customer) async {
    final name = customer.name.trim();
    if (name.isEmpty) throw ArgumentError('اسم العميل مطلوب.');
    final number = customer.customerNumber.trim();
    final now = DateTime.now().toIso8601String();
    return _database.transaction((txn) async {
      if (number.isNotEmpty) {
        final duplicate = await txn.query(
          'customers',
          columns: ['id'],
          where: customer.id == null
              ? 'customer_number = ?'
              : 'customer_number = ? AND id <> ?',
          whereArgs: customer.id == null ? [number] : [number, customer.id],
          limit: 1,
        );
        if (duplicate.isNotEmpty) {
          throw StateError('رقم العميل مستخدم في بطاقة عميل أخرى.');
        }
      }
      final values = {
        'customer_number': number.isEmpty ? null : number,
        'name': name,
        'english_name': customer.englishName.trim(),
        'phone': customer.phone.trim(),
        'email': customer.email.trim(),
        'address': customer.address.trim(),
        'notes': customer.notes.trim(),
        'is_active': customer.isActive ? 1 : 0,
        'updated_at': now,
      };
      if (customer.id == null) {
        return txn.insert('customers', {...values, 'created_at': now});
      }
      final changed = await txn.update(
        'customers',
        values,
        where: 'id = ?',
        whereArgs: [customer.id],
      );
      if (changed == 0) throw StateError('لم يتم العثور على بطاقة العميل.');
      return customer.id!;
    });
  }

  Future<void> setCustomerActive(int customerId, bool isActive) async {
    await _database.update(
      'customers',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  Future<List<CustomerLedgerEntry>> customerStatement(
    int customerId, {
    String? currency,
  }) async {
    final rows = await _database.query(
      'customer_ledger_entries',
      where: currency == null
          ? 'customer_id = ?'
          : 'customer_id = ? AND currency = ?',
      whereArgs: currency == null ? [customerId] : [customerId, currency],
      orderBy: 'entry_date ASC, id ASC',
    );
    return rows.map(CustomerLedgerEntry.fromMap).toList();
  }

  Future<Map<String, int>> customerBalances(int customerId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT currency,
             COALESCE(SUM(debit_minor), 0) -
             COALESCE(SUM(credit_minor), 0) AS balance_minor
      FROM customer_ledger_entries
      WHERE customer_id = ?
      GROUP BY currency
      ''',
      [customerId],
    );
    return {
      for (final row in rows)
        row['currency']! as String: (row['balance_minor'] as num).toInt(),
    };
  }

  Future<void> addCustomerAdjustment({
    required int customerId,
    required String date,
    required String currency,
    required int amountMinor,
    required bool isDebit,
    required String description,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('قيمة التسوية يجب أن تكون موجبة.');
    }
    if (currency != 'USD' && currency != 'YER') {
      throw ArgumentError('العملة غير مدعومة.');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError('سبب التسوية مطلوب.');
    }
    final sourceNumber = 'ADJ-${DateTime.now().microsecondsSinceEpoch}';
    await _upsertLedgerEntry(
      _database,
      customerId: customerId,
      date: date,
      currency: currency,
      entryType: 'adjustment',
      debitMinor: isDebit ? amountMinor : 0,
      creditMinor: isDebit ? 0 : amountMinor,
      sourceType: 'adjustment',
      sourceNumber: sourceNumber,
      description: description.trim(),
    );
  }

  Future<CompanyProfile> getCompanyProfile() async {
    final rows = await _database.query(
      'company_profile',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) return const CompanyProfile.defaults();

    final payload = rows.single['payload_json'];
    if (payload is! String) return const CompanyProfile.defaults();
    try {
      return CompanyProfile.fromJson(_decodeJson(payload));
    } on Object {
      return const CompanyProfile.defaults();
    }
  }

  Future<void> saveCompanyProfile(CompanyProfile profile) async {
    await _database.insert('company_profile', {
      'id': 1,
      'payload_json': jsonEncode(profile.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => _database.close();

  static Future<int?> _findOrCreateCustomer(
    DatabaseExecutor db, {
    int? customerId,
    required String name,
    required String customerNumber,
  }) async {
    if (customerId != null) {
      final byId = await db.query(
        'customers',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (byId.isNotEmpty) return customerId;
    }
    final cleanName = name.trim();
    final cleanNumber = customerNumber.trim();
    if (cleanName.isEmpty) return null;

    if (cleanNumber.isNotEmpty) {
      final byNumber = await db.query(
        'customers',
        columns: ['id'],
        where: 'customer_number = ?',
        whereArgs: [cleanNumber],
        limit: 1,
      );
      if (byNumber.isNotEmpty) return (byNumber.single['id'] as num).toInt();
    }
    final byName = await db.query(
      'customers',
      columns: ['id', 'customer_number'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [cleanName],
      limit: 1,
    );
    if (byName.isNotEmpty) {
      final id = (byName.single['id'] as num).toInt();
      final oldNumber = byName.single['customer_number'] as String? ?? '';
      if (cleanNumber.isNotEmpty && oldNumber.isEmpty) {
        final duplicate = await db.query(
          'customers',
          columns: ['id'],
          where: 'customer_number = ?',
          whereArgs: [cleanNumber],
          limit: 1,
        );
        if (duplicate.isEmpty) {
          await db.update(
            'customers',
            {
              'customer_number': cleanNumber,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      return id;
    }

    final now = DateTime.now().toIso8601String();
    return db.insert('customers', {
      'customer_number': cleanNumber.isEmpty ? null : cleanNumber,
      'name': cleanName,
      'english_name': '',
      'phone': '',
      'email': '',
      'address': '',
      'notes': '',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<void> _insertOrUpdateDocument(
    DatabaseExecutor db, {
    required String table,
    required String keyColumn,
    required String keyValue,
    required Map<String, Object?> values,
  }) async {
    final existing = await db.query(
      table,
      columns: [keyColumn],
      where: '$keyColumn = ?',
      whereArgs: [keyValue],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(table, values);
    } else {
      await db.update(
        table,
        values,
        where: '$keyColumn = ?',
        whereArgs: [keyValue],
      );
    }
  }

  static Future<void> _upsertLedgerEntry(
    DatabaseExecutor db, {
    required int customerId,
    required String date,
    required String currency,
    required String entryType,
    required int debitMinor,
    required int creditMinor,
    required String sourceType,
    required String sourceNumber,
    required String description,
    bool isLegacy = false,
  }) async {
    if (currency != 'USD' && currency != 'YER') {
      throw ArgumentError('العملة غير مدعومة في دفتر العميل: $currency');
    }
    final now = DateTime.now().toIso8601String();
    final values = <String, Object?>{
      'customer_id': customerId,
      'entry_date': _normalizeDate(date),
      'currency': currency,
      'entry_type': entryType,
      'debit_minor': debitMinor,
      'credit_minor': creditMinor,
      'source_type': sourceType,
      'source_number': sourceNumber,
      'description': description,
      'is_legacy': isLegacy ? 1 : 0,
      'created_at': now,
    };
    final existing = await db.query(
      'customer_ledger_entries',
      columns: ['id'],
      where: 'source_type = ? AND source_number = ?',
      whereArgs: [sourceType, sourceNumber],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('customer_ledger_entries', values);
    } else {
      await db.update(
        'customer_ledger_entries',
        values,
        where: 'source_type = ? AND source_number = ?',
        whereArgs: [sourceType, sourceNumber],
      );
    }
  }

  static Future<void> _syncReceiptAllocation(
    DatabaseExecutor db, {
    required ReceiptVoucher receipt,
    required int customerId,
    required int amountMinor,
  }) async {
    await db.delete(
      'customer_receipt_allocations',
      where: 'receipt_number = ?',
      whereArgs: [receipt.receiptNumber],
    );
    final invoiceNumber = receipt.sourceInvoiceNumber.trim();
    if (invoiceNumber.isEmpty || amountMinor <= 0) return;

    final invoiceRows = await db.query(
      'invoices',
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
      limit: 1,
    );
    if (invoiceRows.isEmpty) return;
    final invoiceRow = invoiceRows.single;
    final invoiceCustomerId = (invoiceRow['customer_id'] as num?)?.toInt();
    if (invoiceCustomerId != customerId) return;

    final invoice = ShippingInvoice.fromJson(
      _decodeJson(invoiceRow['payload_json']! as String),
    );
    if (invoice.currency != receipt.currency) return;
    final alreadyAllocated = await _allocatedMinor(
      db,
      invoiceNumber: invoiceNumber,
      excludingReceiptNumber: receipt.receiptNumber,
    );
    final outstanding = _invoiceTotalMinor(invoice) - alreadyAllocated;
    if (outstanding <= 0) return;
    final allocated = amountMinor < outstanding ? amountMinor : outstanding;
    await db.insert('customer_receipt_allocations', {
      'receipt_number': receipt.receiptNumber,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'currency': receipt.currency,
      'amount_minor': allocated,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<int> _allocatedMinor(
    DatabaseExecutor db, {
    required String invoiceNumber,
    String? excludingReceiptNumber,
  }) async {
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS amount_minor
      FROM customer_receipt_allocations
      WHERE invoice_number = ?
        AND (? IS NULL OR receipt_number <> ?)
      ''',
      [invoiceNumber, excludingReceiptNumber, excludingReceiptNumber],
    );
    return (result.single['amount_minor'] as num).toInt();
  }

  static int _invoiceTotalMinor(ShippingInvoice invoice) {
    final subtotal = invoice.chargeLines.fold<int>(
      0,
      (sum, line) => sum + (MoneyMinorUnits.tryParse(line.amount) ?? 0),
    );
    final discount = MoneyMinorUnits.tryParse(invoice.discount) ?? 0;
    final total = subtotal - discount;
    return total > 0 ? total : 0;
  }

  static String _receiptLedgerDescription(ReceiptVoucher receipt) {
    final base = receipt.description.trim().isEmpty
        ? 'سند قبض رقم ${receipt.receiptNumber}'
        : receipt.description.trim();
    final invoiceNumber = receipt.sourceInvoiceNumber.trim();
    return invoiceNumber.isEmpty
        ? base
        : '$base • الفاتورة المرتبطة $invoiceNumber';
  }

  static Map<String, dynamic> _decodeJson(String value) =>
      Map<String, dynamic>.from(jsonDecode(value) as Map);

  static String _normalizeDate(String value) {
    final text = value.trim();
    final match = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$')
        .firstMatch(text);
    if (match == null) return text;
    final day = match.group(1)!.padLeft(2, '0');
    final month = match.group(2)!.padLeft(2, '0');
    final year = match.group(3)!;
    return '$year-$month-$day';
  }
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
