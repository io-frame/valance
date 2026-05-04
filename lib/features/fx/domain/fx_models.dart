enum Currency {
  rub('RUB', '₽'),
  usd('USD', r'$'),
  eur('EUR', '€'),
  byn('BYN', 'Br');

  const Currency(this.code, this.symbol);

  final String code;
  final String symbol;
}

enum StrategyProfile {
  conservative('Консервативная', 0.50, 0.50),
  moderate('Умеренная', 0.45, 0.55),
  active('Активная', 0.35, 0.65);

  const StrategyProfile(this.title, this.targetUsdShare, this.targetEurShare);

  final String title;
  final double targetUsdShare;
  final double targetEurShare;
}

enum ExchangeQuality {
  good('хорошо'),
  acceptable('приемлемо'),
  bad('плохо');

  const ExchangeQuality(this.title);

  final String title;
}

class BenchmarkRates {
  const BenchmarkRates({
    required this.usdRub,
    required this.eurRub,
    required this.eurUsd,
    required this.asOf,
    this.ecbAsOf,
    this.cbrAsOf,
    required this.eurUsdDayChangePct,
    required this.eurUsdWeekMedianDeviationPct,
    required this.eurUsdMonthMedianDeviationPct,
    required this.eurUsdYearMedianDeviationPct,
    this.lower3y = 1.06,
    this.upper3y = 1.14,
    required this.lower5y,
    required this.upper5y,
    this.lower10y = 1.05,
    this.upper10y = 1.18,
    this.eurUsdCbrCross,
    this.eurUsdSourceSpreadPct,
    this.sourceLabel = '',
    this.corridorLabel = '',
  });

  final double usdRub;
  final double eurRub;
  final double eurUsd;
  final String asOf;
  final String? ecbAsOf;
  final String? cbrAsOf;
  final double eurUsdDayChangePct;
  final double eurUsdWeekMedianDeviationPct;
  final double eurUsdMonthMedianDeviationPct;
  final double eurUsdYearMedianDeviationPct;
  final double lower3y;
  final double upper3y;
  final double lower5y;
  final double upper5y;
  final double lower10y;
  final double upper10y;
  final double? eurUsdCbrCross;
  final double? eurUsdSourceSpreadPct;
  final String sourceLabel;
  final String corridorLabel;
}

class FxOperation {
  FxOperation({
    required this.occurredAt,
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
    required this.toAmount,
    this.routeCurrency,
    this.comment = '',
    this.benchmarkRate,
    this.benchmarkRateLabel,
    this.benchmarkAsOf,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();

  FxOperation.withId({
    required this.id,
    required this.occurredAt,
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
    required this.toAmount,
    this.routeCurrency,
    this.comment = '',
    this.benchmarkRate,
    this.benchmarkRateLabel,
    this.benchmarkAsOf,
  });

  final String id;
  final DateTime occurredAt;
  final Currency fromCurrency;
  final double fromAmount;
  final Currency toCurrency;
  final double toAmount;
  final Currency? routeCurrency;
  final String comment;
  final double? benchmarkRate;
  final String? benchmarkRateLabel;
  final String? benchmarkAsOf;
}

class OperationAnalysis {
  const OperationAnalysis({
    required this.actualRate,
    required this.benchmarkRate,
    required this.slippagePct,
    required this.rateLabel,
    required this.quality,
    required this.summary,
  });

  final double actualRate;
  final double benchmarkRate;
  final double slippagePct;
  final String rateLabel;
  final ExchangeQuality quality;
  final String summary;
}

class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.usd,
    required this.eur,
  });

  final double usd;
  final double eur;

  double valueUsd(BenchmarkRates rates) => usd + eur * rates.eurUsd;

  double get totalUnits => usd + eur;

  double usdShare(BenchmarkRates rates) {
    final total = valueUsd(rates);
    return total == 0 ? 0 : usd / total;
  }

  double eurShare(BenchmarkRates rates) {
    final total = valueUsd(rates);
    return total == 0 ? 0 : (eur * rates.eurUsd) / total;
  }
}

class ExchangeThreshold {
  const ExchangeThreshold({
    required this.usdAmount,
    required this.fairReceiveEur,
    required this.goodFromEur,
    required this.acceptableReceiveEur,
  });

  final double usdAmount;
  final double fairReceiveEur;
  final double goodFromEur;
  final double acceptableReceiveEur;
}

class ExchangeQuote {
  const ExchangeQuote({
    required this.fromCurrency,
    required this.toCurrency,
    required this.fromAmount,
    required this.fairReceive,
    required this.goodReceive,
    required this.acceptableReceive,
  });

  final Currency fromCurrency;
  final Currency toCurrency;
  final double fromAmount;
  final double fairReceive;
  final double goodReceive;
  final double acceptableReceive;
}

class AllocationOption {
  const AllocationOption({
    required this.title,
    required this.eurRub,
    required this.usdRub,
  });

  final String title;
  final double eurRub;
  final double usdRub;
}

class InvestmentRecommendation {
  const InvestmentRecommendation({
    required this.primary,
    required this.balanced,
    required this.conservative,
    required this.reasons,
  });

  final AllocationOption primary;
  final AllocationOption balanced;
  final AllocationOption conservative;
  final List<String> reasons;
}
