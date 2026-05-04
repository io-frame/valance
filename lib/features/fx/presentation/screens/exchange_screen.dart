import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../application/valance_store.dart';
import '../../domain/fx_engine.dart';
import '../../domain/fx_models.dart';
import '../widgets/app_chrome.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key, required this.store});

  final ValanceStore store;

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  Currency _fromCurrency = Currency.usd;
  Currency _toCurrency = Currency.eur;
  final _fromController = TextEditingController(text: '1000');
  final _offeredController = TextEditingController();

  @override
  void dispose() {
    _fromController.dispose();
    _offeredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.store.canRecommend) {
      return ScreenScaffold(
        title: 'Проверить обмен',
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Нужны свежие курсы'),
                const SizedBox(height: 8),
                Text(widget.store.ratesError ?? 'Курсы ещё не загружены.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.store.refreshRates,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Загрузить'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final fromAmount =
        double.tryParse(_fromController.text.replaceAll(',', '.')) ?? 0;
    final offered =
        double.tryParse(_offeredController.text.replaceAll(',', '.'));
    final validAmount = fromAmount > 0;
    final quote = validAmount
        ? FxEngine.quoteExchange(
            fromCurrency: _fromCurrency,
            toCurrency: _toCurrency,
            fromAmount: fromAmount,
            rates: widget.store.rates,
          )
        : null;

    return ScreenScaffold(
      title: 'Проверить обмен',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<Currency>(
                segments: const [
                  ButtonSegment(value: Currency.usd, label: Text('USD → EUR')),
                  ButtonSegment(value: Currency.eur, label: Text('EUR → USD')),
                ],
                selected: {_fromCurrency},
                onSelectionChanged: (value) {
                  setState(() {
                    _fromCurrency = value.first;
                    _toCurrency = _fromCurrency == Currency.usd
                        ? Currency.eur
                        : Currency.usd;
                    _offeredController.clear();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fromController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Отдаю',
                  suffixText: _fromCurrency.code,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _offeredController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Предлагают',
                  suffixText: _toCurrency.code,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        if (!validAmount)
          const AppCard(child: Text('Введите сумму больше нуля.'))
        else ...[
          _VerdictCard(quote: quote!, offered: offered),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Порог'),
                const SizedBox(height: 8),
                MetricRow(
                  label: 'Минимум для согласия',
                  value: money(quote.acceptableReceive, quote.toCurrency.code),
                ),
                MetricRow(
                  label: 'Хорошо',
                  value: 'от ${money(quote.goodReceive, quote.toCurrency.code)}',
                ),
                MetricRow(
                  label: 'Без спреда',
                  value: money(quote.fairReceive, quote.toCurrency.code),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.quote, required this.offered});

  final ExchangeQuote quote;
  final double? offered;

  @override
  Widget build(BuildContext context) {
    final value = offered;
    final title = value == null
        ? 'Сравни с обменником'
        : value >= quote.goodReceive
            ? 'Хороший курс'
            : value >= quote.acceptableReceive
                ? 'Нормально'
                : 'Слишком дорого';
    final body = value == null
        ? 'Соглашаться, если дают от ${money(quote.acceptableReceive, quote.toCurrency.code)}.'
        : value >= quote.acceptableReceive
            ? 'Предложение проходит минимальный порог.'
            : 'Спред съедает смысл обмена.';

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    );
  }
}
