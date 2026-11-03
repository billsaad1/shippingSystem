/// Exact money parsing for the local customer ledger.
///
/// The first accounting release stores USD and YER with two decimal places so
/// that existing receipt and invoice amounts are preserved without loss.
class MoneyMinorUnits {
  MoneyMinorUnits._();

  static const int scale = 2;
  static const int factor = 100;

  static int? tryParse(String value) {
    final normalized = _normalizeDigits(value.trim())
        .replaceAll('\u066B', '.')
        .replaceAll('\u066C', ',')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    if (normalized.isEmpty ||
        !RegExp(r'^[+-]?\d+(?:\.\d{1,2})?$').hasMatch(normalized)) {
      return null;
    }

    final negative = normalized.startsWith('-');
    final unsigned = normalized.startsWith('-') || normalized.startsWith('+')
        ? normalized.substring(1)
        : normalized;
    final parts = unsigned.split('.');
    final whole = int.tryParse(parts.first);
    if (whole == null || whole > (1 << 52)) return null;
    final fractional = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(scale, '0'));
    final amount = whole * factor + fractional;
    return negative ? -amount : amount;
  }

  static int parse(String value) {
    final result = tryParse(value);
    if (result == null) {
      throw FormatException('Invalid monetary amount', value);
    }
    return result;
  }

  static String format(int minorUnits, {bool grouping = true}) {
    final negative = minorUnits < 0;
    final absolute = minorUnits.abs();
    final whole = absolute ~/ factor;
    final fraction = (absolute % factor).toString().padLeft(scale, '0');
    final wholeText = grouping
        ? whole.toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => ',',
          )
        : whole.toString();
    return '${negative ? '-' : ''}$wholeText.$fraction';
  }

  static String _normalizeDigits(String value) {
    final output = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        output.write(String.fromCharCode(0x30 + rune - 0x0660));
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        output.write(String.fromCharCode(0x30 + rune - 0x06F0));
      } else {
        output.write(String.fromCharCode(rune));
      }
    }
    return output.toString();
  }
}
