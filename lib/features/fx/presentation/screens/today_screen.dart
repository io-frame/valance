import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../application/valance_store.dart';
import '../../domain/fx_engine.dart';
import '../../domain/fx_models.dart';
import '../widgets/app_chrome.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.store});

  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    if (!store.canRecommend) {
      return _NoRatesState(store: store);
    }

    final rates = store.rates;
    final portfolio = store.portfolio;
    final zone = _zoneFor(rates);
    final recommendation = FxEngine.recommendRubInvestment(
      rubAmount: 100000,
      portfolio: portfolio,
      rates: rates,
      strategy: store.strategy,
    );
    final eurShare = recommendation.primary.eurRub / 1000;
    final usdShare = recommendation.primary.usdRub / 1000;

    return ScreenScaffold(
      title: 'Сегодня',
      action: IconButton(
        onPressed: store.refreshRates,
        icon: const Icon(Icons.refresh),
        tooltip: 'Обновить курсы',
      ),
      children: [
        _DecisionCard(
          zone: zone,
          rates: rates,
          eurShare: eurShare,
          usdShare: usdShare,
        ),
        _RateCard(rates: rates),
        _PortfolioCard(store: store, portfolio: portfolio, rates: rates),
        _ActionCard(
          eurShare: eurShare,
          usdShare: usdShare,
          recommendation: recommendation,
        ),
        _CorridorCard(rates: rates, zone: zone),
        _DataQualityCard(rates: rates),
      ],
    );
  }
}

class _NoRatesState extends StatelessWidget {
  const _NoRatesState({required this.store});

  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Сегодня',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Курсы не загружены'),
              const SizedBox(height: 8),
              if (store.isRatesLoading) ...[
                const Text('Загружаю ECB и ЦБ РФ.'),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ] else ...[
                Text(
                  store.ratesStale
                      ? 'Последнее обновление не прошло. Чтобы не давать совет по устаревшему ориентиру, рекомендации скрыты.'
                      : store.ratesError ?? 'Live-данных пока нет.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: store.refreshRates,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Что доступно без курсов'),
              SizedBox(height: 8),
              Text(
                'Можно вводить фактические обмены. Оценка качества сделки и рекомендации появятся после загрузки курсов.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.zone,
    required this.rates,
    required this.eurShare,
    required this.usdShare,
  });

  final _Zone zone;
  final BenchmarkRates rates;
  final double eurShare;
  final double usdShare;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zone.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(zone.explanation),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BigMetric(
                  label: 'EUR/USD',
                  value: rate(rates.eurUsd),
                ),
              ),
              Expanded(
                child: _BigMetric(
                  label: 'Новые RUB',
                  value:
                      '${eurShare.round()}% EUR / ${usdShare.round()}% USD',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.rates});

  final BenchmarkRates rates;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionTitle('Динамика')),
              Text(
                'обновлено ${rates.asOf}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black.withValues(alpha: 0.58),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip('1д ${pct(rates.eurUsdDayChangePct)}'),
              _Chip('7д ${pct(rates.eurUsdWeekMedianDeviationPct)}'),
              _Chip('30д ${pct(rates.eurUsdMonthMedianDeviationPct)}'),
              _Chip('1г ${pct(rates.eurUsdYearMedianDeviationPct)}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '1д — к прошлому значению. 7д/30д/1г — отклонение от медианы периода.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black.withValues(alpha: 0.62),
                ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.store,
    required this.portfolio,
    required this.rates,
  });

  final ValanceStore store;
  final PortfolioSnapshot portfolio;
  final BenchmarkRates rates;

  @override
  Widget build(BuildContext context) {
    final hasPortfolio = portfolio.usd > 0 || portfolio.eur > 0;
    final avgUsd = FxEngine.averageRubBuyRate(Currency.usd, store.operations);
    final avgEur = FxEngine.averageRubBuyRate(Currency.eur, store.operations);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Портфель'),
          const SizedBox(height: 8),
          if (!hasPortfolio) ...[
            const Text(
              'Задай USD/EUR в настройках или добавь обмен — тогда рекомендации будут учитывать твой перекос.',
            ),
          ] else ...[
            _ShareBar(
              usdShare: portfolio.usdShare(rates),
              eurShare: portfolio.eurShare(rates),
            ),
            const SizedBox(height: 10),
            MetricRow(label: 'USD', value: money(portfolio.usd, 'USD')),
            MetricRow(label: 'EUR', value: money(portfolio.eur, 'EUR')),
            MetricRow(
              label: 'Цель',
              value:
                  'USD ${(store.strategy.targetUsdShare * 100).round()}% / EUR ${(store.strategy.targetEurShare * 100).round()}%',
            ),
            if (avgUsd != null)
              MetricRow(
                label: 'Средняя покупка USD',
                value: '${rate(avgUsd)} RUB/USD',
              ),
            if (avgEur != null)
              MetricRow(
                label: 'Средняя покупка EUR',
                value: '${rate(avgEur)} RUB/EUR',
              ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.eurShare,
    required this.usdShare,
    required this.recommendation,
  });

  final double eurShare;
  final double usdShare;
  final InvestmentRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Практически'),
          const SizedBox(height: 10),
          _ActionLine(
            icon: Icons.savings,
            title: 'Новые RUB',
            body:
                'Ориентир: ${eurShare.round()}% в EUR, ${usdShare.round()}% в USD. Сумму вводи во вкладке «Вложить».',
          ),
          const SizedBox(height: 12),
          _ActionLine(
            icon: Icons.currency_exchange,
            title: 'Обмен USD/EUR',
            body: 'Сначала выбери направление на вкладке «Обмен». Ребалансировка может быть в обе стороны.',
          ),
          const SizedBox(height: 12),
          for (final reason in recommendation.reasons.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                reason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black.withValues(alpha: 0.62),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CorridorCard extends StatelessWidget {
  const _CorridorCard({required this.rates, required this.zone});

  final BenchmarkRates rates;
  final _Zone zone;

  @override
  Widget build(BuildContext context) {
    final position = ((rates.eurUsd - rates.lower5y) /
            (rates.upper5y - rates.lower5y))
        .clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Коридор EUR/USD'),
          const SizedBox(height: 8),
          Text(zone.corridorText),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF9FDCCB),
                          Color(0xFFE8D67A),
                          Color(0xFFE49A8E),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: position * constraints.maxWidth - 7,
                    top: -4,
                    child: const Icon(Icons.arrow_drop_down, size: 22),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          MetricRow(
            label: '5 лет, обычный диапазон',
            value: '${rate(rates.lower5y)}–${rate(rates.upper5y)}',
          ),
          MetricRow(
            label: '10 лет, широкий фон',
            value: '${rate(rates.lower10y)}–${rate(rates.upper10y)}',
          ),
        ],
      ),
    );
  }
}

class _DataQualityCard extends StatelessWidget {
  const _DataQualityCard({required this.rates});

  final BenchmarkRates rates;

  @override
  Widget build(BuildContext context) {
    final spread = rates.eurUsdSourceSpreadPct;
    final absSpread = spread?.abs();
    final title = absSpread == null
        ? 'Проверка источников недоступна'
        : absSpread < 0.2
            ? 'Источники совпадают'
            : absSpread < 0.7
                ? 'Есть небольшое расхождение'
                : 'Источники расходятся';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: 8),
          if (rates.eurUsdCbrCross != null && spread != null) ...[
            Text(
              'ECB даёт ${rate(rates.eurUsd)}, кросс ЦБ РФ даёт ${rate(rates.eurUsdCbrCross!)}. Разница ${pct(spread)}.',
            ),
          ] else
            const Text('ECB загружен, но сверка через ЦБ РФ недоступна.'),
          const SizedBox(height: 8),
          Text(
            'Это не курс обменника, а публичный ориентир для решений и контроля фактических сделок.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black.withValues(alpha: 0.62),
                ),
          ),
        ],
      ),
    );
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black.withValues(alpha: 0.58),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.usdShare, required this.eurShare});

  final double usdShare;
  final double eurShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: (usdShare * 100).round().clamp(1, 99),
                child: Container(height: 12, color: const Color(0xFF176B5B)),
              ),
              Expanded(
                flex: (eurShare * 100).round().clamp(1, 99),
                child: Container(height: 12, color: const Color(0xFFE0B84F)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('USD ${(usdShare * 100).round()}%')),
            Text('EUR ${(eurShare * 100).round()}%'),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

_Zone _zoneFor(BenchmarkRates rates) {
  if (rates.eurUsd < rates.lower5y) {
    return _Zone(
      title: 'EUR дешевле USD',
      explanation:
          '1 EUR стоит меньше USD, чем обычно за последние 5 лет. Это аргумент в пользу EUR.',
      corridorText:
          'EUR/USD ниже обычного 5-летнего диапазона. EUR относительно USD выглядит дешевле, но фактический обмен всё равно надо проверять по спреду.',
    );
  }
  if (rates.eurUsd > rates.upper5y) {
    return _Zone(
      title: 'EUR дороже USD',
      explanation:
          '1 EUR стоит больше USD, чем обычно за последние 5 лет. Покупку EUR стоит ограничивать.',
      corridorText:
          'EUR/USD выше обычного 5-летнего диапазона. EUR относительно USD дорогой.',
    );
  }
  return _Zone(
    title: 'EUR/USD в обычном диапазоне',
    explanation:
        'Курс внутри 5-летнего диапазона. Главный фактор — перекос твоего портфеля.',
    corridorText: 'EUR/USD находится внутри обычного 5-летнего диапазона.',
  );
}

class _Zone {
  const _Zone({
    required this.title,
    required this.explanation,
    required this.corridorText,
  });

  final String title;
  final String explanation;
  final String corridorText;
}
