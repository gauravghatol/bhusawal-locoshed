// hello

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/authentication_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthenticationManager.initializeAuthentication();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color primaryColor = Color(0xFFE43636);
  static const Color backgroundColor = Color(0xFFF6EFD2);
  static const Color tileColor = Color(0xFFE2DDB4);
  static const Color contrastColor = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loco Info',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: primaryColor,
          onPrimary: backgroundColor,
          secondary: tileColor,
          onSecondary: contrastColor,
          error: Colors.red,
          onError: Colors.white,
          surface: tileColor,
          onSurface: contrastColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: backgroundColor,
          iconTheme: IconThemeData(color: backgroundColor),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: contrastColor),
          bodyMedium: TextStyle(color: contrastColor),
        ),
      ),
      builder: (context, child) {
        // Responsive wrapper for all platforms
        return LayoutBuilder(
          builder: (context, constraints) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  constraints.maxWidth < 400 ? 0.95 : 1.0,
                ),
              ),
              child: child!,
            );
          },
        );
      },
      home: const HomePage(),
    );
  }
}

class _HomeTileData {
  final String title;
  final IconData icon;
  const _HomeTileData(this.title, this.icon);
}

class _HomeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  const _HomeTile({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MyApp.tileColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO: Handle tile tap
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: MyApp.primaryColor),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MyApp.contrastColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
