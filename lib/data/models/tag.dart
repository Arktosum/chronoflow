/// A tag is the only taxonomy in the river. `#topic` or `@person`.
class Tag {
  final int? id;
  final String name; // stored WITHOUT the sigil, lowercase (e.g. "gym")
  final String kind; // '#' or '@'
  final int? colorVal;
  final bool isFavorite;

  const Tag({
    this.id,
    required this.name,
    required this.kind,
    this.colorVal,
    this.isFavorite = false,
  });

  String get display => '$kind$name';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'color': colorVal,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
        id: map['id'] as int?,
        name: map['name'] as String,
        kind: map['kind'] as String,
        colorVal: map['color'] as int?,
        isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      );
}
