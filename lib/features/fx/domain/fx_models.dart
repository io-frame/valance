enum Currency {
  rub('RUB'),
  byn('BYN'),
  usd('USD'),
  eur('EUR');

  const Currency(this.code);

  final String code;

  static Currency parse(String value) {
    final normalized = value.trim().toUpperCase();
    return Currency.values.firstWhere(
      (currency) => currency.code == normalized,
      orElse: () => throw FormatException('Unknown currency: $value'),
    );
  }
}

const Object _unchangedAdjustmentSourceId = Object();

class MoneyAmount {
  const MoneyAmount({required this.currency, required this.amount});

  final Currency currency;
  final double amount;
}

class OperationRateLine {
  const OperationRateLine({
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.quotePerBase,
  });

  final Currency baseCurrency;
  final Currency quoteCurrency;
  final double quotePerBase;
}

class OperationRateWarning {
  const OperationRateWarning({
    required this.actualRate,
    required this.marketRate,
    required this.deviationPct,
  });

  final double actualRate;
  final double marketRate;
  final double deviationPct;
}

class WalletOperation {
  WalletOperation({
    String? id,
    required this.occurredAt,
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
    required this.toAmount,
    this.comment = '',
    this.adjustmentSourceId,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final DateTime occurredAt;
  final Currency fromCurrency;
  final double fromAmount;
  final Currency toCurrency;
  final double toAmount;
  final String comment;
  final String? adjustmentSourceId;

  bool get isAdjustment => adjustmentSourceId != null;

  WalletOperation copyWith({
    String? id,
    DateTime? occurredAt,
    Currency? fromCurrency,
    double? fromAmount,
    Currency? toCurrency,
    double? toAmount,
    String? comment,
    Object? adjustmentSourceId = _unchangedAdjustmentSourceId,
  }) {
    return WalletOperation(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      fromCurrency: fromCurrency ?? this.fromCurrency,
      fromAmount: fromAmount ?? this.fromAmount,
      toCurrency: toCurrency ?? this.toCurrency,
      toAmount: toAmount ?? this.toAmount,
      comment: comment ?? this.comment,
      adjustmentSourceId:
          identical(adjustmentSourceId, _unchangedAdjustmentSourceId)
          ? this.adjustmentSourceId
          : adjustmentSourceId as String?,
    );
  }
}

class WalletOperationGroup {
  const WalletOperationGroup({
    required this.source,
    required this.adjustments,
    required this.netFromAmount,
    required this.netToAmount,
  });

  final WalletOperation source;
  final List<WalletOperation> adjustments;
  final double netFromAmount;
  final double netToAmount;

  bool get hasAdjustments => adjustments.isNotEmpty;

  WalletOperation get netOperation => source.copyWith(
    fromAmount: netFromAmount,
    toAmount: netToAmount,
  );
}

class WalletPosition {
  const WalletPosition({
    required this.currency,
    required this.amount,
    this.currentRubValue,
  });

  final Currency currency;
  final double amount;
  final double? currentRubValue;
}

class WalletSnapshot {
  const WalletSnapshot({required this.positions});

  final List<WalletPosition> positions;

  WalletPosition position(Currency currency) {
    return positions.firstWhere((position) => position.currency == currency);
  }

  double? get totalCurrentRubValue {
    var total = 0.0;
    for (final position in positions) {
      final current = position.currentRubValue;
      if (current == null) return null;
      total += current;
    }
    return total;
  }
}

class PositionState {
  const PositionState({this.amount = 0});

  final double amount;
}

class EurUsdRangeStats {
  const EurUsdRangeStats({
    required this.years,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
    required this.observationCount,
  });

  final int years;
  final double p10;
  final double p25;
  final double p50;
  final double p75;
  final double p90;
  final int observationCount;
}

class FeedStatus {
  const FeedStatus({
    required this.sourceDate,
    required this.fetchedAt,
    this.error,
  });

  final DateTime? sourceDate;
  final DateTime? fetchedAt;
  final String? error;

  bool get hasData => sourceDate != null && error == null;
}

class RatesSnapshot {
  const RatesSnapshot({
    required this.usdRub,
    required this.eurRub,
    required this.bynRub,
    required this.eurUsd,
    required this.cbr,
    required this.ecb,
    required this.ranges,
  });

  final double? usdRub;
  final double? eurRub;
  final double? bynRub;
  final double? eurUsd;
  final FeedStatus cbr;
  final FeedStatus ecb;
  final Map<int, EurUsdRangeStats> ranges;

  bool get hasCurrentRubRates =>
      usdRub != null && eurRub != null && bynRub != null;
  bool get hasEurUsd => eurUsd != null;
}

enum RateFreshness { fresh, missing, stale }

class FeedFreshness {
  const FeedFreshness({required this.state, required this.label});

  final RateFreshness state;
  final String label;

  bool get isFresh => state == RateFreshness.fresh;
}

class RatesFreshness {
  const RatesFreshness({required this.cbr, required this.ecb});

  final FeedFreshness cbr;
  final FeedFreshness ecb;

  bool get canValueInRub => cbr.isFresh;
  bool get canShowEurUsd => ecb.isFresh;
}

class WalletComposition {
  const WalletComposition({
    required this.usdPct,
    required this.eurPct,
    required this.usdValue,
    required this.eurValue,
  });

  final double usdPct;
  final double eurPct;
  final double usdValue;
  final double eurValue;
}
