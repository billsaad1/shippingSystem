class ChargeLine {
  const ChargeLine({this.payee = '', this.description = '', this.amount = ''});

  final String payee;
  final String description;
  final String amount;

  double get numericAmount => parseAmount(amount);

  Map<String, Object?> toJson() => {
    'payee': payee,
    'description': description,
    'amount': amount,
  };

  factory ChargeLine.fromJson(Map<String, dynamic> json) => ChargeLine(
    payee: json['payee'] as String? ?? '',
    description: json['description'] as String? ?? '',
    amount: json['amount'] as String? ?? '',
  );
}

class ShippingInvoice {
  const ShippingInvoice({
    this.invoiceNumber = '',
    this.invoiceDate = '',
    this.currency = 'USD',
    this.billOfLadingNumber = '',
    this.releaseMethod = '',
    this.transportName = '',
    this.voyageNumber = '',
    this.portOfLoading = '',
    this.portOfDischarge = '',
    this.arrivalDate = '',
    this.customerName = '',
    this.customerNumber = '',
    this.containerCount = '',
    this.quantity = '',
    this.weight = '',
    this.weightUnit = 'طن',
    this.chargeLines = const [],
    this.discount = '',
  });

  final String invoiceNumber;
  final String invoiceDate;
  final String currency;
  final String billOfLadingNumber;
  final String releaseMethod;
  final String transportName;
  final String voyageNumber;
  final String portOfLoading;
  final String portOfDischarge;
  final String arrivalDate;
  final String customerName;
  final String customerNumber;
  final String containerCount;
  final String quantity;
  final String weight;
  final String weightUnit;
  final List<ChargeLine> chargeLines;
  final String discount;

  double get subtotal =>
      chargeLines.fold<double>(0, (total, line) => total + line.numericAmount);

  double get discountValue => parseAmount(discount);

  double get total =>
      (subtotal - discountValue).clamp(0, double.infinity).toDouble();

  Map<String, Object?> toJson() => {
    'invoiceNumber': invoiceNumber,
    'invoiceDate': invoiceDate,
    'currency': currency,
    'billOfLadingNumber': billOfLadingNumber,
    'releaseMethod': releaseMethod,
    'transportName': transportName,
    'voyageNumber': voyageNumber,
    'portOfLoading': portOfLoading,
    'portOfDischarge': portOfDischarge,
    'arrivalDate': arrivalDate,
    'customerName': customerName,
    'customerNumber': customerNumber,
    'containerCount': containerCount,
    'quantity': quantity,
    'weight': weight,
    'weightUnit': weightUnit,
    'chargeLines': chargeLines.map((line) => line.toJson()).toList(),
    'discount': discount,
  };

  factory ShippingInvoice.fromJson(Map<String, dynamic> json) {
    final rawLines = json['chargeLines'] as List<dynamic>? ?? const [];
    return ShippingInvoice(
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      invoiceDate: json['invoiceDate'] as String? ?? '',
      currency: json['currency'] as String? ?? 'USD',
      billOfLadingNumber: json['billOfLadingNumber'] as String? ?? '',
      releaseMethod: json['releaseMethod'] as String? ?? '',
      transportName: json['transportName'] as String? ?? '',
      voyageNumber: json['voyageNumber'] as String? ?? '',
      portOfLoading: json['portOfLoading'] as String? ?? '',
      portOfDischarge: json['portOfDischarge'] as String? ?? '',
      arrivalDate: json['arrivalDate'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerNumber: json['customerNumber'] as String? ?? '',
      containerCount: json['containerCount'] as String? ?? '',
      quantity: json['quantity'] as String? ?? '',
      weight: json['weight'] as String? ?? '',
      weightUnit: json['weightUnit'] as String? ?? 'طن',
      chargeLines: rawLines
          .whereType<Map<String, dynamic>>()
          .map(ChargeLine.fromJson)
          .toList(),
      discount: json['discount'] as String? ?? '',
    );
  }
}

class ReceiptVoucher {
  const ReceiptVoucher({
    this.receiptNumber = '',
    this.receiptDate = '',
    this.bankNumber = '',
    this.customerName = '',
    this.amount = '',
    this.currency = 'USD',
    this.amountInWords = '',
    this.bankName = '',
    this.chequeNumber = '',
    this.referenceNumber = '',
    this.dueDate = '',
    this.description = '',
  });

  final String receiptNumber;
  final String receiptDate;
  final String bankNumber;
  final String customerName;
  final String amount;
  final String currency;
  final String amountInWords;
  final String bankName;
  final String chequeNumber;
  final String referenceNumber;
  final String dueDate;
  final String description;

  double get numericAmount => parseAmount(amount);

  Map<String, Object?> toJson() => {
    'receiptNumber': receiptNumber,
    'receiptDate': receiptDate,
    'bankNumber': bankNumber,
    'customerName': customerName,
    'amount': amount,
    'currency': currency,
    'amountInWords': amountInWords,
    'bankName': bankName,
    'chequeNumber': chequeNumber,
    'referenceNumber': referenceNumber,
    'dueDate': dueDate,
    'description': description,
  };

  factory ReceiptVoucher.fromJson(Map<String, dynamic> json) => ReceiptVoucher(
    receiptNumber: json['receiptNumber'] as String? ?? '',
    receiptDate: json['receiptDate'] as String? ?? '',
    bankNumber: json['bankNumber'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    amount: json['amount'] as String? ?? '',
    currency: json['currency'] as String? ?? 'USD',
    amountInWords: json['amountInWords'] as String? ?? '',
    bankName: json['bankName'] as String? ?? '',
    chequeNumber: json['chequeNumber'] as String? ?? '',
    referenceNumber: json['referenceNumber'] as String? ?? '',
    dueDate: json['dueDate'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}

double parseAmount(String value) {
  final normalized = value.replaceAll(',', '').trim();
  return double.tryParse(normalized) ?? 0;
}
