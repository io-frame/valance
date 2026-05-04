import 'fx_models.dart';

class FxEngine {
  static const double goodSlippagePct = 1;
  static const double acceptableSlippagePct = 1.5;

  static OperationAnalysis analyzeOperation(
    FxOperation operation,
    BenchmarkRates rates,
  ) {
    final pair = _comparisonPair(operation, rates);
    final benchmarkRate = operation.benchmarkRate ?? pair.benchmarkRate;
    final slippage = (pair.actualRate / benchmarkRate - 1) * 100;
    final quality = _qualityFor(slippage);
    final direction = slippage >= 0 ? 'хуже' : 'лучше';
    final summary =
        'Вы обменяли на ${slippage.abs().toStringAsFixed(2)}% $direction публичного ориентира.';

    return OperationAnalysis(
      actualRate: pair.actualRate,
      benchmarkRate: benchmarkRate,
      slippagePct: slippage,
      rateLabel: operation.benchmarkRateLabel ?? pair.label,
      quality: quality,
      summary: summary,
    );
  }

  static FxOperation attachBenchmark(
    FxOperation operation,
    BenchmarkRates rates,
  ) {
    final pair = _comparisonPair(operation, rates);
    return FxOperation.withId(
      id: operation.id,
      occurredAt: operation.occurredAt,
      fromCurrency: operation.fromCurrency,
      fromAmount: operation.fromAmount,
      toCurrency: operation.toCurrency,
      toAmount: operation.toAmount,
      routeCurrency: operation.routeCurrency,
      comment: operation.comment,
      benchmarkRate: pair.benchmarkRate,
      benchmarkRateLabel: pair.label,
      benchmarkAsOf: rates.asOf,
    );
  }

  static ExchangeThreshold usdToEurThreshold({
    required double usdAmount,
    required BenchmarkRates rates,
    double maxSlippagePct = acceptableSlippagePct,
  }) {
    final fair = usdAmount / rates.eurUsd;
    return ExchangeThreshold(
      usdAmount: usdAmount,
      fairReceiveEur: fair,
      goodFromEur: fair * (1 - goodSlippagePct / 100),
      acceptableReceiveEur: fair * (1 - maxSlippagePct / 100),
    );
  }

  static ExchangeQuote quoteExchange({
    required Currency fromCurrency,
    required Currency toCurrency,
    required double fromAmount,
    required BenchmarkRates rates,
    double maxSlippagePct = acceptableSlippagePct,
  }) {
    final fairReceive = switch ((fromCurrency, toCurrency)) {
      (Currency.usd, Currency.eur) => fromAmount / rates.eurUsd,
      (Currency.eur, Currency.usd) => fromAmount * rates.eurUsd,
      _ => throw ArgumentError('Unsupported exchange pair'),
    };

    return ExchangeQuote(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      fromAmount: fromAmount,
      fairReceive: fairReceive,
      goodReceive: fairReceive * (1 - goodSlippagePct / 100),
      acceptableReceive: fairReceive * (1 - maxSlippagePct / 100),
    );
  }

  static InvestmentRecommendation recommendRubInvestment({
    required double rubAmount,
    required PortfolioSnapshot portfolio,
    required BenchmarkRates rates,
    required StrategyProfile strategy,
  }) {
    final currentEurShare = portfolio.eurShare(rates);
    final targetEurShare = strategy.targetEurShare;
    final targetGap = targetEurShare - currentEurShare;
    final eurCheap = rates.eurUsd < rates.lower5y;
    final eurExpensive = rates.eurUsd > rates.upper5y;
    final hasPortfolio = portfolio.usd > 0 || portfolio.eur > 0;

    var primaryEurShare = targetEurShare;
    if (hasPortfolio) {
      primaryEurShare += targetGap.clamp(-0.20, 0.20);
    }
    if (eurCheap) {
      primaryEurShare += 0.10;
    } else if (eurExpensive) {
      primaryEurShare -= 0.25;
      if (targetGap > 0.10) {
        primaryEurShare = primaryEurShare.clamp(0.35, targetEurShare);
      }
    }
    primaryEurShare = primaryEurShare.clamp(0.15, 0.75);

    final balancedEurShare = (targetEurShare + (hasPortfolio ? targetGap * 0.5 : 0))
        .clamp(0.20, 0.70);
    final conservativeEurShare = (primaryEurShare - 0.15).clamp(0.10, 0.60);

    final reasons = <String>[
      if (eurCheap)
        'EUR дешевле USD относительно 5-летнего коридора ${rates.lower5y.toStringAsFixed(2)}–${rates.upper5y.toStringAsFixed(2)}.',
      if (eurExpensive)
        'EUR дорогой относительно USD: долю EUR в новом пополнении лучше ограничить.',
      if (hasPortfolio && targetGap > 0.03)
        'EUR ниже целевой доли на ${(targetGap * 100).toStringAsFixed(0)} п.п., но курс всё равно учитывается.',
      if (hasPortfolio && targetGap < -0.03)
        'EUR выше целевой доли на ${(-targetGap * 100).toStringAsFixed(0)} п.п.',
      'EUR/USD изменился на ${rates.eurUsdDayChangePct.toStringAsFixed(1)}% за 1д; текущий курс относительно медианы: ${rates.eurUsdWeekMedianDeviationPct.toStringAsFixed(1)}% за 7д и ${rates.eurUsdMonthMedianDeviationPct.toStringAsFixed(1)}% за 30д.',
    ];

    return InvestmentRecommendation(
      primary: _allocation('Основной вариант', rubAmount, primaryEurShare),
      balanced:
          _allocation('Сбалансированный вариант', rubAmount, balancedEurShare),
      conservative: _allocation(
        'Консервативный вариант',
        rubAmount,
        conservativeEurShare,
      ),
      reasons: reasons,
    );
  }

  static PortfolioSnapshot applyOperations(
    PortfolioSnapshot initial,
    List<FxOperation> operations,
  ) {
    var usd = initial.usd;
    var eur = initial.eur;

    for (final operation in operations) {
      if (operation.fromCurrency == Currency.usd) usd -= operation.fromAmount;
      if (operation.fromCurrency == Currency.eur) eur -= operation.fromAmount;
      if (operation.toCurrency == Currency.usd) usd += operation.toAmount;
      if (operation.toCurrency == Currency.eur) eur += operation.toAmount;
    }

    return PortfolioSnapshot(usd: usd, eur: eur);
  }

  static double? averageRubBuyRate(
    Currency currency,
    List<FxOperation> operations,
  ) {
    final buys = operations.where(
      (operation) =>
          operation.fromCurrency == Currency.rub &&
          operation.toCurrency == currency,
    );
    final rubSpent = buys.fold<double>(
      0,
      (sum, operation) => sum + operation.fromAmount,
    );
    final received = buys.fold<double>(
      0,
      (sum, operation) => sum + operation.toAmount,
    );

    if (rubSpent == 0 || received == 0) return null;
    return rubSpent / received;
  }

  static ExchangeQuality _qualityFor(double slippagePct) {
    if (slippagePct <= goodSlippagePct) return ExchangeQuality.good;
    if (slippagePct <= acceptableSlippagePct) {
      return ExchangeQuality.acceptable;
    }
    return ExchangeQuality.bad;
  }

  static AllocationOption _allocation(
    String title,
    double rubAmount,
    double eurShare,
  ) {
    final eurRub = _roundToHundreds(rubAmount * eurShare);
    return AllocationOption(
      title: title,
      eurRub: eurRub,
      usdRub: rubAmount - eurRub,
    );
  }

  static double _roundToHundreds(double value) => (value / 100).round() * 100;

  static _ComparisonPair _comparisonPair(
    FxOperation operation,
    BenchmarkRates rates,
  ) {
    if (operation.toCurrency == Currency.eur &&
        operation.fromCurrency == Currency.rub) {
      return _ComparisonPair(
        actualRate: operation.fromAmount / operation.toAmount,
        benchmarkRate: rates.eurRub,
        label: 'RUB/EUR',
      );
    }

    if (operation.toCurrency == Currency.usd &&
        operation.fromCurrency == Currency.rub) {
      return _ComparisonPair(
        actualRate: operation.fromAmount / operation.toAmount,
        benchmarkRate: rates.usdRub,
        label: 'RUB/USD',
      );
    }

    if (operation.toCurrency == Currency.eur &&
        operation.fromCurrency == Currency.usd) {
      return _ComparisonPair(
        actualRate: operation.fromAmount / operation.toAmount,
        benchmarkRate: rates.eurUsd,
        label: 'USD/EUR',
      );
    }

    if (operation.toCurrency == Currency.usd &&
        operation.fromCurrency == Currency.eur) {
      return _ComparisonPair(
        actualRate: operation.toAmount / operation.fromAmount,
        benchmarkRate: rates.eurUsd,
        label: 'USD/EUR',
      );
    }

    return _ComparisonPair(
      actualRate: operation.fromAmount / operation.toAmount,
      benchmarkRate: operation.fromAmount / operation.toAmount,
      label: '${operation.fromCurrency.code}/${operation.toCurrency.code}',
    );
  }
}

class _ComparisonPair {
  const _ComparisonPair({
    required this.actualRate,
    required this.benchmarkRate,
    required this.label,
  });

  final double actualRate;
  final double benchmarkRate;
  final String label;
}
