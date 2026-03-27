import 'dart:math';

import 'fx_models.dart';

class FxEngine {
  static const double tolerance = 0.000001;

  static List<WalletOperation> sortOperations(
    List<WalletOperation> operations,
  ) {
    return [...operations]..sort((a, b) {
      final byDate = a.occurredAt.compareTo(b.occurredAt);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
  }

  static String? validateOperation(WalletOperation operation) {
    if (operation.fromCurrency == operation.toCurrency) {
      return 'Валюты должны отличаться.';
    }
    if (!_isPositiveFinite(operation.fromAmount) ||
        !_isPositiveFinite(operation.toAmount)) {
      return 'Суммы должны быть положительными числами.';
    }
    return null;
  }

  static String? validateLedger(List<WalletOperation> operations) {
    try {
      calculatePositionStates(operations);
      return null;
    } on StateError catch (error) {
      return error.message;
    }
  }

  static Map<Currency, PositionState> calculatePositionStates(
    List<WalletOperation> operations,
  ) {
    final states = <Currency, _MutablePosition>{
      Currency.byn: _MutablePosition(),
      Currency.usd: _MutablePosition(),
      Currency.eur: _MutablePosition(),
    };

    for (final operation in sortOperations(operations)) {
      final validation = validateOperation(operation);
      if (validation != null) throw StateError(validation);

      if (operation.fromCurrency != Currency.rub) {
        final source = states[operation.fromCurrency]!;
        source.release(
          operation.fromAmount,
          label:
              '${operation.fromCurrency.code} после операции ${_dateLabel(operation.occurredAt)}',
        );
      }

      if (operation.toCurrency != Currency.rub) {
        final target = states[operation.toCurrency]!;
        target.add(operation.toAmount);
      }
    }

    return {
      for (final entry in states.entries)
        entry.key: PositionState(amount: _zero(entry.value.amount)),
    };
  }

  static WalletSnapshot calculateWallet({
    required List<WalletOperation> operations,
    required RatesSnapshot? rates,
    required RatesFreshness freshness,
  }) {
    final states = calculatePositionStates(operations);
    return WalletSnapshot(
      positions: [
        for (final currency in const [Currency.byn, Currency.usd, Currency.eur])
          WalletPosition(
            currency: currency,
            amount: states[currency]!.amount,
            currentRubValue: freshness.canValueInRub && rates != null
                ? currentRubValue(
                    currency: currency,
                    amount: states[currency]!.amount,
                    rates: rates,
                  )
                : null,
          ),
      ],
    );
  }

  static double netRubSpent(List<WalletOperation> operations) {
    var total = 0.0;
    for (final operation in operations) {
      if (operation.fromCurrency == Currency.rub) {
        total += operation.fromAmount;
      }
      if (operation.toCurrency == Currency.rub) {
        total -= operation.toAmount;
      }
    }
    return _zero(total);
  }

  static double? currentRubValue({
    required Currency currency,
    required double amount,
    required RatesSnapshot rates,
  }) {
    return switch (currency) {
      Currency.byn => rates.bynRub == null ? null : amount * rates.bynRub!,
      Currency.usd => rates.usdRub == null ? null : amount * rates.usdRub!,
      Currency.eur => rates.eurRub == null ? null : amount * rates.eurRub!,
      Currency.rub => amount,
    };
  }

  static WalletComposition? eurUsdComposition({
    required double usd,
    required double eur,
    required double? eurUsd,
  }) {
    if (eurUsd == null || eurUsd <= 0) return null;
    final usdValue = max(0.0, usd);
    final eurValue = max(0.0, eur * eurUsd);
    final total = usdValue + eurValue;
    if (total <= tolerance) return null;
    return WalletComposition(
      usdPct: usdValue / total * 100,
      eurPct: eurValue / total * 100,
      usdValue: usdValue,
      eurValue: eurValue,
    );
  }

  static List<OperationRateLine> actualRateLines(WalletOperation operation) {
    if (operation.fromAmount <= tolerance || operation.toAmount <= tolerance) {
      return const [];
    }
    return [
      OperationRateLine(
        baseCurrency: operation.fromCurrency,
        quoteCurrency: operation.toCurrency,
        quotePerBase: operation.toAmount / operation.fromAmount,
      ),
      OperationRateLine(
        baseCurrency: operation.toCurrency,
        quoteCurrency: operation.fromCurrency,
        quotePerBase: operation.fromAmount / operation.toAmount,
      ),
    ];
  }

  static OperationRateWarning? operationRateWarning({
    required WalletOperation operation,
    required RatesSnapshot? rates,
    double thresholdPct = 30,
  }) {
    final current = rates;
    if (current == null) return null;
    if (operation.fromAmount <= tolerance || operation.toAmount <= tolerance) {
      return null;
    }
    final actual = operation.toAmount / operation.fromAmount;
    final market = marketRate(
      baseCurrency: operation.fromCurrency,
      quoteCurrency: operation.toCurrency,
      rates: current,
    );
    if (market == null || market <= tolerance) return null;
    final deviationPct = ((actual - market).abs() / market) * 100;
    if (deviationPct < thresholdPct) return null;
    return OperationRateWarning(
      actualRate: actual,
      marketRate: market,
      deviationPct: deviationPct,
    );
  }

  static double? marketRate({
    required Currency baseCurrency,
    required Currency quoteCurrency,
    required RatesSnapshot rates,
  }) {
    if (baseCurrency == quoteCurrency) return 1;
    final baseRub = currentRubValue(
      currency: baseCurrency,
      amount: 1,
      rates: rates,
    );
    final quoteRub = currentRubValue(
      currency: quoteCurrency,
      amount: 1,
      rates: rates,
    );
    if (baseRub == null || quoteRub == null || quoteRub <= tolerance) {
      return null;
    }
    return baseRub / quoteRub;
  }

  static String buildOperationsCsv(List<WalletOperation> operations) {
    final rows = <List<String>>[
      [
        'id',
        'date',
        'from_currency',
        'from_amount',
        'to_currency',
        'to_amount',
        'comment',
      ],
      for (final operation in sortOperations(operations))
        [
          operation.id,
          operation.occurredAt.toIso8601String(),
          operation.fromCurrency.code,
          _csvNumber(operation.fromAmount),
          operation.toCurrency.code,
          _csvNumber(operation.toAmount),
          operation.comment,
        ],
    ];
    return rows.map((row) => row.map(_csvEscape).join(',')).join('\n');
  }

  static List<WalletOperation> parseOperationsCsv(String raw) {
    final rows = _parseCsv(raw);
    if (rows.isEmpty) return [];
    final header = rows.first.map((cell) => cell.trim()).toList();
    final idIndex = header.indexOf('id');
    final dateIndex = header.indexOf('date');
    final fromCurrencyIndex = header.indexOf('from_currency');
    final fromAmountIndex = header.indexOf('from_amount');
    final toCurrencyIndex = header.indexOf('to_currency');
    final toAmountIndex = header.indexOf('to_amount');
    final fromIndex = header.indexOf('from');
    final toIndex = header.indexOf('to');
    final commentIndex = header.indexOf('comment');
    final hasExpandedMoney =
        fromCurrencyIndex != -1 &&
        fromAmountIndex != -1 &&
        toCurrencyIndex != -1 &&
        toAmountIndex != -1;
    final hasCompactMoney = fromIndex != -1 && toIndex != -1;
    if (dateIndex == -1 || (!hasExpandedMoney && !hasCompactMoney)) {
      throw const FormatException('CSV header is incomplete.');
    }

    final operations = <WalletOperation>[];
    final ids = <String>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      String cell(int index) =>
          index >= 0 && index < row.length ? row[index] : '';
      final idRaw = idIndex == -1 ? '' : cell(idIndex).trim();
      final id = idRaw.isEmpty ? _generatedCsvId(row, i) : idRaw;
      if (!ids.add(id)) throw FormatException('Duplicate operation id: $id');
      final from = hasExpandedMoney
          ? MoneyAmount(
              currency: Currency.parse(cell(fromCurrencyIndex)),
              amount: _parseAmount(cell(fromAmountIndex)),
            )
          : _parseCompactMoney(cell(fromIndex));
      final to = hasExpandedMoney
          ? MoneyAmount(
              currency: Currency.parse(cell(toCurrencyIndex)),
              amount: _parseAmount(cell(toAmountIndex)),
            )
          : _parseCompactMoney(cell(toIndex));
      final operation = WalletOperation(
        id: id,
        occurredAt: _parseCsvDate(cell(dateIndex)),
        fromCurrency: from.currency,
        fromAmount: from.amount,
        toCurrency: to.currency,
        toAmount: to.amount,
        comment: commentIndex == -1 ? '' : cell(commentIndex),
      );
      final validation = validateOperation(operation);
      if (validation != null) throw FormatException(validation);
      operations.add(operation);
    }

    final ledgerError = validateLedger(operations);
    if (ledgerError != null) throw FormatException(ledgerError);
    return operations;
  }

  static Map<int, EurUsdRangeStats> calculateRanges(List<RatePoint> history) {
    if (history.isEmpty) return const {};
    final sorted = [...history]..sort((a, b) => a.date.compareTo(b.date));
    final latest = sorted.last.date;
    return {
      for (final years in const [1, 5, 10])
        years: _rangeFor(sorted, latest, years),
    };
  }

  static RatesFreshness freshness(RatesSnapshot? rates, {DateTime? now}) {
    final checkedAt = now ?? DateTime.now();
    if (rates == null) {
      return const RatesFreshness(
        cbr: FeedFreshness(
          state: RateFreshness.missing,
          label: 'ЦБ РФ не загружен',
        ),
        ecb: FeedFreshness(
          state: RateFreshness.missing,
          label: 'ECB не загружен',
        ),
      );
    }
    return RatesFreshness(
      cbr: _feedFreshness('ЦБ РФ', rates.cbr, checkedAt),
      ecb: _feedFreshness('ECB', rates.ecb, checkedAt),
    );
  }

  static EurUsdRangeStats _rangeFor(
    List<RatePoint> sorted,
    DateTime latest,
    int years,
  ) {
    final start = DateTime(latest.year - years, latest.month, latest.day);
    final values = sorted
        .where(
          (point) => !point.date.isBefore(start) && !point.date.isAfter(latest),
        )
        .map((point) => point.value)
        .toList();
    if (values.isEmpty) {
      throw StateError('No EUR/USD observations for ${years}Y');
    }
    return EurUsdRangeStats(
      years: years,
      p10: percentile(values, 0.10),
      p25: percentile(values, 0.25),
      p50: percentile(values, 0.50),
      p75: percentile(values, 0.75),
      p90: percentile(values, 0.90),
      observationCount: values.length,
    );
  }

  static double percentile(List<double> values, double p) {
    if (values.isEmpty) throw StateError('No values for percentile');
    final sorted = [...values]..sort();
    if (sorted.length == 1) return sorted.first;
    final rank = (sorted.length - 1) * p;
    final lower = rank.floor();
    final upper = rank.ceil();
    if (lower == upper) return sorted[lower];
    final weight = rank - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  static bool _isPositiveFinite(double value) =>
      value.isFinite && value > tolerance;

  static double _zero(double value) => value.abs() <= tolerance ? 0 : value;

  static String _csvNumber(double value) {
    var text = value.toStringAsFixed(8);
    while (text.contains('.') && text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text;
  }

  static String _csvEscape(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  static List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (char == '"') {
        if (inQuotes && i + 1 < raw.length && raw[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        row.add(cell.toString());
        cell.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < raw.length && raw[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(char);
      }
    }
    if (inQuotes) throw const FormatException('Unclosed CSV quote.');
    row.add(cell.toString());
    if (row.any((value) => value.isNotEmpty) || rows.isEmpty) rows.add(row);
    return rows;
  }

  static DateTime _parseCsvDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) throw const FormatException('Missing date.');
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return DateTime.parse('${value}T00:00:00');
    }
    return DateTime.parse(value);
  }

  static double _parseAmount(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || !_isPositiveFinite(value)) {
      throw FormatException('Invalid amount: $raw');
    }
    return value;
  }

  static MoneyAmount _parseCompactMoney(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) {
      throw FormatException('Invalid money value: $raw');
    }
    return MoneyAmount(
      amount: _parseAmount(parts[0]),
      currency: Currency.parse(parts[1]),
    );
  }

  static String _generatedCsvId(List<String> row, int index) {
    var hash = 0x811c9dc5;
    final text = '$index|${row.join('|')}';
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'csv-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static FeedFreshness _feedFreshness(
    String label,
    FeedStatus status,
    DateTime now,
  ) {
    if (status.error != null && status.sourceDate == null) {
      return FeedFreshness(
        state: RateFreshness.missing,
        label: '$label: ${status.error}',
      );
    }
    final sourceDate = status.sourceDate;
    if (sourceDate == null) {
      return FeedFreshness(
        state: RateFreshness.missing,
        label: '$label не загружен',
      );
    }
    final age = DateTime(now.year, now.month, now.day)
        .difference(DateTime(sourceDate.year, sourceDate.month, sourceDate.day))
        .inDays;
    if (age <= 5) {
      if (status.error != null) {
        return FeedFreshness(
          state: RateFreshness.fresh,
          label: _freshLabel(label, sourceDate, hasError: true),
        );
      }
      return FeedFreshness(
        state: RateFreshness.fresh,
        label: _freshLabel(label, sourceDate),
      );
    }
    return FeedFreshness(
      state: RateFreshness.stale,
      label: status.error == null
          ? '$label устарел: ${_dateLabel(sourceDate)}'
          : '$label устарел: ${_dateLabel(sourceDate)}; ${status.error}',
    );
  }

  static String _freshLabel(
    String label,
    DateTime sourceDate, {
    bool hasError = false,
  }) {
    final prefix = label == 'ЦБ РФ'
        ? 'Оценка по курсу ЦБ: ${_dateLabel(sourceDate)}'
        : '$label: ${_dateLabel(sourceDate)}';
    if (!hasError) return prefix;
    return '$prefix; последнее обновление не прошло';
  }

  static String _dateLabel(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }
}

class RatePoint {
  const RatePoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class _MutablePosition {
  double amount = 0;

  void add(double value) {
    amount += value;
    _normalize();
  }

  void release(double value, {required String label}) {
    if (value > amount + FxEngine.tolerance) {
      throw StateError('История уводит $label в минус.');
    }
    amount -= min(value, amount);
    _normalize();
  }

  void _normalize() {
    if (amount.abs() <= FxEngine.tolerance) {
      amount = 0;
    }
  }
}
