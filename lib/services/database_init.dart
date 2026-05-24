import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 数据库初始化，桌面端启用 sqflite FFI
class DatabaseInit {
  static void initForPlatform() {
    if (Platform.isAndroid || Platform.isIOS) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
