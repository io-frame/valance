import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

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
    final groups = store.operationGroups;
    final children = <Widget>[];
    DateTime? currentDate;
    for (final group in groups) {
      final source = group.source;
      if (currentDate == null || !_sameDay(currentDate, source.occurredAt)) {
        currentDate = source.occurredAt;
        children.add(_DateGroupHeader(date: currentDate));
      }
      children.add(_OperationTile(store: store, group: group));
    }
    return ScreenScaffold(
      title: 'Операции',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () => _showOperationSheet(context, store),
            icon: const Icon(Icons.add),
            label: const Text('Добавить'),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Импорт и экспорт',
            onSelected: (value) async {
              if (value == 'export') {
                await _shareCsv(store);
              } else if (value == 'import') {
                await _showImportSheet(context, store);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('Экспорт CSV')),
              PopupMenuItem(value: 'import', child: Text('Импорт CSV')),
            ],
          ),
        ],
      ),
      children: [
        if (groups.isEmpty)
          _EmptyHistoryCard(onAdd: () => _showOperationSheet(context, store))
        else
          ...children,
      ],
    );
  }
}

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        appDate(date),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Colors.black.withValues(alpha: 0.62),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.store, required this.group});

  final ValanceStore store;
  final WalletOperationGroup group;

  @override
  Widget build(BuildContext context) {
    final operation = group.netOperation;
    final source = group.source;
    final warning = FxEngine.operationRateWarning(
      operation: operation,
      rates: store.rates,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      _showOperationSheet(context, store, existing: source),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_historyMoney(operation.fromAmount, operation.fromCurrency)} → '
                          '${_historyMoney(operation.toAmount, operation.toCurrency)}',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'операция от ${appDate(source.occurredAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.black.withValues(alpha: 0.56),
                                  ),
                            ),
                            if (group.hasAdjustments)
                              Text(
                                'нетто после корректировок',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.black.withValues(alpha: 0.56),
                                    ),
                              ),
                            if (warning != null) _AnomalyBadge(warning: warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Действия с операцией',
                onSelected: (value) {
                  if (value == 'edit') {
                    _showOperationSheet(context, store, existing: source);
                  } else if (value == 'adjust') {
                    _showAdjustmentSheet(context, store, source: source);
                  } else if (value == 'delete') {
                    _confirmDelete(context, store, source);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  PopupMenuItem(value: 'adjust', child: Text('Уменьшить')),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Курс операции'),
              children: [
                _RateDetails(operation: operation, warning: warning, store: store),
                if (group.hasAdjustments) ...[
                  _DetailRow(
                    label: 'Исходно',
                    value:
                        '${_historyMoney(source.fromAmount, source.fromCurrency)} → '
                        '${_historyMoney(source.toAmount, source.toCurrency)}',
                  ),
                  _AdjustmentList(
                    store: store,
                    source: source,
                    adjustments: group.adjustments,
                  ),
                ],
                if (source.comment.trim().isNotEmpty)
                  _DetailRow(label: 'Комментарий', value: source.comment),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentList extends StatelessWidget {
  const _AdjustmentList({
    required this.store,
    required this.source,
    required this.adjustments,
  });

  final ValanceStore store;
  final WalletOperation source;
  final List<WalletOperation> adjustments;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final adjustment in adjustments)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Убрано ${_historyMoney(adjustment.fromAmount, adjustment.fromCurrency)} '
                    '(${_historyMoney(adjustment.toAmount, adjustment.toCurrency)})',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Редактировать корректировку',
                  onPressed: () => _showAdjustmentSheet(
                    context,
                    store,
                    source: source,
                    adjustment: adjustment,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Удалить корректировку',
                  onPressed: () =>
                      _confirmDeleteAdjustment(context, store, adjustment),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AnomalyBadge extends StatelessWidget {
  const _AnomalyBadge({required this.warning});

  final OperationRateWarning warning;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: warning.deviationPct >= 1000
            ? const Color(0xFFFFE9E5)
            : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          warning.deviationPct >= 1000
              ? 'Критическое отклонение'
              : 'Нерыночный курс',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: warning.deviationPct >= 1000
                ? const Color(0xFFB3261E)
                : const Color(0xFF8A4B00),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Операций пока нет',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Добавьте первую покупку валюты, обмен или начальный остаток.'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Добавить операцию'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showOperationSheet(
  BuildContext context,
  ValanceStore store, {
  WalletOperation? existing,
}) async {
  final fromAmount = TextEditingController(
    text: existing == null ? '' : _inputNumber(existing.fromAmount),
  );
  final toAmount = TextEditingController(
    text: existing == null ? '' : _inputNumber(existing.toAmount),
  );
  final comment = TextEditingController(text: existing?.comment ?? '');
  var date = existing?.occurredAt ?? DateTime.now();
  var fromCurrency = existing?.fromCurrency ?? Currency.rub;
  var toCurrency = existing?.toCurrency ?? Currency.usd;
  String? error;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          WalletOperation draftOperation() {
            return WalletOperation(
              id: existing?.id,
              occurredAt: date,
              fromCurrency: fromCurrency,
              fromAmount: parseLocalizedNumber(fromAmount.text) ?? 0,
              toCurrency: toCurrency,
              toAmount: parseLocalizedNumber(toAmount.text) ?? 0,
              comment: comment.text.trim(),
            );
          }

          final draft = draftOperation();
          final canSave = FxEngine.validateOperation(draft) == null;
          final previewWarning = canSave
              ? FxEngine.operationRateWarning(
                  operation: draft,
                  rates: store.rates,
                )
              : null;
          final canAdjustSource = existing != null && !existing.isAdjustment;
          final hasUnsavedChanges = existing == null
              ? false
              : canAdjustSource && !_sameOperationInput(existing, draft);

          Future<void> save() async {
            final operation = draftOperation();
            final validation = FxEngine.validateOperation(operation);
            if (validation != null) {
              setState(() => error = validation);
              return;
            }
            final rateWarning = FxEngine.operationRateWarning(
              operation: operation,
              rates: store.rates,
            );
            if (rateWarning != null) {
              final confirmed = await _confirmAnomalousRate(
                context,
                rateWarning,
              );
              if (confirmed != true) return;
            }
            final result = await store.upsertOperation(operation);
            if (result == null && context.mounted) {
              Navigator.of(context).pop();
            } else {
              setState(() => error = result);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SectionTitle(
                          existing == null
                              ? 'Новая операция'
                              : 'Редактировать операцию',
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 1),
                                ),
                              );
                              if (picked != null) {
                                setState(() => date = picked);
                              }
                            },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Дата операции',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(appDate(date)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CurrencyAmountRow(
                          label: 'Списано',
                          currency: fromCurrency,
                          controller: fromAmount,
                          amountLabel: 'Сколько списано',
                          onAmountChanged: () => setState(() {}),
                          onCurrencyChanged: (value) {
                            if (value == null) return;
                            setState(() => fromCurrency = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _CurrencyAmountRow(
                          label: 'Зачислено',
                          currency: toCurrency,
                          controller: toAmount,
                          amountLabel: 'Сколько зачислено',
                          onAmountChanged: () => setState(() {}),
                          onCurrencyChanged: (value) {
                            if (value == null) return;
                            setState(() => toCurrency = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: comment,
                          decoration: const InputDecoration(
                            labelText: 'Комментарий',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (canSave) ...[
                          const SizedBox(height: 10),
                          _OperationPreview(
                            operation: draft,
                            warning: previewWarning,
                          ),
                        ],
                        if (canAdjustSource) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: hasUnsavedChanges
                                  ? null
                                  : () async {
                                      await _showAdjustmentSheet(
                                        context,
                                        store,
                                        source: existing!,
                                      );
                                      if (context.mounted) setState(() {});
                                    },
                              icon: const Icon(Icons.remove_circle_outline),
                              label: Text(
                                hasUnsavedChanges
                                    ? 'Сначала сохраните изменения'
                                    : 'Уменьшить пропорционально',
                              ),
                            ),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          _WarningStrip(text: error!),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canSave ? save : null,
                            child: const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
        },
      );
    },
  );
  fromAmount.dispose();
  toAmount.dispose();
  comment.dispose();
}

Future<void> _showAdjustmentSheet(
  BuildContext context,
  ValanceStore store, {
  required WalletOperation source,
  WalletOperation? adjustment,
}) async {
  final amount = TextEditingController(
    text: adjustment == null ? '' : _inputNumber(adjustment.fromAmount),
  );
  var currency = adjustment?.fromCurrency ?? source.toCurrency;
  String? error;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final removedAmount = parseLocalizedNumber(amount.text) ?? 0;
          WalletOperation? draft;
          WalletOperationGroup? preview;
          String? previewError;
          try {
            final draftAdjustment = FxEngine.buildProportionalAdjustment(
              id: adjustment?.id,
              source: source,
              removedCurrency: currency,
              removedAmount: removedAmount,
              occurredAt: adjustment?.occurredAt ??
                  source.occurredAt.add(const Duration(microseconds: 1)),
            );
            draft = draftAdjustment;
            final previewGroup = FxEngine.groupAfterAdjustment(
              source: source,
              adjustments: store.operations
                  .where((item) => item.adjustmentSourceId == source.id)
                  .toList(growable: false),
              adjustment: draftAdjustment,
            );
            preview = previewGroup;
            if (previewGroup.netFromAmount <= FxEngine.tolerance ||
                previewGroup.netToAmount <= FxEngine.tolerance) {
              previewError = 'Корректировка полностью убирает операцию.';
            }
          } on StateError catch (stateError) {
            previewError = stateError.message;
          }
          final canSave = draft != null && previewError == null;

          Future<void> save() async {
            final result = await store.upsertProportionalAdjustment(
              adjustmentId: adjustment?.id,
              sourceId: source.id,
              removedCurrency: currency,
              removedAmount: removedAmount,
            );
            if (result == null && context.mounted) {
              Navigator.of(context).pop();
            } else {
              setState(() => error = result);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    adjustment == null
                        ? 'Уменьшить операцию'
                        : 'Редактировать корректировку',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Исходно',
                    value:
                        '${_historyMoney(source.fromAmount, source.fromCurrency)} → '
                        '${_historyMoney(source.toAmount, source.toCurrency)}',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 112,
                        child: DropdownButtonFormField<Currency>(
                          initialValue: currency,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            for (final value in [
                              source.fromCurrency,
                              source.toCurrency,
                            ])
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.code),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => currency = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: amount,
                          inputFormatters: const [
                            LocalizedDecimalInputFormatter(),
                          ],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Сколько убрать',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (draft != null && preview != null) ...[
                    const SizedBox(height: 10),
                    _OperationPreview(
                      operation: draft,
                      warning: null,
                    ),
                    const SizedBox(height: 8),
                    _WarningStrip(
                      text:
                          'Нетто: ${_historyMoney(preview.netFromAmount, source.fromCurrency)} → '
                          '${_historyMoney(preview.netToAmount, source.toCurrency)}',
                    ),
                  ],
                  if (previewError != null) ...[
                    const SizedBox(height: 10),
                    _WarningStrip(text: previewError),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    _WarningStrip(text: error!),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canSave ? save : null,
                      child: const Text('Сохранить корректировку'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  amount.dispose();
}

class _CurrencyAmountRow extends StatelessWidget {
  const _CurrencyAmountRow({
    required this.label,
    required this.currency,
    required this.controller,
    required this.onCurrencyChanged,
    required this.amountLabel,
    required this.onAmountChanged,
  });

  final String label;
  final Currency currency;
  final TextEditingController controller;
  final ValueChanged<Currency?> onCurrencyChanged;
  final String amountLabel;
  final VoidCallback onAmountChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black.withValues(alpha: 0.62),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 112,
              child: DropdownButtonFormField<Currency>(
                initialValue: currency,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: [
                  for (final value in Currency.values)
                    DropdownMenuItem(value: value, child: Text(value.code)),
                ],
                onChanged: onCurrencyChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                inputFormatters: const [LocalizedDecimalInputFormatter()],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onAmountChanged(),
                decoration: InputDecoration(
                  hintText: amountLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<bool?> _confirmAnomalousRate(
  BuildContext context,
  OperationRateWarning warning,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Проверить курс?'),
      content: Text(
        'Курс ${_warningDirection(warning)}. Это точно не ошибка?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Вернуться'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  ValanceStore store,
  WalletOperation operation,
) async {
  final deleteTargets = _deleteTargets(store, operation);
  final deleteIds = deleteTargets.map((item) => item.id).toSet();
  final before = _portfolioResultRub(
    operations: store.operations,
    wallet: store.wallet,
  );
  final nextOperations = store.operations
      .where((item) => !deleteIds.contains(item.id))
      .toList(growable: false);
  final ledgerError = FxEngine.validateLedger(nextOperations);
  final nextWallet = ledgerError == null
      ? FxEngine.calculateWallet(
          operations: nextOperations,
          rates: store.rates,
          freshness: store.freshness,
        )
      : null;
  final after = nextWallet == null
      ? null
      : _portfolioResultRub(operations: nextOperations, wallet: nextWallet);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Удалить операцию?'),
      content: Text(
        ledgerError == null
            ? '${deleteTargets.length > 1 ? 'Будут удалены операция и корректировки. ' : ''}'
                  'После удаления пересчитается вся история. '
                  'Результат изменится с ${_nullableRub(before)} '
                  'на ${_nullableRub(after)}.'
            : 'После удаления история станет некорректной: $ledgerError',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: ledgerError == null
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    final error = await store.deleteOperation(operation.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Операция удалена'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () => store.restoreOperations(deleteTargets),
          ),
        ),
      );
    }
  }
}

Future<void> _confirmDeleteAdjustment(
  BuildContext context,
  ValanceStore store,
  WalletOperation adjustment,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Удалить корректировку?'),
      content: const Text('После удаления нетто операции пересчитается.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    final error = await store.deleteOperation(adjustment.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Корректировка удалена'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () => store.restoreOperations([adjustment]),
          ),
        ),
      );
    }
  }
}

Future<void> _shareCsv(ValanceStore store) async {
  final csv = store.exportCsv();
  final bytes = Uint8List.fromList(utf8.encode(csv));
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          mimeType: 'text/csv',
          name: 'valance-operations.csv',
        ),
      ],
      fileNameOverrides: const ['valance-operations.csv'],
      subject: 'История операций Valance',
      text: 'История операций Valance',
    ),
  );
}

Future<void> _showImportSheet(BuildContext context, ValanceStore store) async {
  final controller = TextEditingController();
  var replace = false;
  var backupDone = store.operations.isEmpty;
  List<WalletOperation> preview = const [];
  String? error;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void buildPreview() {
            final result = store.previewCsv(controller.text);
            setState(() {
              preview = result.operations;
              error = result.error;
            });
          }

          Future<void> importCsv() async {
            buildPreview();
            if (error != null || preview.isEmpty) return;
            if (!backupDone) {
              setState(
                () => error = 'Перед импортом сделайте backup текущей истории.',
              );
              return;
            }
            final result = await store.importOperations(
              operations: preview,
              replace: replace,
            );
            if (result == null && context.mounted) {
              Navigator.of(context).pop();
            } else {
              setState(() => error = result);
            }
          }

          return FractionallySizedBox(
            heightFactor: 0.9,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Импорт CSV'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: null,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'CSV',
                      ),
                      onChanged: (_) => buildPreview(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Добавить')),
                      ButtonSegment(value: true, label: Text('Заменить')),
                    ],
                    selected: {replace},
                    onSelectionChanged: (value) =>
                        setState(() => replace = value.first),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    preview.isEmpty
                        ? 'Предпросмотр появится после вставки корректного CSV.'
                        : 'Будет импортировано операций: ${preview.length}.',
                  ),
                  if (!backupDone) ...[
                    const SizedBox(height: 8),
                    _WarningStrip(
                      text: 'Перед импортом нужно экспортировать текущую историю.',
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    _WarningStrip(text: error!),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          controller.text = data?.text ?? '';
                          buildPreview();
                        },
                        icon: const Icon(Icons.content_paste),
                        label: const Text('Вставить'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _shareCsv(store);
                          setState(() => backupDone = true);
                        },
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Backup'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: importCsv,
                        child: const Text('Импорт'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  controller.dispose();
}

class _RateDetails extends StatelessWidget {
  const _RateDetails({
    required this.operation,
    required this.warning,
    required this.store,
  });

  final WalletOperation operation;
  final OperationRateWarning? warning;
  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    final lines = FxEngine.actualRateLines(operation);
    final market = store.rates == null
        ? null
        : FxEngine.marketRate(
            baseCurrency: operation.fromCurrency,
            quoteCurrency: operation.toCurrency,
            rates: store.rates!,
          );
    return Column(
      children: [
        if (lines.isNotEmpty)
          _DetailRow(
            label: 'Прямой курс',
            value: _rateText(lines.first),
          ),
        if (lines.length > 1)
          _DetailRow(
            label: 'Обратный курс',
            value: _rateText(lines[1]),
          ),
        if (market != null)
          _DetailRow(
            label: 'Рынок',
            value:
                '1 ${operation.fromCurrency.code} = ${rate(market)} ${operation.toCurrency.code}',
          ),
        if (warning != null)
          _DetailRow(
            label: 'Отклонение',
            value: _warningDirection(warning!),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningStrip extends StatelessWidget {
  const _WarningStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF7A4B00)),
      ),
    );
  }
}

class _OperationPreview extends StatelessWidget {
  const _OperationPreview({required this.operation, required this.warning});

  final WalletOperation operation;
  final OperationRateWarning? warning;

  @override
  Widget build(BuildContext context) {
    final color = warning == null ? Colors.black.withValues(alpha: 0.62) : const Color(0xFF8A4B00);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: warning == null
            ? Colors.black.withValues(alpha: 0.035)
            : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        warning == null
            ? _primaryRateText(operation)
            : '${_primaryRateText(operation)} · ${_warningDirection(warning!)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: warning == null ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
    );
  }
}

String _historyMoney(double value, Currency currency) {
  return moneyWithCode(value, currency.code);
}

String _primaryRateText(WalletOperation operation) {
  final lines = FxEngine.actualRateLines(operation);
  if (lines.isEmpty) return '';
  final line = lines.first;
  return '1 ${line.baseCurrency.code} = '
      '${rate(line.quotePerBase)} ${line.quoteCurrency.code}';
}

String _rateText(OperationRateLine line) {
  return '1 ${line.baseCurrency.code} = '
      '${rate(line.quotePerBase)} ${line.quoteCurrency.code}';
}

String _warningDirection(OperationRateWarning warning) {
  if (warning.marketRate <= 0) return 'нерыночный курс';
  final factor = warning.actualRate / warning.marketRate;
  if (factor >= 2) {
    return 'выше рынка в ${rate(factor)} раз';
  }
  if (factor <= 0.5) {
    return 'ниже рынка на ${unsignedPct((1 - factor) * 100)}';
  }
  return 'отличается от рынка на ${unsignedPct(warning.deviationPct)}';
}

String _inputNumber(double value) {
  var text = value.toStringAsFixed(value.abs() < 0.01 ? 8 : 4);
  while (text.contains('.') && text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return text.replaceAll('.', ',');
}

String _nullableRub(double? value) {
  return value == null ? 'недоступно' : money(value, 'RUB', detailed: true);
}

double? _portfolioResultRub({
  required List<WalletOperation> operations,
  required WalletSnapshot wallet,
}) {
  final current = wallet.totalCurrentRubValue;
  if (current == null) return null;
  return current - FxEngine.netRubSpent(operations);
}

List<WalletOperation> _deleteTargets(
  ValanceStore store,
  WalletOperation operation,
) {
  if (operation.isAdjustment) return [operation];
  return [
    for (final item in store.operations)
      if (item.id == operation.id || item.adjustmentSourceId == operation.id)
        item,
  ];
}

bool _sameOperationInput(WalletOperation a, WalletOperation b) {
  return a.occurredAt == b.occurredAt &&
      a.fromCurrency == b.fromCurrency &&
      (a.fromAmount - b.fromAmount).abs() <= FxEngine.tolerance &&
      a.toCurrency == b.toCurrency &&
      (a.toAmount - b.toAmount).abs() <= FxEngine.tolerance &&
      a.comment == b.comment;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
