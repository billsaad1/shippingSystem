class Customer {
  const Customer({
    this.id,
    this.customerNumber = '',
    required this.name,
    this.englishName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.isActive = true,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final int? id;
  final String customerNumber;
  final String name;
  final String englishName;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Customer copyWith({
    int? id,
    String? customerNumber,
    String? name,
    String? englishName,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) => Customer(
    id: id ?? this.id,
    customerNumber: customerNumber ?? this.customerNumber,
    name: name ?? this.name,
    englishName: englishName ?? this.englishName,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory Customer.fromMap(Map<String, Object?> row) => Customer(
    id: (row['id'] as num?)?.toInt(),
    customerNumber: row['customer_number'] as String? ?? '',
    name: row['name'] as String? ?? '',
    englishName: row['english_name'] as String? ?? '',
    phone: row['phone'] as String? ?? '',
    email: row['email'] as String? ?? '',
    address: row['address'] as String? ?? '',
    notes: row['notes'] as String? ?? '',
    isActive: (row['is_active'] as num? ?? 1) != 0,
    createdAt: row['created_at'] as String? ?? '',
    updatedAt: row['updated_at'] as String? ?? '',
  );
}

class CustomerAccountSummary {
  const CustomerAccountSummary({
    required this.customer,
    required this.usdBalanceMinor,
    required this.yerBalanceMinor,
  });

  final Customer customer;
  final int usdBalanceMinor;
  final int yerBalanceMinor;
}

class CustomerLedgerEntry {
  const CustomerLedgerEntry({
    this.id,
    required this.customerId,
    required this.entryDate,
    required this.currency,
    required this.entryType,
    required this.debitMinor,
    required this.creditMinor,
    required this.sourceType,
    required this.sourceNumber,
    required this.description,
    this.isLegacy = false,
  });

  final int? id;
  final int customerId;
  final String entryDate;
  final String currency;
  final String entryType;
  final int debitMinor;
  final int creditMinor;
  final String sourceType;
  final String sourceNumber;
  final String description;
  final bool isLegacy;

  int get balanceChangeMinor => debitMinor - creditMinor;

  factory CustomerLedgerEntry.fromMap(Map<String, Object?> row) =>
      CustomerLedgerEntry(
        id: (row['id'] as num?)?.toInt(),
        customerId: (row['customer_id'] as num).toInt(),
        entryDate: row['entry_date'] as String? ?? '',
        currency: row['currency'] as String? ?? 'USD',
        entryType: row['entry_type'] as String? ?? '',
        debitMinor: (row['debit_minor'] as num? ?? 0).toInt(),
        creditMinor: (row['credit_minor'] as num? ?? 0).toInt(),
        sourceType: row['source_type'] as String? ?? '',
        sourceNumber: row['source_number'] as String? ?? '',
        description: row['description'] as String? ?? '',
        isLegacy: (row['is_legacy'] as num? ?? 0) != 0,
      );
}

class CustomerInvoiceBalance {
  const CustomerInvoiceBalance({
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.currency,
    required this.totalMinor,
    required this.paidMinor,
    required this.outstandingMinor,
  });

  final String invoiceNumber;
  final String invoiceDate;
  final String currency;
  final int totalMinor;
  final int paidMinor;
  final int outstandingMinor;
}
