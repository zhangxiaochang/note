import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project/domain/note.dart';
import 'package:project/sync/utils/note_sync_hash.dart';

void main() {
  group('noteSyncContentHash', () {
    test('identical notes produce same hash', () {
      final n = Note(
        uuid: 'u1',
        title: 't',
        content: 'c',
        deltaContent: Note.emptyDelta,
        createdAt: 1,
        updatedAt: 2,
        categoryUuid: 'cat-1',
      );
      expect(noteSyncContentHash(n), noteSyncContentHash(n));
    });

    test('categoryUuid changes hash', () {
      final a = Note(
        uuid: 'u1',
        title: 't',
        content: 'c',
        deltaContent: Note.emptyDelta,
        createdAt: 1,
        updatedAt: 2,
        categoryUuid: 'a',
      );
      final b = a.copyWith(categoryUuid: 'b');
      expect(noteSyncContentHash(a), isNot(noteSyncContentHash(b)));
    });

    test('JSON round-trip preserves hash', () {
      final n = Note(
        uuid: 'u1',
        title: 't',
        content: 'c',
        deltaContent: const [
          {'insert': 'hello'},
        ],
        createdAt: 1,
        updatedAt: 2,
        syncStatus: 'synced',
        categoryUuid: 'cu1',
      );
      final raw = jsonEncode(n.toJsonMap());
      final decoded = Note.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      expect(noteSyncContentHash(n), noteSyncContentHash(decoded));
    });
  });
}
