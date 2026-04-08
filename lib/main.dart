import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize(webStorageMode: WebStorageMode.streaming);
  runApp(const MyApp());
}
