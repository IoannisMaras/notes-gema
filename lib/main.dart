import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FlutterGemma.initialize(webStorageMode: WebStorageMode.streaming);
  } catch (e) {
    debugPrint('[SYSTEM] FlutterGemma.initialize failed: $e');
  }
  runApp(const MyApp());
}
