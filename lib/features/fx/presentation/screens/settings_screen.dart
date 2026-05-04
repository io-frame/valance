import 'package:flutter/material.dart';

import '../../application/valance_store.dart';
import '../../domain/fx_models.dart';
import '../widgets/app_chrome.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final ValanceStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _usdController;
  late final TextEditingController _eurController;

  @override
  void initState() {
    super.initState();
    _usdController = TextEditingController(
      text: widget.store.initialPortfolio.usd.toStringAsFixed(0),
    );
    _eurController = TextEditingController(
      text: widget.store.initialPortfolio.eur.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _usdController.dispose();
    _eurController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Настройки',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Целевая доля EUR'),
              const SizedBox(height: 12),
              SegmentedButton<StrategyProfile>(
                segments: [
                  for (final strategy in StrategyProfile.values)
                    ButtonSegment(
                      value: strategy,
                      label: Text(
                        '${(strategy.targetEurShare * 100).round()}%',
                      ),
                    ),
                ],
                selected: {widget.store.strategy},
                onSelectionChanged: (value) {
                  widget.store.setStrategy(value.first);
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Используется только для расчёта следующих пополнений. Сейчас: USD ${(widget.store.strategy.targetUsdShare * 100).round()}% / EUR ${(widget.store.strategy.targetEurShare * 100).round()}%.',
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Начальные балансы'),
              const SizedBox(height: 12),
              TextField(
                controller: _usdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'USD',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _eurController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'EUR',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final usd =
                        double.tryParse(_usdController.text.replaceAll(',', '.'));
                    final eur =
                        double.tryParse(_eurController.text.replaceAll(',', '.'));
                    if (usd == null || eur == null) return;
                    widget.store.setInitialPortfolio(usd: usd, eur: eur);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Балансы обновлены')),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Курсы'),
              SizedBox(height: 8),
              Text(
                'EUR/USD загружается из ECB. USD/RUB и EUR/RUB — из ЦБ РФ. Если обновление не прошло, рекомендации скрываются или используют последний успешный курс как устаревший.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
