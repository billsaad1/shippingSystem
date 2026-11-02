class AmountToWordsArabic {
  static const _ones = <String>[
    'صفر',
    'واحد',
    'اثنان',
    'ثلاثة',
    'أربعة',
    'خمسة',
    'ستة',
    'سبعة',
    'ثمانية',
    'تسعة',
    'عشرة',
    'أحد عشر',
    'اثنا عشر',
    'ثلاثة عشر',
    'أربعة عشر',
    'خمسة عشر',
    'ستة عشر',
    'سبعة عشر',
    'ثمانية عشر',
    'تسعة عشر',
  ];

  static const _tens = <String>[
    '',
    '',
    'عشرون',
    'ثلاثون',
    'أربعون',
    'خمسون',
    'ستون',
    'سبعون',
    'ثمانون',
    'تسعون',
  ];

  static const _hundreds = <String>[
    '',
    'مائة',
    'مائتان',
    'ثلاثمائة',
    'أربعمائة',
    'خمسمائة',
    'ستمائة',
    'سبعمائة',
    'ثمانمائة',
    'تسعمائة',
  ];

  static String convert(double value, String currency) {
    final minorUnits = (value.abs() * 100).round();
    final whole = minorUnits ~/ 100;
    final fraction = minorUnits % 100;
    final isUsd = currency.toUpperCase() == 'USD';
    final currencyName = isUsd ? 'دولار أمريكي' : 'ريال يمني';
    final fractionName = isUsd ? 'سنت' : 'فلس';
    final sign = value < 0 ? 'سالب ' : '';

    final parts = <String>['$sign${_integer(whole)} $currencyName'];
    if (fraction > 0) {
      parts.add('${_integer(fraction)} $fractionName');
    }
    return 'فقط ${parts.join(' و')} لا غير';
  }

  static String _integer(int value) {
    if (value < 20) return _ones[value];
    if (value < 100) {
      final unit = value % 10;
      final ten = value ~/ 10;
      return unit == 0 ? _tens[ten] : '${_ones[unit]} و${_tens[ten]}';
    }
    if (value < 1000) {
      final hundred = value ~/ 100;
      final remainder = value % 100;
      return remainder == 0
          ? _hundreds[hundred]
          : '${_hundreds[hundred]} و${_integer(remainder)}';
    }

    const scales = <String>['', 'ألف', 'مليون', 'مليار'];
    final groups = <int>[];
    var rest = value;
    while (rest > 0) {
      groups.add(rest % 1000);
      rest ~/= 1000;
    }

    final segments = <String>[];
    for (var index = groups.length - 1; index >= 0; index--) {
      final group = groups[index];
      if (group == 0) continue;
      final words = _integer(group);
      if (index == 0) {
        segments.add(words);
      } else {
        final scaleIndex = index < scales.length ? index : scales.length - 1;
        final scale = scales[scaleIndex];
        segments.add('$words $scale');
      }
    }
    return segments.join(' و');
  }
}
