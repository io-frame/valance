import 'package:flutter/foundation.dart';

import '../data/benchmark_rates_api.dart';
import '../data/local_store.dart';
import '../domain/fx_engine.dart';
import '../domain/fx_models.dart';

class ValanceStore extends ChangeNotifier {
  ValanceStore({BenchmarkRatesApi? ratesApi, LocalStore? localStore})
    : _ratesApi = ratesApi ?? BenchmarkRatesApi(),
      _localStore = localStore ?? LocalStore();

  final BenchmarkRatesApi _ratesApi;
  final LocalStore _localStore;
  final CsvBackup _csvBackup = const CsvBackup();
  final List<WalletOperation> _operations = [];

  bool isReady = false;
  bool isRatesLoading = false;
  String? ratesError;
  String? loadError;
  RatesSnapshot? rates;

  List<WalletOperation> get operations =>
      FxEngine.sortOperations(_operations).reversed.toList();

  RatesFreshness get freshness => FxEngine.freshness(rates);

  WalletSnapshot get wallet => FxEngine.calculateWallet(
    operations: _operations,
    rates: rates,
    freshness: freshness,
  );

  WalletComposition? get eurUsdComposition {
    final states = FxEngine.calculatePositionStates(_operations);
    return FxEngine.eurUsdComposition(
      usd: states[Currency.usd]!.amount,
      eur: states[Currency.eur]!.amount,
      eurUsd: freshness.canShowEurUsd ? rates?.eurUsd : null,
    );
  }

  Future<void> load() async {
    loadError = null;
    try {
      _operations
        ..clear()
        ..addAll(await _localStore.loadOperations());
      rates = await _localStore.loadRates();
    } catch (error) {
      loadError = error.toString();
    }
    isReady = true;
    notifyListeners();
  }

  Future<void> refreshRates() async {
    isRatesLoading = true;
    ratesError = null;
    notifyListeners();
    try {
      final fetched = await _ratesApi.fetch();
      rates = fetched;
      await _localStore.saveRates(fetched);
    } catch (error) {
      ratesError = error.toString();
      final current = rates;
      if (current != null) {
        rates = RatesSnapshot(
          usdRub: current.usdRub,
          eurRub: current.eurRub,
          bynRub: current.bynRub,
          eurUsd: current.eurUsd,
          cbr: FeedStatus(
            sourceDate: current.cbr.sourceDate,
            fetchedAt: current.cbr.fetchedAt,
            error: ratesError,
          ),
          ecb: FeedStatus(
            sourceDate: current.ecb.sourceDate,
            fetchedAt: current.ecb.fetchedAt,
            error: ratesError,
          ),
          ranges: current.ranges,
        );
      }
    } finally {
      isRatesLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addOperation(WalletOperation operation) async {
    return upsertOperation(operation);
  }

  Future<String?> upsertOperation(WalletOperation operation) async {
    final validation = FxEngine.validateOperation(operation);
    if (validation != null) return validation;
    final next = [
      for (final item in _operations)
        if (item.id != operation.id) item,
      operation,
    ];
    final ledgerError = FxEngine.validateLedger(next);
    if (ledgerError != null) return ledgerError;
    _operations
      ..clear()
      ..addAll(next);
    await _localStore.saveOperations(_operations);
    notifyListeners();
    return null;
  }

  Future<String?> deleteOperation(String id) async {
    final next = _operations
        .where((operation) => operation.id != id)
        .toList(growable: false);
    final ledgerError = FxEngine.validateLedger(next);
    if (ledgerError != null) return ledgerError;
    _operations
      ..clear()
      ..addAll(next);
    await _localStore.saveOperations(_operations);
    notifyListeners();
    return null;
  }

  String exportCsv() => _csvBackup.encode(_operations);

  ({List<WalletOperation> operations, String? error}) previewCsv(String raw) {
    try {
      return (operations: _csvBackup.decode(raw), error: null);
    } on FormatException catch (error) {
      return (operations: const [], error: error.message);
    } on StateError catch (error) {
      return (operations: const [], error: error.message);
    }
  }

  Future<String?> importOperations({
    required List<WalletOperation> operations,
    required bool replace,
  }) async {
    final existingIds = _operations.map((operation) => operation.id).toSet();
    final imported = replace
        ? operations
        : [
            for (final operation in operations)
              existingIds.contains(operation.id)
                  ? WalletOperation(
                      occurredAt: operation.occurredAt,
                      fromCurrency: operation.fromCurrency,
                      fromAmount: operation.fromAmount,
                      toCurrency: operation.toCurrency,
                      toAmount: operation.toAmount,
                      comment: operation.comment,
                    )
                  : operation,
          ];
    final next = replace ? imported : [..._operations, ...imported];
    final ledgerError = FxEngine.validateLedger(next);
    if (ledgerError != null) return ledgerError;
    _operations
      ..clear()
      ..addAll(next);
    await _localStore.saveOperations(_operations);
    notifyListeners();
    return null;
  }

  Future<String?> replaceOperationsFromCsv(String raw) async {
    try {
      final parsed = _csvBackup.decode(raw);
      _operations
        ..clear()
        ..addAll(parsed);
      await _localStore.saveOperations(_operations);
      notifyListeners();
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on StateError catch (error) {
      return error.message;
    }
  }
}
