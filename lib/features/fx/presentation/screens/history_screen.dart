import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/formatters.dart';
import '../../application/valance_store.dart';
import '../../domain/fx_engine.dart';
import '../../domain/fx_models.dart';
import '../widgets/app_chrome.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store});

  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    final operations = store.operations;

    return ScreenScaffold(
      title: 'История',
      action: FilledButton.icon(
        onPressed: () => _showAddExchange(context),
        icon: const Icon(Icons.add),
        label: const Text('Обмен'),
      ),
      children: [
        if (operations.isEmpty)
          const AppCard(child: Text('Фактических операций пока нет.')),
        for (final operation in operations)
          _OperationCard(operation: operation, store: store),
      ],
    );
  }

  void _showAddExchange(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddExchangeSheet(store: store),
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({required this.operation, required this.store});

  final FxOperation operation;
  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    final analysis = operation.benchmarkRate == null
        ? null
        : FxEngine.analyzeOperation(operation, store.rates);
    final date = DateFormat('d MMM yyyy', 'ru').format(operation.occurredAt);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$date · ${operation.fromCurrency.code} → ${operation.toCurrency.code}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (analysis != null) _QualityPill(analysis.quality.title),
            ],
          ),
          const SizedBox(height: 10),
          MetricRow(
            label: 'Отдал',
            value: money(operation.fromAmount, operation.fromCurrency.code),
          ),
          MetricRow(
            label: 'Получил',
            value: money(operation.toAmount, operation.toCurrency.code),
          ),
          if (operation.routeCurrency != null)
            MetricRow(
              label: 'Через',
              value: operation.routeCurrency!.code,
            ),
          if (analysis != null) ...[
            MetricRow(
              label: 'Фактический ${analysis.rateLabel}',
              value: rate(analysis.actualRate),
            ),
            MetricRow(
              label: 'Отклонение',
              value: pct(analysis.slippagePct),
            ),
            if (operation.benchmarkAsOf != null)
              MetricRow(
                label: 'Ориентир на дату',
                value: operation.benchmarkAsOf!,
              ),
            Text(analysis.summary),
          ] else
            const Text('Оценка появится после загрузки курсов.'),
          if (operation.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(operation.comment),
          ],
        ],
      ),
    );
  }
}

class _QualityPill extends StatelessWidget {
  const _QualityPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text),
      ),
    );
  }
}

class AddExchangeSheet extends StatefulWidget {
  const AddExchangeSheet({super.key, required this.store});

  final ValanceStore store;

  @override
  State<AddExchangeSheet> createState() => _AddExchangeSheetState();
}

class _AddExchangeSheetState extends State<AddExchangeSheet> {
  int _mode = 0;
  bool _routeViaByn = false;
  final _fromController = TextEditingController(text: '100000');
  final _toController = TextEditingController(text: '930');
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencies = _currenciesForMode();
    final operation = _operationOrNull(currencies);
    final analysis = operation == null
        ? null
        : widget.store.canRecommend
            ? FxEngine.analyzeOperation(operation, widget.store.rates)
            : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Добавить обмен',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('RUB→EUR')),
                ButtonSegment(value: 1, label: Text('RUB→USD')),
                ButtonSegment(value: 2, label: Text('USD→EUR')),
                ButtonSegment(value: 3, label: Text('EUR→USD')),
              ],
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() {
                  _mode = value.first;
                  if (_mode == 0) {
                    _fromController.text = '100000';
                    _toController.text = '930';
                  } else if (_mode == 1) {
                    _fromController.text = '100000';
                    _toController.text = '1020';
                  } else if (_mode == 2) {
                    _fromController.text = '1000';
                    _toController.text = '925';
                  } else {
                    _fromController.text = '1000';
                    _toController.text = '1170';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fromController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Отдал',
                suffixText: currencies.$1.code,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _toController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Получил',
                suffixText: currencies.$2.code,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _routeViaByn,
              onChanged: (value) {
                setState(() => _routeViaByn = value ?? false);
              },
              title: const Text('Маршрут через BYN'),
              subtitle: const Text('BYN сохранится только как пометка маршрута'),
            ),
            if (analysis != null) ...[
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Расчет'),
                    const SizedBox(height: 8),
                    MetricRow(
                      label: 'Фактический ${analysis.rateLabel}',
                      value: rate(analysis.actualRate),
                    ),
                    MetricRow(
                      label: 'Ориентир',
                      value: rate(analysis.benchmarkRate),
                    ),
                    MetricRow(
                      label: 'Отклонение',
                      value: pct(analysis.slippagePct),
                    ),
                    const SizedBox(height: 6),
                    Text(analysis.summary),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: operation == null
                    ? null
                    : () {
                        final saved = widget.store.canRecommend
                            ? FxEngine.attachBenchmark(
                                operation,
                                widget.store.rates,
                              )
                            : operation;
                        widget.store.addOperation(saved);
                        Navigator.of(context).pop();
                      },
                child: const Text('Сохранить операцию'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Currency, Currency, Currency?) _currenciesForMode() {
    final route = _routeViaByn ? Currency.byn : null;
    if (_mode == 1) return (Currency.rub, Currency.usd, route);
    if (_mode == 2) return (Currency.usd, Currency.eur, route);
    if (_mode == 3) return (Currency.eur, Currency.usd, route);
    return (Currency.rub, Currency.eur, route);
  }

  FxOperation? _operationOrNull((Currency, Currency, Currency?) currencies) {
    final fromAmount =
        double.tryParse(_fromController.text.replaceAll(',', '.'));
    final toAmount = double.tryParse(_toController.text.replaceAll(',', '.'));
    if (fromAmount == null || toAmount == null) return null;
    if (fromAmount <= 0 || toAmount <= 0) return null;

    return FxOperation(
      occurredAt: DateTime.now(),
      fromCurrency: currencies.$1,
      fromAmount: fromAmount,
      toCurrency: currencies.$2,
      toAmount: toAmount,
      routeCurrency: currencies.$3,
      comment: _commentController.text.trim(),
    );
  }
}
