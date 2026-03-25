import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _moneyFormatter = NumberFormat.decimalPattern('ru');
final _currencyFormatter = NumberFormat('#,##0.00', 'ru');
final _rateFormatter = NumberFormat('#,##0.####', 'ru');
final _preciseRateFormatter = NumberFormat('#,##0.########', 'ru');
final _percentFormatter = NumberFormat('#,##0.00', 'ru');
final _largePercentFormatter = NumberFormat('#,##0', 'ru');
final _dateFormatter = DateFormat('dd.MM.yyyy', 'ru');

String money(num value, String code, {bool detailed = false}) {
  if (code == 'RUB') {
    final amount = detailed
        ? _currencyFormatter.format(value)
        : _moneyFormatter.format(value.round());
    return '$amount ${currencySymbol(code)}';
  }
  return '${_currencyFormatter.format(value)} $code';
}

String moneyWithCode(num value, String code) {
  final amount = value.roundToDouble() == value
      ? _moneyFormatter.format(value)
      : _currencyFormatter.format(value);
  return '$amount $code';
}

String rate(num value) {
  final abs = value.abs();
  if (abs > 0 && abs < 0.01) return _preciseRateFormatter.format(value);
  return _rateFormatter.format(value);
}

String pct(num value) {
  final sign = value > 0 ? '+' : '';
  final formatter = value.abs() >= 1000
      ? _largePercentFormatter
      : _percentFormatter;
  return '$sign${formatter.format(value)}%';
}

String unsignedPct(num value) {
  final formatter = value.abs() >= 1000
      ? _largePercentFormatter
      : _percentFormatter;
  return '${formatter.format(value)}%';
}

String appDate(DateTime value) => _dateFormatter.format(value);

String currencySymbol(String code) {
  return switch (code) {
    'RUB' => '₽',
    'USD' => '\$',
    'EUR' => '€',
    'BYN' => 'BYN',
    _ => code,
  };
}

double? parseLocalizedNumber(String raw) {
  final normalized = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

class LocalizedDecimalInputFormatter extends TextInputFormatter {
  const LocalizedDecimalInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    var hasSeparator = false;
    var selectionOffset = newValue.selection.end;

    for (var i = 0; i < newValue.text.length; i++) {
      final char = newValue.text[i];
      final isSeparator = char == ',' || char == '.';
      if (_isDigit(char)) {
        buffer.write(char);
      } else if (isSeparator && !hasSeparator) {
        buffer.write(',');
        hasSeparator = true;
      } else if (i < newValue.selection.end) {
        selectionOffset--;
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selectionOffset.clamp(0, text.length).toInt(),
      ),
    );
  }

  bool _isDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
