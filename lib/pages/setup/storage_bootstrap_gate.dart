import 'package:flutter/material.dart';

import '../../pages/home/home_page.dart';
import '../../utils/storage_location_prefs.dart';
import 'storage_setup_page.dart';

class StorageBootstrapGate extends StatefulWidget {
  const StorageBootstrapGate({super.key});

  @override
  State<StorageBootstrapGate> createState() => _StorageBootstrapGateState();
}

class _StorageBootstrapGateState extends State<StorageBootstrapGate> {
  bool _loading = true;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await StorageLocationPrefs.getStorageRootPath();
    if (!mounted) return;
    setState(() {
      _configured = path != null && path.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_configured) {
      return const HomePage();
    }

    return StorageSetupPage(
      onConfigured: () {
        if (!mounted) return;
        setState(() {
          _configured = true;
        });
      },
    );
  }
}
