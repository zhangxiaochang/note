import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/setup/storage_bootstrap_gate.dart';
import 'services/theme_provider.dart';
import 'services/database_init.dart';
import 'services/system_ui_config.dart';
import 'sync/services/sync_session_recovery.dart';
import 'widgets/app_scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DatabaseInit.initForPlatform();
  await SyncSessionRecovery.recoverAfterProcessRestart();
  SystemUI.configure();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Benny',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      themeMode: themeProvider.flutterThemeMode,
      theme: themeProvider.theme,
      home: const StorageBootstrapGate(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        quill.FlutterQuillLocalizations.delegate,
      ],
    );
  }
}
