import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../core/database/db_provider.dart';
import '../../core/database/thought.dart';
import '../../core/database/entity.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  String _currentQuery = '';
  int _atIndex = -1;
  final List<Entity> _linkedEntities = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final cursorPosition = _controller.selection.base.offset;
    if (cursorPosition == -1) return;

    final textBeforeCursor = text.substring(0, cursorPosition);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    // Check if '@' is at the start of a word
    if (atIndex != -1 &&
        (atIndex == 0 || textBeforeCursor[atIndex - 1] == ' ')) {
      final query = textBeforeCursor.substring(atIndex + 1);
      // Ensure there are no spaces after the '@'
      if (!query.contains(' ')) {
        _atIndex = atIndex;
        _currentQuery = query;
        _showOverlay();
        return;
      }
    }
    _removeOverlay();
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuart,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 10 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: FutureBuilder<List<Entity>>(
                  future: _searchEntities(_currentQuery),
                  builder: (context, snapshot) {
                    final entities = snapshot.data ?? [];

                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: entities.length + 1,
                      itemBuilder: (context, index) {
                        if (index == entities.length) {
                          return ListTile(
                            leading: Icon(Icons.add_circle_outline,
                                color: Theme.of(context).colorScheme.primary),
                            title: Text('Create "$_currentQuery"',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                            onTap: () =>
                                _selectEntity(_currentQuery, isNew: true),
                          );
                        }
                        final entity = entities[index];
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(entity.name),
                          onTap: () => _selectEntity(entity.name, isNew: false),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<List<Entity>> _searchEntities(String query) async {
    final isar = await ref.read(isarProvider.future);
    return await isar
        .collection<Entity>()
        .filter()
        .nameStartsWith(query, caseSensitive: false)
        .findAll();
  }

  Future<void> _selectEntity(String name, {required bool isNew}) async {
    final isar = await ref.read(isarProvider.future);
    Entity? entityToLink;

    if (isNew) {
      entityToLink = Entity()
        ..name = name
        ..category = 'Person'
        ..lastMentioned = DateTime.now()
        ..mentionCount = 0;

      await isar.writeTxn(() async {
        await isar.collection<Entity>().put(entityToLink!);
      });
    } else {
      entityToLink = await isar
          .collection<Entity>()
          .filter()
          .nameEqualTo(name)
          .findFirst();
    }

    if (entityToLink != null &&
        !_linkedEntities.any((e) => e.id == entityToLink!.id)) {
      _linkedEntities.add(entityToLink);
    }

    final text = _controller.text;
    final newText = text.replaceRange(
        _atIndex, _controller.selection.base.offset, '@$name ');

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: _atIndex + name.length + 2),
    );

    _removeOverlay();
    _focusNode.requestFocus();
  }

  Future<void> _saveThought() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final isar = await ref.read(isarProvider.future);

    final newThought = Thought()
      ..content = text
      ..timestamp = DateTime.now();

    await isar.writeTxn(() async {
      await isar.collection<Thought>().put(newThought);

      if (_linkedEntities.isNotEmpty) {
        newThought.entities.addAll(_linkedEntities);
        await newThought.entities.save();

        for (var entity in _linkedEntities) {
          entity.mentionCount += 1;
          entity.lastMentioned = DateTime.now();
          await isar.collection<Entity>().put(entity);
        }
      }
    });

    _controller.clear();
    _linkedEntities.clear();
  }

  @override
  Widget build(BuildContext context) {
    final thoughtsAsync = ref.watch(todaysThoughtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chronoflow',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: thoughtsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (thoughts) {
                if (thoughts.isEmpty) {
                  return const Center(
                    child: Text('Your mind is clear. Type a thought below.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: thoughts.length,
                  itemBuilder: (context, index) {
                    final thought = thoughts[index];

                    return Container(
                      margin:
                          const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white
                              .withOpacity(0.05), // Subtle edge highlight
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        thought.content,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          letterSpacing: 0.2, // Slightly better readability
                          color: Colors.white, // Forces high contrast
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16).copyWith(bottom: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border:
                  Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onTextChanged,
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Type @ to tag someone...',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Replace the old CircleAvatar with this:
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary, // The Electric Cyan
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.4),
                        blurRadius: 12, // Creates the neon glow effect
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.black, size: 28),
                    tooltip: 'Flow',
                    onPressed: _saveThought,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
