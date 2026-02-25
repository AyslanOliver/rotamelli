import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/sb2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const MyApp());
}

class AppThemeController extends ChangeNotifier {
  Color seed = const Color(0xFF4E73DF);
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
        final lightScheme = const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF4E73DF),
          onPrimary: Colors.white,
          secondary: Color(0xFF858796),
          onSecondary: Colors.white,
          error: Color(0xFFE74A3B),
          onError: Colors.white,
          background: Color(0xFFF8F9FC),
          onBackground: Color(0xFF5A5C69),
          surface: Colors.white,
          onSurface: Color(0xFF5A5C69),
        );
        final sbTheme = ThemeData(
          useMaterial3: true,
          colorScheme: lightScheme,
          brightness: Brightness.light,
          scaffoldBackgroundColor: SB2.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: SB2.surface,
            foregroundColor: SB2.text,
            centerTitle: true,
            elevation: 2,
          ),
          drawerTheme: const DrawerThemeData(
            backgroundColor: SB2.surface,
            elevation: 2,
          ),
          cardTheme: CardThemeData(
            color: SB2.surface,
            elevation: 1,
            shape: const RoundedRectangleBorder(borderRadius: SB2.cardRadius),
          ),
          textTheme: GoogleFonts.nunitoTextTheme(),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: SB2.primary,
              foregroundColor: SB2.surface,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: const RoundedRectangleBorder(borderRadius: SB2.cardRadius),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: SB2.primary,
              side: const BorderSide(color: SB2.primary),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: const RoundedRectangleBorder(borderRadius: SB2.cardRadius),
            ),
          ),
          listTileTheme: const ListTileThemeData(
            iconColor: SB2.primary,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          ),
          dividerTheme: const DividerThemeData(
            color: SB2.divider,
            thickness: 1,
          ),
          splashColor: const Color(0xFFEAECF4),
        );
        return MaterialApp(
          title: 'Rota Mercado Livre',
          theme: sbTheme,
          darkTheme: sbTheme,
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
