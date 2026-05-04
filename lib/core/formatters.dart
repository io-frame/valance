import 'package:intl/intl.dart';

final _moneyFormatter = NumberFormat.decimalPattern('ru');
final _rateFormatter = NumberFormat('#,##0.0000', 'ru');

String money(num value, String code) {
  final rounded = value.abs() >= 1000 ? value.round() : value;
  return '${_moneyFormatter.format(rounded)} $code';
}

String rate(num value) => _rateFormatter.format(value);

String pct(num value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}
