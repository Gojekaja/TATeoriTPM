import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'config/theme_config.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  try {
    // Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Hive and clear any corrupted data
    await Hive.initFlutter();

    // Initialize services
    final dbService = DatabaseService();
    await dbService.init();

    final authService = AuthService();
    await authService.init();

    runApp(const MyApp());
  } catch (e, stackTrace) {
    debugPrint('Initialization error: $e');
    debugPrint('Stack trace: $stackTrace');

    // Show error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: ThemeConfig.backgroundColor,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to initialize app',
                    style: ThemeConfig.headingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    style: ThemeConfig.bodyStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Who Wants to Be a Millionaire?',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.blue[300]!,
          secondary: Colors.blue[200]!,
          surface: Colors.grey[900]!,
          surfaceContainerHighest: const Color(0xFF121212),
          error: Colors.red[300]!,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: TextTheme(
          displayLarge: ThemeConfig.headingStyle.copyWith(
            color: Colors.blue[300],
          ),
          bodyLarge: ThemeConfig.bodyStyle.copyWith(color: Colors.white),
          bodyMedium: ThemeConfig.bodyStyle.copyWith(color: Colors.white70),
          bodySmall: ThemeConfig.subtitleStyle.copyWith(color: Colors.white54),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.blue[300]),
        ),
        cardTheme: CardThemeData(color: Colors.grey[850], elevation: 4),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.blue[300],
          textTheme: ButtonTextTheme.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[300],
            foregroundColor: Colors.white,
          ),
        ),
      ),
      routerConfig: AppRouter.router,
    );
  }
}
