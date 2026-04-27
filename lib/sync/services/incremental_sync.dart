import 'package:flutter/material.dart';

import '../models/sync_progress.dart';
import '../models/sync_state.dart';
import 'synchronizer.dart';
import 'sync_client_base.dart';

export 'synchronizer.dart' show Synchronizer, SyncUserCancelled;

/// 与 [Synchronizer] 等价；保留类名以兼容旧调用，新逻辑请用 [Synchronizer]。
class IncrementalSync {
  IncrementalSync(
    SyncClientBase client, {
    SyncProgressController? progress,
    bool Function()? isCancelled,
  }) : _s = Synchronizer(
          client,
          progress: progress,
          isCancelled: isCancelled,
        );

  final Synchronizer _s;

  void setContext(BuildContext context) => _s.setContext(context);

  Future<SyncResult> sync() => _s.run();
}
