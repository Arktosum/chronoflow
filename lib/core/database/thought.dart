import 'package:isar/isar.dart';
import 'entity.dart';

part 'thought.g.dart';

@collection
class Thought {
  Id id = Isar.autoIncrement;

  String? title; // <-- NEW: Optional title

  @Index(type: IndexType.value)
  late String content;

  @Index()
  late DateTime timestamp;

  bool isArchived = false;

  final entities = IsarLinks<Entity>();
}
