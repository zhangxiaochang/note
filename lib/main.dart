import 'package:flutter/material.dart';
import 'ui/home_page.dart';
import 'dart:io';   // 因为用了 Platform.isMacOS
import 'package:flutter/services.dart';   // ← 就是这一行！！
void main() {
  runApp(const App());
}
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebDAV Notepad',
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
    );
  }
}