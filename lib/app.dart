import 'package:flutter/material.dart';
import 'screens/boot_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A0B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
          primary: Colors.cyanAccent,
          surface: const Color(0xFF121214),
          outline: Colors.white24,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Color(0xFFE1E1E6),
            fontFamily: 'Courier',
            fontSize: 16,
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFFC4C4CC),
            fontFamily: 'Courier',
            fontSize: 14,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.cyanAccent,
            fontFamily: 'Courier',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const BootScreen(),
    );
  }
}
