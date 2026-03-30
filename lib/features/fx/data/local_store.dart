import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fx_engine.dart';
import '../domain/fx_models.dart';

class LocalStore {
  static const _operationsKey = 'wallet.operations.v1';
  static const _ratesKey = 'wallet.rates.v1';

  Future<List<WalletOperation>> loadOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_operationsKey);
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw) as List<dynamic>;
      final operations = json
          .map((item) => _operationFromJson(item as Map<String, dynamic>))
          .toList();
      final ledgerError = FxEngine.validateLedger(operations);
      if (ledgerError != null) throw FormatException(ledgerError);
      return operations;
    } catch (error) {
      await prefs.setString('$_operationsKey.corrupted', raw);
      throw FormatException('Не удалось прочитать историю: $error');
    }
  }

  Future<void> saveOperations(List<WalletOperation> operations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _operationsKey,
      jsonEncode(operations.map(_operationToJson).toList()),
    );
  }

  Future<RatesSnapshot?> loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ratesKey);
    if (raw == null) return null;
    try {
      return _ratesFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      await prefs.setString('$_ratesKey.corrupted', raw);
      throw FormatException('Не удалось прочитать курсы: $error');
    }
  }

  Future<void> saveRates(RatesSnapshot rates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ratesKey, jsonEncode(_ratesToJson(rates)));
  }

  Map<String, dynamic> _operationToJson(WalletOperation operation) => {
    'id': operation.id,
    'occurredAt': operation.occurredAt.toIso8601String(),
    'fromCurrency': operation.fromCurrency.code,
    'fromAmount': operation.fromAmount,
    'toCurrency': operation.toCurrency.code,
    'toAmount': operation.toAmount,
    'comment': operation.comment,
  };

  WalletOperation _operationFromJson(Map<String, dynamic> json) {
    return WalletOperation(
      id: json['id'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      fromCurrency: Currency.parse(json['fromCurrency'] as String),
      fromAmount: (json['fromAmount'] as num).toDouble(),
      toCurrency: Currency.parse(json['toCurrency'] as String),
      toAmount: (json['toAmount'] as num).toDouble(),
      comment: json['comment'] as String? ?? '',
    );
  }

  Map<String, dynamic> _ratesToJson(RatesSnapshot rates) => {
    'usdRub': rates.usdRub,
    'eurRub': rates.eurRub,
    'bynRub': rates.bynRub,
    'eurUsd': rates.eurUsd,
    'cbr': _feedToJson(rates.cbr),
    'ecb': _feedToJson(rates.ecb),
    'ranges': {
      for (final entry in rates.ranges.entries)
        entry.key.toString(): _rangeToJson(entry.value),
    },
  };

  RatesSnapshot _ratesFromJson(Map<String, dynamic> json) {
    final rawRanges = json['ranges'] as Map<String, dynamic>? ?? const {};
    return RatesSnapshot(
      usdRub: (json['usdRub'] as num?)?.toDouble(),
      eurRub: (json['eurRub'] as num?)?.toDouble(),
      bynRub: (json['bynRub'] as num?)?.toDouble(),
      eurUsd: (json['eurUsd'] as num?)?.toDouble(),
      cbr: _feedFromJson(json['cbr'] as Map<String, dynamic>? ?? const {}),
      ecb: _feedFromJson(json['ecb'] as Map<String, dynamic>? ?? const {}),
      ranges: {
        for (final entry in rawRanges.entries)
          int.parse(entry.key): _rangeFromJson(
            entry.value as Map<String, dynamic>,
          ),
      },
    );
  }

  Map<String, dynamic> _feedToJson(FeedStatus status) => {
    'sourceDate': status.sourceDate?.toIso8601String(),
    'fetchedAt': status.fetchedAt?.toIso8601String(),
    'error': status.error,
  };

  FeedStatus _feedFromJson(Map<String, dynamic> json) {
    return FeedStatus(
      sourceDate: json['sourceDate'] == null
          ? null
          : DateTime.parse(json['sourceDate'] as String),
      fetchedAt: json['fetchedAt'] == null
          ? null
          : DateTime.parse(json['fetchedAt'] as String),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> _rangeToJson(EurUsdRangeStats range) => {
    'years': range.years,
    'p10': range.p10,
    'p25': range.p25,
    'p50': range.p50,
    'p75': range.p75,
    'p90': range.p90,
    'observationCount': range.observationCount,
  };

  EurUsdRangeStats _rangeFromJson(Map<String, dynamic> json) {
    return EurUsdRangeStats(
      years: (json['years'] as num).toInt(),
      p10: (json['p10'] as num).toDouble(),
      p25: (json['p25'] as num).toDouble(),
      p50: (json['p50'] as num).toDouble(),
      p75: (json['p75'] as num).toDouble(),
      p90: (json['p90'] as num).toDouble(),
      observationCount: (json['observationCount'] as num).toInt(),
    );
  }
}

class CsvBackup {
  const CsvBackup();

  String encode(List<WalletOperation> operations) {
    return FxEngine.buildOperationsCsv(operations);
  }

  List<WalletOperation> decode(String raw) {
    return FxEngine.parseOperationsCsv(raw);
  }
}
