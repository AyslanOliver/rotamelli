import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const MyApp());
}

class AppThemeController extends ChangeNotifier {
  Color seed = const Color(0xFF1769AA);
  ThemeMode mode = ThemeMode.light;
  void setSeed(Color c) {
    seed = c;
    notifyListeners();
  }
  void setMode(ThemeMode m) {
    mode = m;
    notifyListeners();
  }
}

final appThemeController = AppThemeController();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final seed = appThemeController.seed;
        return MaterialApp(
          title: 'Rota Mercado Livre',
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F6FA),
            appBarTheme: AppBarTheme(
              backgroundColor: seed,
              foregroundColor: Colors.white,
              centerTitle: true,
              elevation: 0,
            ),
            drawerTheme: const DrawerThemeData(
              backgroundColor: Colors.white,
              elevation: 2,
            ),
            cardTheme: CardThemeData(
              color: seed.withOpacity(0.08),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: seed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: seed,
                side: BorderSide(color: seed),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            listTileTheme: ListTileThemeData(
              iconColor: seed,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0xFFE3E6EF),
              thickness: 1,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: seed,
            brightness: Brightness.dark,
          ),
          themeMode: appThemeController.mode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
          ],
          home: const DashboardScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
