import 'package:isar/isar.dart';
import 'thought.dart';

part 'entity.g.dart'; // Needed for build_runner

@collection
class Entity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  @Index()
  late String category; // 'Person', 'Place', 'Concept', 'Event'

  late DateTime lastMentioned;
  int mentionCount = 0;

  // Backlink to see which thoughts contain this entity
  @Backlink(to: 'entities')
  final thoughts = IsarLinks<Thought>();
}