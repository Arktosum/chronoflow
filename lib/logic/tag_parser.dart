/// Everything tag-shaped in the river flows through this one regex.
final RegExp tagRegex = RegExp(r'([@#])([a-zA-Z0-9_]+)');

class ParsedTag {
  final String kind; // '#' or '@'
  final String name; // lowercase, without sigil
  const ParsedTag(this.kind, this.name);

  @override
  bool operator ==(Object other) =>
      other is ParsedTag && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);
}

List<ParsedTag> parseTags(String text) {
  return tagRegex
      .allMatches(text)
      .map((m) => ParsedTag(m.group(1)!, m.group(2)!.toLowerCase()))
      .toSet()
      .toList();
}
