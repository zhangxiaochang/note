import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'pages/home/home_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';

// 👇 新增：平台判断导入
import 'dart:io' show Platform;

void main() async {
  // 👇 必须加 await 和 WidgetsFlutterBinding
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 仅在非移动端（Windows/macOS/Linux）启用 FFI
  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit(); // 初始化 FFI
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ 移除了这里对 databaseFactory 的设置！
    return MaterialApp(
      title: 'Note',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
    );
  }
}