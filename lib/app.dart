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
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 14,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontFamily: 'Courier',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
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
