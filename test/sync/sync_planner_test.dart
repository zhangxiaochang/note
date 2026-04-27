import 'package:flutter_test/flutter_test.dart';
import 'package:project/domain/note.dart';
import 'package:project/sync/models/remote_note_info.dart';
import 'package:project/sync/utils/sync_planner.dart';

void main() {
  group('plannedSyncOperationCount', () {
    test('counts new local note without remote', () {
      final local = [
        Note(
          uuid: 'a',
          title: 't',
          content: 'c',
          deltaContent: Note.emptyDelta,
          createdAt: 1,
          updatedAt: 2,
        ),
      ];
      final remote = <String, RemoteNoteInfo>{};
      expect(plannedSyncOperationCount(local, remote), 1);
    });

    test('includes remote-only as one op', () {
      final local = <Note>[];
      final remote = {
        'x': const RemoteNoteInfo(uuid: 'x', path: 'p', mTime: 0),
      };
      expect(plannedSyncOperationCount(local, remote), 1);
    });
  });
}
