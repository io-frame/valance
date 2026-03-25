import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/fx/application/valance_store.dart';
import 'features/fx/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installDebugKeyboardAssertionFilter();
  await initializeDateFormatting('ru');
  final store = ValanceStore();
  await store.load();
  runApp(ValanceApp(store: store));
  if (!store.freshness.canValueInRub || !store.freshness.canShowEurUsd) {
    unawaited(store.refreshRates());
  }
}

void _installDebugKeyboardAssertionFilter() {
  if (!kDebugMode) return;
  final defaultHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    final isDuplicateKeyDownAssertion =
        text.contains('A KeyDownEvent is dispatched') &&
        text.contains('physical key is already pressed');
    if (isDuplicateKeyDownAssertion) return;
    (defaultHandler ?? FlutterError.presentError)(details);
  };
}

class ValanceApp extends StatelessWidget {
  const ValanceApp({super.key, required this.store});

  final ValanceStore store;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF176B5B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Valance',
      locale: const Locale('ru'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7F3),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.24)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: seed, width: 1.4),
          ),
        ),
      ),
      home: HomeShell(store: store),
    );
  }
}
