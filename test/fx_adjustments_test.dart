import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valance/features/fx/application/valance_store.dart';
import 'package:valance/features/fx/domain/fx_engine.dart';
import 'package:valance/features/fx/domain/fx_models.dart';

void main() {
  WalletOperation sourceOperation() {
    return WalletOperation(
      id: 'source',
      occurredAt: DateTime(2026, 1, 1),
      fromCurrency: Currency.rub,
      fromAmount: 200,
      toCurrency: Currency.usd,
      toAmount: 100,
    );
  }

  test('builds inverse correction when removing received currency', () {
    final source = sourceOperation();
    final adjustment = FxEngine.buildProportionalAdjustment(
      id: 'adjustment',
      source: source,
      removedCurrency: Currency.usd,
      removedAmount: 20,
      occurredAt: source.occurredAt.add(const Duration(microseconds: 1)),
    );

    expect(adjustment.fromCurrency, Currency.usd);
    expect(adjustment.fromAmount, 20);
    expect(adjustment.toCurrency, Currency.rub);
    expect(adjustment.toAmount, 40);
    expect(adjustment.adjustmentSourceId, source.id);

    final group = FxEngine.groupOperations([source, adjustment]).single;
    expect(group.netFromAmount, 160);
    expect(group.netToAmount, 80);
    expect(FxEngine.validateLedger([source, adjustment]), isNull);
  });

  test('builds equivalent correction when removing spent currency', () {
    final source = sourceOperation();
    final adjustment = FxEngine.buildProportionalAdjustment(
      id: 'adjustment',
      source: source,
      removedCurrency: Currency.rub,
      removedAmount: 40,
      occurredAt: source.occurredAt.add(const Duration(microseconds: 1)),
    );

    final group = FxEngine.groupOperations([source, adjustment]).single;
    expect(adjustment.fromAmount, 20);
    expect(adjustment.toAmount, 40);
    expect(group.netFromAmount, 160);
    expect(group.netToAmount, 80);
  });

  test('rejects corrections that remove the whole source operation', () {
    final source = sourceOperation();
    final adjustment = FxEngine.buildProportionalAdjustment(
      id: 'adjustment',
      source: source,
      removedCurrency: Currency.usd,
      removedAmount: 100,
      occurredAt: source.occurredAt.add(const Duration(microseconds: 1)),
    );

    expect(
      FxEngine.validateLedger([source, adjustment]),
      'Корректировки полностью убирают операцию.',
    );
  });

  test('rejects corrections dated before their source operation', () {
    final initial = WalletOperation(
      id: 'initial',
      occurredAt: DateTime(2026, 1, 1),
      fromCurrency: Currency.rub,
      fromAmount: 1000,
      toCurrency: Currency.usd,
      toAmount: 1000,
    );
    final source = WalletOperation(
      id: 'source',
      occurredAt: DateTime(2026, 1, 3),
      fromCurrency: Currency.usd,
      fromAmount: 100,
      toCurrency: Currency.rub,
      toAmount: 200,
    );
    final adjustment = FxEngine.buildProportionalAdjustment(
      id: 'adjustment',
      source: source,
      removedCurrency: Currency.rub,
      removedAmount: 20,
      occurredAt: DateTime(2026, 1, 2),
    );

    expect(
      FxEngine.validateLedger([initial, source, adjustment]),
      'Корректировка должна идти после исходной операции.',
    );
  });

  test('copyWith can clear adjustment source id', () {
    final adjustment = sourceOperation().copyWith(
      adjustmentSourceId: 'source',
    );

    expect(adjustment.isAdjustment, isTrue);
    expect(adjustment.copyWith(adjustmentSourceId: null).isAdjustment, isFalse);
  });

  test('parses old csv without adjustment column', () {
    final operations = FxEngine.parseOperationsCsv(
      'id,date,from_currency,from_amount,to_currency,to_amount,comment\n'
      'source,2026-01-01,RUB,200,USD,100,\n',
    );

    expect(operations.single.adjustmentSourceId, isNull);
  });

  test('append import remaps correction source id when source id changes', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ValanceStore();
    await store.load();

    final existingSource = sourceOperation();
    expect(
      await store.importOperations(operations: [existingSource], replace: true),
      isNull,
    );

    final importedSource = sourceOperation();
    final importedAdjustment = FxEngine.buildProportionalAdjustment(
      id: 'imported-adjustment',
      source: importedSource,
      removedCurrency: Currency.usd,
      removedAmount: 20,
      occurredAt: importedSource.occurredAt.add(
        const Duration(microseconds: 1),
      ),
    );
    expect(
      await store.importOperations(
        operations: [importedSource, importedAdjustment],
        replace: false,
      ),
      isNull,
    );

    final savedAdjustment = store.operations.firstWhere(
      (operation) => operation.id == 'imported-adjustment',
    );
    expect(savedAdjustment.adjustmentSourceId, isNot(existingSource.id));
    expect(
      store.operations.any(
        (operation) => operation.id == savedAdjustment.adjustmentSourceId,
      ),
      isTrue,
    );
  });
}
