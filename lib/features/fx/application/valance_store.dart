import 'package:flutter/foundation.dart';

import '../data/benchmark_rates_api.dart';
import '../domain/fx_engine.dart';
import '../domain/fx_models.dart';

class ValanceStore extends ChangeNotifier {
  ValanceStore({BenchmarkRatesApi? ratesApi}) : _ratesApi = ratesApi;

  final BenchmarkRatesApi? _ratesApi;
  bool isRatesLoading = false;
  String? ratesError;
  bool hasLiveRates = false;
  bool ratesStale = false;

  bool get canRecommend => hasLiveRates && !ratesStale;

  BenchmarkRates rates = const BenchmarkRates(
    usdRub: 98,
    eurRub: 105.20,
    eurUsd: 1.064,
    asOf: '2026-05-04',
    eurUsdDayChangePct: -0.4,
    eurUsdWeekMedianDeviationPct: -1.2,
    eurUsdMonthMedianDeviationPct: -2.8,
    eurUsdYearMedianDeviationPct: 3.6,
    lower5y: 1.07,
    upper5y: 1.16,
    eurUsdCbrCross: 1.071,
    eurUsdSourceSpreadPct: -0.65,
  );

  StrategyProfile strategy = StrategyProfile.active;
  PortfolioSnapshot initialPortfolio = const PortfolioSnapshot(
    usd: 0,
    eur: 0,
  );

  final List<FxOperation> _operations = [];

  List<FxOperation> get operations => List.unmodifiable(_operations);

  PortfolioSnapshot get portfolio =>
      FxEngine.applyOperations(initialPortfolio, _operations);

  void addOperation(FxOperation operation) {
    _operations.insert(0, operation);
    notifyListeners();
  }

  void setStrategy(StrategyProfile value) {
    strategy = value;
    notifyListeners();
  }

  void setInitialPortfolio({required double usd, required double eur}) {
    initialPortfolio = PortfolioSnapshot(usd: usd, eur: eur);
    notifyListeners();
  }

  Future<void> refreshRates() async {
    isRatesLoading = true;
    ratesError = null;
    notifyListeners();

    try {
      rates = await (_ratesApi ?? BenchmarkRatesApi()).fetch();
      hasLiveRates = true;
      ratesStale = false;
      debugPrint('[rates] fetch success asOf=${rates.asOf}');
    } catch (error) {
      if (!hasLiveRates) {
        hasLiveRates = false;
      }
      ratesStale = hasLiveRates;
      ratesError = error.toString();
      debugPrint('[rates] fetch failed: $error');
    } finally {
      isRatesLoading = false;
      notifyListeners();
    }
  }
}
