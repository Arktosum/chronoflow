import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'thought.dart';
import 'entity.dart';

// Provides the global Isar instance
final isarProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open(
    [ThoughtSchema, EntitySchema],
    directory: dir.path,
    name: 'chronoflow_db',
  );
});

// Example Provider to watch today's thoughts reactively
final todaysThoughtsProvider = StreamProvider<List<Thought>>((ref) async* {
  final isar = await ref.watch(isarProvider.future);

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

  yield* isar.thoughts
      .filter()
      .timestampBetween(startOfDay, endOfDay)
      .sortByTimestampDesc()
      .watch(fireImmediately: true);
});
