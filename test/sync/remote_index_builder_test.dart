import 'package:flutter_test/flutter_test.dart';
import 'package:project/sync/models/remote_file.dart';
import 'package:project/sync/services/remote_index_builder.dart';
import 'package:project/sync/services/sync_client_base.dart';

void main() {
  group('RemoteIndexBuilder', () {
    test('lists notes under benny/notes shards', () async {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
      final t2 = DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true);
      final client = _FakeSyncClient(
        dirs: {
          'benny/notes': [
            RemoteFile(name: 'ab', isDir: true, mTime: t1),
          ],
          'benny/notes/ab': [
            RemoteFile(
              name: 'n1.json',
              isDir: false,
              mTime: t2,
            ),
          ],
          'benny/images': <RemoteFile>[],
        },
        categoryProps: null,
      );

      final index = await RemoteIndexBuilder.build(client);
      expect(index.noteCount, 1);
      expect(index.notesByUuid['n1']?.path, 'benny/notes/ab/n1.json');
      expect(index.imageFileCount, 0);
    });

    test('lists image files under benny/images', () async {
      final mt = DateTime.fromMillisecondsSinceEpoch(500, isUtc: true);
      final client = _FakeSyncClient(
        dirs: {
          'benny/notes': <RemoteFile>[],
          'benny/images': [
            RemoteFile(name: 'a.png', isDir: false, mTime: mt, size: 10),
          ],
        },
        categoryProps: null,
      );

      final index = await RemoteIndexBuilder.build(client);
      expect(index.imageFileCount, 1);
      expect(index.imagesByFileName['a.png']?.path, 'benny/images/a.png');
    });
  });
}

class _FakeSyncClient implements SyncClientBase {
  _FakeSyncClient({
    required this.dirs,
    this.categoryProps,
  });

  final Map<String, List<RemoteFile>> dirs;
  final RemoteFile? categoryProps;

  @override
  Map<String, dynamic> get config => {};

  @override
  Future<String> downloadString(String path) async => '';

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    void Function(int received, int total)? onProgress,
  }) async {}

  @override
  bool get isConfigured => true;

  @override
  Future<void> mkdirAll(String path) async {}

  @override
  Future<bool> isExist(String path) async => false;

  @override
  String get protocolName => 'fake';

  @override
  Future<void> ping() async {}

  @override
  Future<List<RemoteFile>> readDir(String path) async => dirs[path] ?? [];

  @override
  Future<RemoteFile?> readProps(String path) async {
    if (path == 'benny/meta/categories.json') {
      return categoryProps;
    }
    return null;
  }

  @override
  Future<void> remove(String path) async {}

  @override
  Future<List<RemoteFile>> safeReadDir(String path) async => dirs[path] ?? [];

  @override
  Future<void> testFullCapabilities() async {}

  @override
  Future<void> updateConfig(Map<String, dynamic> newConfig) async {}

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    bool replace = true,
    void Function(int sent, int total)? onProgress,
  }) async {}

  @override
  Future<void> uploadString(String content, String path) async {}
}
