import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../application/valance_store.dart';
import '../../domain/fx_models.dart';
import '../widgets/app_chrome.dart';

class EurUsdScreen extends StatefulWidget {
  const EurUsdScreen({super.key, required this.store});

  final ValanceStore store;

  @override
  State<EurUsdScreen> createState() => _EurUsdScreenState();
}

class _EurUsdScreenState extends State<EurUsdScreen> {
  int _years = 5;

  @override
  Widget build(BuildContext context) {
    final rates = widget.store.rates;
    final freshness = widget.store.freshness;
    final range = rates?.ranges[_years];
    return ScreenScaffold(
      title: 'EUR/USD',
      action: IconButton(
        onPressed: widget.store.isRatesLoading
            ? null
            : widget.store.refreshRates,
        tooltip: 'Обновить курсы',
        icon: widget.store.isRatesLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      ),
      children: [
        if (rates?.eurUsd != null)
          _CurrentRateCard(rateValue: rates!.eurUsd!)
        else
          const _WarningCard(text: 'Текущий EUR/USD недоступен.'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 год')),
            ButtonSegment(value: 5, label: Text('5 лет')),
            ButtonSegment(value: 10, label: Text('10 лет')),
          ],
          selected: {_years},
          onSelectionChanged: (value) => setState(() => _years = value.first),
        ),
        if (!freshness.canShowEurUsd || range == null || rates?.eurUsd == null)
          _WarningCard(text: widget.store.ratesError ?? freshness.ecb.label)
        else ...[
          _RangeCard(
            range: range,
            current: rates!.eurUsd!,
            sourceLabel: freshness.ecb.label,
          ),
        ],
      ],
    );
  }
}

class _CurrentRateCard extends StatelessWidget {
  const _CurrentRateCard({required this.rateValue});

  final double rateValue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rate(rateValue),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'USD за 1 EUR',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({
    required this.range,
    required this.current,
    required this.sourceLabel,
  });

  final EurUsdRangeStats range;
  final double current;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final state = _marketState(current, range);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Диапазон за ${_periodLabel(range.years)} · $sourceLabel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _BulletChartPainter(range: range, current: current),
              child: const SizedBox.expand(),
            ),
          ),
          Text(
            'Дневные курсы ECB, без прогноза.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black.withValues(alpha: 0.62),
            ),
          ),
        ],
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

class _BulletChartPainter extends CustomPainter {
  _BulletChartPainter({required this.range, required this.current});

  final EurUsdRangeStats range;
  final double current;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 8.0;
    final left = padding;
    final right = size.width - padding;
    final trackTop = size.height * 0.34;
    const trackHeight = 18.0;
    final rawMin = current < range.p10 ? current : range.p10;
    final rawMax = current > range.p90 ? current : range.p90;
    final rawSpan = rawMax - rawMin;
    final padValue = rawSpan <= 0 ? 0.01 : rawSpan * 0.08;
    final minValue = rawMin - padValue;
    final maxValue = rawMax + padValue;
    final span = maxValue - minValue;

    double x(double value) {
      if (span <= 0) return left;
      return left +
          ((value - minValue) / span).clamp(0.0, 1.0) * (right - left);
    }

    final trackCenter = trackTop + trackHeight / 2;
    final rareBand = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        x(range.p10),
        trackTop,
        x(range.p90),
        trackTop + trackHeight,
      ),
      const Radius.circular(2),
    );
    final usualBand = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        x(range.p25),
        trackTop,
        x(range.p75),
        trackTop + trackHeight,
      ),
      const Radius.circular(2),
    );
    final rarePaint = Paint()..color = const Color(0xFFE3E6DF);
    final usualPaint = Paint()..color = const Color(0xFF9FB9AD);
    final isOutOfRange = current < range.p10 || current > range.p90;
    final currentColor = isOutOfRange
        ? const Color(0xFFB3261E)
        : const Color(0xFF254B8F);

    canvas.drawRRect(rareBand, rarePaint);
    canvas.drawRRect(usualBand, usualPaint);

    _paintMarker(canvas, x(range.p10), trackCenter);
    _paintMarker(canvas, x(range.p25), trackCenter);
    _paintMarker(canvas, x(range.p50), trackCenter, emphasized: true);
    _paintMarker(canvas, x(range.p75), trackCenter);
    _paintMarker(canvas, x(range.p90), trackCenter);
    _paintCurrentMarker(
      canvas,
      x(current),
      trackTop - 32,
      color: currentColor,
    );
    _paintCurrentLabel(
      canvas,
      text: rate(current),
      x: x(current),
      y: 0,
      color: currentColor,
      left: left,
      right: right,
    );
    _paintTickLabel(
      canvas,
      label: 'p10',
      value: rate(range.p10),
      x: x(range.p10),
      y: trackTop + trackHeight + 14,
      left: left,
      right: right,
    );
    _paintTickLabel(
      canvas,
      label: 'p25',
      value: rate(range.p25),
      x: x(range.p25),
      y: trackTop + trackHeight + 14,
      left: left,
      right: right,
    );
    _paintTickLabel(
      canvas,
      label: 'p50',
      value: rate(range.p50),
      x: x(range.p50),
      y: trackTop + trackHeight + 14,
      left: left,
      right: right,
      emphasized: true,
    );
    _paintTickLabel(
      canvas,
      label: 'p75',
      value: rate(range.p75),
      x: x(range.p75),
      y: trackTop + trackHeight + 14,
      left: left,
      right: right,
    );
    _paintTickLabel(
      canvas,
      label: 'p90',
      value: rate(range.p90),
      x: x(range.p90),
      y: trackTop + trackHeight + 14,
      left: left,
      right: right,
    );
  }

  @override
  bool shouldRepaint(covariant _BulletChartPainter oldDelegate) {
    return oldDelegate.range != range || oldDelegate.current != current;
  }

  void _paintMarker(
    Canvas canvas,
    double x,
    double y, {
    bool emphasized = false,
  }) {
    final fillPaint = Paint()..color = const Color(0xFFFAFBF8);
    final strokePaint = Paint()
      ..color = emphasized
          ? Colors.black.withValues(alpha: 0.82)
          : const Color(0xFF63776F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = emphasized ? 4 : 3;
    canvas.drawCircle(Offset(x, y), emphasized ? 11 : 9, fillPaint);
    canvas.drawCircle(Offset(x, y), emphasized ? 11 : 9, strokePaint);
  }

  void _paintCurrentMarker(
    Canvas canvas,
    double x,
    double y, {
    required Color color,
  }) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(x, y + 26)
      ..lineTo(x - 13, y)
      ..lineTo(x + 13, y)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintCurrentLabel(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required Color color,
    required double left,
    required double right,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = (x - painter.width / 2)
        .clamp(left, right - painter.width)
        .toDouble();
    painter.paint(canvas, Offset(dx, y));
  }

  void _paintTickLabel(
    Canvas canvas, {
    required String label,
    required String value,
    required double x,
    required double y,
    required double left,
    required double right,
    bool emphasized = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label\n',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.52),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.70),
              fontSize: 11,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final dx = (x - painter.width / 2)
        .clamp(left, right - painter.width)
        .toDouble();
    painter.paint(canvas, Offset(dx, y));
  }
}

String _periodLabel(int years) {
  return switch (years) {
    1 => '1 год',
    5 => '5 лет',
    10 => '10 лет',
    _ => '$years лет',
  };
}

({String title}) _marketState(double current, EurUsdRangeStats range) {
  if (current < range.p10) {
    return (title: 'EUR/USD ниже обычного диапазона');
  }
  if (current < range.p25) {
    return (title: 'EUR/USD ниже середины диапазона');
  }
  if (current > range.p90) {
    return (title: 'EUR/USD выше обычного диапазона');
  }
  if (current > range.p75) {
    return (title: 'EUR/USD выше середины диапазона');
  }
  return (title: 'EUR/USD около обычного уровня');
}
