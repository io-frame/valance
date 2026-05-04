import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'features/fx/application/valance_store.dart';
import 'features/fx/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  final store = ValanceStore();
  runApp(ValanceApp(store: store));
  store.refreshRates();
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
      ),
      home: HomeShell(store: store),
    );
  }
}
