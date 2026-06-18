import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../core/database/db_provider.dart';
import '../../core/database/thought.dart';
import '../../core/database/entity.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  String _currentQuery = '';
  int _atIndex = -1;
  final List<Entity> _linkedEntities = [];

  // Keys for SharedPreferences
  static const String _draftContentKey = 'draft_content';
  static const String _draftTitleKey = 'draft_title';

  @override
  void initState() {
    super.initState();
    _loadDraft(); // Load draft on startup

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeOverlay();
    });

    // Auto-save draft whenever the text changes
    _controller.addListener(_saveDraft);
    _titleController.addListener(_saveDraft);
  }

  @override
  void dispose() {
    _controller.removeListener(_saveDraft);
    _titleController.removeListener(_saveDraft);
    _controller.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  // --- Draft Persistence Logic ---

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTitle = prefs.getString(_draftTitleKey) ?? '';
    final savedContent = prefs.getString(_draftContentKey) ?? '';

    if (savedTitle.isNotEmpty || savedContent.isNotEmpty) {
      setState(() {
        _titleController.text = savedTitle;
        _controller.text = savedContent;
      });
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftTitleKey, _titleController.text);
    await prefs.setString(_draftContentKey, _controller.text);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftTitleKey);
    await prefs.remove(_draftContentKey);
  }

  // --- Core Capture Logic ---

  void _onTextChanged(String text) {
    final cursorPosition = _controller.selection.base.offset;
    if (cursorPosition == -1) return;

    final textBeforeCursor = text.substring(0, cursorPosition);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex != -1 &&
        (atIndex == 0 || textBeforeCursor[atIndex - 1] == ' ')) {
      final query = textBeforeCursor.substring(atIndex + 1);
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
        width: MediaQuery.of(context).size.width - 48,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutQuart,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 10 * (1 - value)),
                child: Opacity(opacity: value, child: child),
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
      ..title = _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim()
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

    // Clear the controllers and the saved draft memory
    _titleController.clear();
    _controller.clear();
    _linkedEntities.clear();
    await _clearDraft();
  }

  // --- Keep your existing build() method below this point ---
  // (Do not change the build method we created previously with the date/time header and layout)

  @override
  Widget build(BuildContext context) {
    // Generate beautiful date strings
    final now = DateTime.now();
    final dateString = DateFormat('EEEE, MMMM d').format(now);
    final timeString = DateFormat('h:mm a').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chronoflow',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              onPressed: () {
                _saveThought();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Added to flow.',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text(
                  'Save'), // Replaced the broken icon with sleek text!
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // --- The New Premium Header ---
              Text(
                dateString,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeString,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.3),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Title (Optional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              // --- The Canvas ---
              Expanded(
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onTextChanged,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.8, // Increased for a more airy, essay-like feel
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'What\'s on your mind? \n\n(Type @ to tag a person)',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        height: 1.8,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
