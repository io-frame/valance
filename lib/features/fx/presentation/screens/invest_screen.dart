import 'package:flutter/material.dart';

import '../../../../core/formatters.dart';
import '../../application/valance_store.dart';
import '../../domain/fx_engine.dart';
import '../../domain/fx_models.dart';
import '../widgets/app_chrome.dart';

class InvestScreen extends StatefulWidget {
  const InvestScreen({super.key, required this.store});

  final ValanceStore store;

  @override
  State<InvestScreen> createState() => _InvestScreenState();
}

class _InvestScreenState extends State<InvestScreen> {
  final _controller = TextEditingController(text: '100000');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.store.canRecommend) {
      return _NeedRatesScreen(
        title: 'Пополнить',
        store: widget.store,
      );
    }

    final amount = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
    final validAmount = amount > 0;
    final recommendation = validAmount
        ? FxEngine.recommendRubInvestment(
            rubAmount: amount,
            portfolio: widget.store.portfolio,
            rates: widget.store.rates,
            strategy: widget.store.strategy,
          )
        : null;

    return ScreenScaffold(
      title: 'Пополнить',
      children: [
        AppCard(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Сколько RUB вложить',
              suffixText: 'RUB',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (!validAmount)
          const AppCard(child: Text('Введите сумму больше нуля.'))
        else ...[
          _MainRecommendation(
            option: recommendation!.primary,
            rates: widget.store.rates,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Альтернативы'),
                const SizedBox(height: 10),
                _CompactOption(option: recommendation.balanced),
                const Divider(height: 18),
                _CompactOption(option: recommendation.conservative),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Почему так'),
                const SizedBox(height: 8),
                for (final reason in recommendation.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(reason),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MainRecommendation extends StatelessWidget {
  const _MainRecommendation({required this.option, required this.rates});

  final AllocationOption option;
  final BenchmarkRates rates;

  @override
  Widget build(BuildContext context) {
    final eurAmount = option.eurRub / rates.eurRub;
    final usdAmount = option.usdRub / rates.usdRub;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Рекомендация'),
          const SizedBox(height: 10),
          Text(
            '${money(option.eurRub, 'RUB')} в EUR',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text('примерно ${money(eurAmount, 'EUR')}'),
          const SizedBox(height: 12),
          Text(
            '${money(option.usdRub, 'RUB')} в USD',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text('примерно ${money(usdAmount, 'USD')}'),
        ],
      ),
    );
  }
}

class _CompactOption extends StatelessWidget {
  const _CompactOption({required this.option});

  final AllocationOption option;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            option.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Text('${money(option.eurRub, 'RUB')} / ${money(option.usdRub, 'RUB')}'),
      ],
    );
  }
}

class _NeedRatesScreen extends StatelessWidget {
  const _NeedRatesScreen({required this.title, required this.store});

  final String title;
  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: title,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Нужны курсы'),
              const SizedBox(height: 8),
              Text(store.ratesError ?? 'Курсы ещё не загружены.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: store.refreshRates,
                icon: const Icon(Icons.refresh),
                label: const Text('Загрузить'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
