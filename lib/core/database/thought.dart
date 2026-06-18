import 'package:isar/isar.dart';
import 'entity.dart';

part 'thought.g.dart'; // Needed for build_runner

@collection
class Thought {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String content;

  @Index()
  late DateTime timestamp;

  // Metadata
  bool isArchived = false;

  // Many-to-Many Relationship to Entities
  final entities = IsarLinks<Entity>();
}
