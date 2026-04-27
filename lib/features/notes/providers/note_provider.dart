import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/note_repository.dart';
import '../domain/note.dart';

final noteRepositoryProvider =
    Provider<NoteRepository>((_) => NoteRepository());

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);

class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    return ref.watch(noteRepositoryProvider).getAll();
  }

  Future<int> add({
    int? bookId,
    int? chapterIndex,
    int? charStart,
    int? charEnd,
    required String selectedText,
    required String noteText,
  }) async {
    final id = await ref.read(noteRepositoryProvider).add(
          bookId: bookId,
          chapterIndex: chapterIndex,
          charStart: charStart,
          charEnd: charEnd,
          selectedText: selectedText,
          noteText: noteText,
        );
    ref.invalidateSelf();
    return id;
  }

  Future<void> updateText(int id, String noteText) async {
    await ref.read(noteRepositoryProvider).updateText(id, noteText);
    ref.invalidateSelf();
  }

  Future<void> remove(int id) async {
    await ref.read(noteRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}
