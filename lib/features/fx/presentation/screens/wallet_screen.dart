import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../application/valance_store.dart';
import '../../domain/fx_engine.dart';
import '../../domain/fx_models.dart';
import '../widgets/app_chrome.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.store});

  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    final wallet = store.wallet;
    final freshness = store.freshness;
    final activePositions = wallet.positions
        .where((item) => item.amount.abs() > 0.000001)
        .toList();
    final emptyPositions = wallet.positions
        .where((item) => item.amount.abs() <= 0.000001)
        .toList();
    final suspiciousCurrencies = <Currency>{};
    for (final operation in store.operations) {
      final warning = FxEngine.operationRateWarning(
        operation: operation,
        rates: store.rates,
      );
      if (warning != null) {
        if (operation.fromCurrency != Currency.rub) {
          suspiciousCurrencies.add(operation.fromCurrency);
        }
        if (operation.toCurrency != Currency.rub) {
          suspiciousCurrencies.add(operation.toCurrency);
        }
      }
    }

    return ScreenScaffold(
      title: 'Портфель',
      action: IconButton(
        onPressed: store.isRatesLoading ? null : store.refreshRates,
        tooltip: 'Обновить курсы',
        icon: store.isRatesLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      ),
      children: [
        _SummaryCard(wallet: wallet, store: store),
        if (store.loadError != null) _WarningCard(text: store.loadError!),
        if (!freshness.canValueInRub)
          _WarningCard(text: store.ratesError ?? freshness.cbr.label),
        if (activePositions.isEmpty)
          const _EmptyWalletCard()
        else
          _PortfolioStructureCard(
            wallet: wallet,
            rates: store.rates,
            ratesFresh: freshness.canValueInRub,
            suspiciousCurrencies: suspiciousCurrencies,
          ),
        if (activePositions.isEmpty && emptyPositions.isNotEmpty)
          const _NoPositionsHint(),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.wallet, required this.store});

  final WalletSnapshot wallet;
  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    final current = wallet.totalCurrentRubValue;
    final spent = FxEngine.netRubSpent(store.operations);
    final result = current == null ? null : current - spent;
    final hasSuspiciousOperations = store.operations.any(
      (operation) =>
          FxEngine.operationRateWarning(
            operation: operation,
            rates: store.rates,
          ) !=
          null,
    );
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Стоимость валют',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            current == null ? 'нет актуального курса' : money(current, 'RUB'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _InlineMetric(label: 'Списано всего', value: money(spent, 'RUB')),
          if (result != null)
            _InlineMetric(
              label: 'Прибыль/убыток',
              value: _resultText(current!, spent),
              valueColor: hasSuspiciousOperations
                  ? _warningColor
                  : _resultColor(result),
            ),
          const SizedBox(height: 6),
          Tooltip(
            message:
                'ЦБ РФ может публиковать курс на следующий банковский день.',
            child: Text(
              store.isRatesLoading
                  ? 'Обновляю курсы...'
                  : store.freshness.cbr.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black.withValues(alpha: 0.56),
              ),
            ),
          ),
          if (hasSuspiciousOperations) ...[
            const SizedBox(height: 8),
            const _SuspiciousHint(),
          ],
        ],
      ),
    );
  }
}

class _EmptyWalletCard extends StatelessWidget {
  const _EmptyWalletCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Text(
        'Валют пока нет. Добавьте первую покупку или начальный остаток.',
      ),
    );
  }
}

class _PortfolioStructureCard extends StatelessWidget {
  const _PortfolioStructureCard({
    required this.wallet,
    required this.rates,
    required this.ratesFresh,
    required this.suspiciousCurrencies,
  });

  final WalletSnapshot wallet;
  final RatesSnapshot? rates;
  final bool ratesFresh;
  final Set<Currency> suspiciousCurrencies;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final currency in const [Currency.byn, Currency.usd, Currency.eur])
        _PortfolioItem(
          position: wallet.position(currency),
          rateRub: _rateRub(rates, currency),
          color: _portfolioAccentColor,
          hasSuspiciousOperations: suspiciousCurrencies.contains(currency),
        ),
    ];
    final total = items.fold<double>(
      0,
      (sum, item) => sum + (item.position.currentRubValue ?? 0),
    );
    final percentages = [
      for (final item in items)
        total <= 0 || item.position.currentRubValue == null
            ? 0.0
            : item.position.currentRubValue! / total * 100,
    ];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Структура портфеля',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _PercentMarker(
                    percent: percentages[index],
                    color: items[index].color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          _SegmentBar(items: items),
          const SizedBox(height: 20),
          _ThreeColumnGrid(
            divider: _DashedVerticalDivider(
              color: Colors.black.withValues(alpha: 0.10),
            ),
            children: [
              for (final item in items) _PortfolioColumn(item: item),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _ThreeColumnGrid(
              divider: ColoredBox(color: Colors.black.withValues(alpha: 0.08)),
              children: [
                for (final item in items)
                  Text(
                    _ratePillText(
                      item.position.currency,
                      item.rateRub,
                      ratesFresh,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withValues(alpha: 0.64),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (items.any((item) => item.hasSuspiciousOperations))
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: _SuspiciousHint(),
            ),
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.items});

  final List<_PortfolioItem> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: _portfolioAccentColor)),
            _AlignedDividers(
              count: items.length,
              width: 2,
              child: const ColoredBox(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreeColumnGrid extends StatelessWidget {
  const _ThreeColumnGrid({required this.children, required this.divider});

  final List<Widget> children;
  final Widget divider;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final child in children) Expanded(child: Center(child: child)),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: _AlignedDividers(
              count: children.length,
              width: 1,
              verticalInset: 0,
              child: divider,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlignedDividers extends StatelessWidget {
  const _AlignedDividers({
    required this.count,
    required this.width,
    required this.child,
    this.verticalInset = 0,
  });

  final int count;
  final double width;
  final double verticalInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (var index = 1; index < count; index++)
              Positioned(
                left: constraints.maxWidth * index / count - width / 2,
                top: verticalInset,
                bottom: verticalInset,
                width: width,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _PercentMarker extends StatelessWidget {
  const _PercentMarker({required this.percent, required this.color});

  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${percent.round()}%',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        CustomPaint(size: const Size(12, 8), painter: _TrianglePainter(color)),
      ],
    );
  }
}

class _PortfolioColumn extends StatelessWidget {
  const _PortfolioColumn({required this.item});

  final _PortfolioItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _portfolioAmount(item.position),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          item.position.currentRubValue == null
              ? 'нет курса'
              : money(item.position.currentRubValue!, 'RUB'),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(
            color: Colors.black.withValues(alpha: 0.56),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DashedVerticalDivider extends StatelessWidget {
  const _DashedVerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedVerticalDividerPainter(color));
  }
}

class _DashedVerticalDividerPainter extends CustomPainter {
  const _DashedVerticalDividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width;
    var top = 0.0;
    const dash = 7.0;
    const gap = 6.0;
    final x = size.width / 2;
    while (top < size.height) {
      final bottom = top + dash > size.height ? size.height : top + dash;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
      top += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedVerticalDividerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PortfolioItem {
  const _PortfolioItem({
    required this.position,
    required this.rateRub,
    required this.color,
    required this.hasSuspiciousOperations,
  });

  final WalletPosition position;
  final double? rateRub;
  final Color color;
  final bool hasSuspiciousOperations;
}

String _portfolioAmount(WalletPosition position) {
  return '${_amountText(position.amount)} ${_portfolioSymbol(position.currency)}';
}

String _amountText(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() <= 0.000001) {
    return moneyWithCode(rounded, '').trim();
  }
  return money(value, 'RUB', detailed: true).replaceAll(' ₽', '');
}

String _ratePillText(Currency currency, double? rateRub, bool fresh) {
  final symbol = _portfolioSymbol(currency);
  if (!fresh || rateRub == null) return '1 $symbol = нет курса';
  return '1 $symbol = ${rate(rateRub)} ₽';
}

String _portfolioSymbol(Currency currency) {
  return switch (currency) {
    Currency.byn => '₿',
    Currency.usd => r'$',
    Currency.eur => '€',
    Currency.rub => '₽',
  };
}

const _portfolioAccentColor = Color(0xFFD9E2D8);

class _NoPositionsHint extends StatelessWidget {
  const _NoPositionsHint();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(14),
      child: Text('Нет валютных позиций.'),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black.withValues(alpha: 0.62),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuspiciousHint extends StatelessWidget {
  const _SuspiciousHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Есть нерыночные операции',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _warningColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

double? _rateRub(RatesSnapshot? rates, Currency currency) {
  return switch (currency) {
    Currency.byn => rates?.bynRub,
    Currency.usd => rates?.usdRub,
    Currency.eur => rates?.eurRub,
    Currency.rub => 1,
  };
}

String _resultText(double currentRub, double costRub) {
  final roundedCurrent = currentRub.roundToDouble();
  final roundedCost = costRub.roundToDouble();
  final result = roundedCurrent - roundedCost;
  final percent = roundedCost <= 0 ? 0.0 : result / roundedCost * 100;
  return '${money(result, 'RUB')} / ${pct(percent)}';
}

Color _resultColor(double value) {
  if (value > 0) return const Color(0xFF147A4B);
  if (value < 0) return const Color(0xFFB3261E);
  return Colors.black;
}

const _warningColor = Color(0xFF8A4B00);
