import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/entry.dart';
import '../../data/models/tag.dart';
import '../../data/repositories/river_repository.dart';
import '../../logic/mood.dart';
import '../../logic/tag_parser.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../mako/mako_chat_screen.dart';
import 'mood_sheet.dart';

/// A whole damn page for a thought. Not a message — a canvas.
class ThoughtEditorScreen extends ConsumerStatefulWidget {
  /// When set, we're editing an existing drop instead of creating one.
  final Entry? existing;

  /// Pre-filled span for new entries (e.g. tapped a gap on the timeline).
  final DateTime? initialSpanStart;
  final DateTime? initialSpanEnd;

  /// For new entries: the earlier thought this one continues (a thread).
  final int? parentId;

  const ThoughtEditorScreen(
      {super.key,
      this.existing,
      this.initialSpanStart,
      this.initialSpanEnd,
      this.parentId});

  @override
  ConsumerState<ThoughtEditorScreen> createState() =>
      _ThoughtEditorScreenState();
}

/// Live ink: @people violet, #tags cyan — colored as you type.
class _TagInkController extends TextEditingController {
  _TagInkController([String? text]) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <TextSpan>[];
    text.splitMapJoin(
      tagRegex,
      onMatch: (m) {
        final word = m.group(0)!;
        spans.add(TextSpan(
          text: word,
          style: style?.copyWith(
            color: word.startsWith('@') ? RiverColors.purple : RiverColors.cyan,
            fontWeight: FontWeight.bold,
          ),
        ));
        return word;
      },
      onNonMatch: (t) {
        spans.add(TextSpan(text: t, style: style));
        return t;
      },
    );
    return TextSpan(children: spans, style: style);
  }
}

class _ThoughtEditorScreenState extends ConsumerState<ThoughtEditorScreen> {
  late final _TagInkController _controller =
      _TagInkController(widget.existing?.text);
  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');
  late DateTime? _spanStart =
      widget.existing?.spanStart ?? widget.initialSpanStart;
  late DateTime? _spanEnd = widget.existing?.spanEnd ?? widget.initialSpanEnd;
  late bool _isPlanned = widget.existing != null
      ? widget.existing!.isPlanned
      : (widget.initialSpanStart?.isAfter(DateTime.now()) ?? false);
  late Map<String, double> _mood = decodeMood(widget.existing?.moodJson);

  Future<void> _pickMood() async {
    final result = await showMoodSheet(context, _mood);
    if (result != null) setState(() => _mood = result);
  }
  List<EntryWithTags> _related = [];
  String _relatedTagDisplay = '';
  List<Tag> _suggestions = [];

  /// The partial tag being typed at the cursor, e.g. "#t|" → ('#', 't').
  ({String kind, String prefix, int start})? _tokenAtCursor() {
    final sel = _controller.selection;
    if (!sel.isValid || !sel.isCollapsed) return null;
    final before = _controller.text.substring(0, sel.start);
    final m = RegExp(r'([#@])([A-Za-z0-9_]*)$').firstMatch(before);
    if (m == null) return null;
    return (kind: m.group(1)!, prefix: m.group(2)!, start: m.start);
  }

  Future<void> _updateSuggestions() async {
    final token = _tokenAtCursor();
    if (token == null) {
      if (_suggestions.isNotEmpty && mounted) {
        setState(() => _suggestions = []);
      }
      return;
    }
    final found = await ref
        .read(repositoryProvider)
        .searchTags(token.kind, token.prefix);
    if (mounted) {
      setState(() => _suggestions = found
          .where((t) => t.name != token.prefix.toLowerCase())
          .toList());
    }
  }

  void _applySuggestion(Tag tag) {
    final token = _tokenAtCursor();
    if (token == null) return;
    final sel = _controller.selection;
    final text = _controller.text;
    final replaced = '${tag.kind}${tag.name} ';
    _controller.value = TextEditingValue(
      text: text.replaceRange(token.start, sel.start, replaced),
      selection:
          TextSelection.collapsed(offset: token.start + replaced.length),
    );
  }

  /// "This was my 2–4pm": two taps, start and end.
  Future<void> _pickSpan() async {
    final base = widget.existing?.createdAt ??
        widget.initialSpanStart ??
        DateTime.now();
    final now = DateTime.now();

    final start = await showTimePicker(
      context: context,
      helpText: 'WHEN DID IT START?',
      initialTime: _spanStart != null
          ? TimeOfDay.fromDateTime(_spanStart!)
          : TimeOfDay.fromDateTime(now.subtract(const Duration(hours: 1))),
    );
    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      helpText: 'WHEN DID IT END?',
      initialTime: _spanEnd != null
          ? TimeOfDay.fromDateTime(_spanEnd!)
          : TimeOfDay.fromDateTime(now),
    );
    if (end == null) return;

    var startDt = DateTime(
        base.year, base.month, base.day, start.hour, start.minute);
    var endDt =
        DateTime(base.year, base.month, base.day, end.hour, end.minute);
    if (!endDt.isAfter(startDt)) {
      endDt = endDt.add(const Duration(days: 1)); // crossed midnight
    }
    setState(() {
      _spanStart = startDt;
      _spanEnd = endDt;
      _isPlanned = startDt.isAfter(DateTime.now());
    });
  }

  String? get _spanStatus =>
      _spanStart == null ? null : (_isPlanned ? 'planned' : 'done');

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// Related-while-writing: the newest tag in the text whispers its history.
  Future<void> _onTextChanged() async {
    _updateSuggestions();
    final tags = parseTags(_controller.text);
    if (tags.isEmpty) {
      if (_related.isNotEmpty && mounted) {
        setState(() {
          _related = [];
          _relatedTagDisplay = '';
        });
      }
      return;
    }
    final last = tags.last;
    final display = '${last.kind}${last.name}';
    if (display == _relatedTagDisplay) return;

    final found = await ref
        .read(repositoryProvider)
        .getEntriesForTag(last.name, last.kind, limit: 2);
    if (mounted) {
      setState(() {
        _related = found
            .where((r) => r.entry.id != widget.existing?.id)
            .toList();
        _relatedTagDisplay = display;
      });
    }
  }

  /// Writes the current state to the river. Returns the entry's id
  /// (null when there was nothing to keep and the entry evaporated).
  Future<int?> _persist() async {
    final text = _controller.text.trim();
    final titleText = _titleController.text.trim();
    final title = titleText.isEmpty ? null : titleText;
    final repo = ref.read(repositoryProvider);
    final existing = widget.existing;

    if (existing != null) {
      if (text.isEmpty && title == null) {
        await repo.deleteEntry(existing.id!);
        return null;
      }
      await repo.updateEntry(Entry(
        id: existing.id,
        createdAt: existing.createdAt,
        text: text,
        title: title,
        spanStart: _spanStart,
        spanEnd: _spanEnd,
        spanStatus: _spanStatus,
        parentId: existing.parentId,
        moodJson: encodeMood(_mood),
        habitId: existing.habitId,
        author: existing.author,
      ));
      return existing.id;
    }
    if (text.isNotEmpty || title != null) {
      final saved = await repo.saveEntry(Entry(
        createdAt: DateTime.now(),
        text: text,
        title: title,
        spanStart: _spanStart,
        spanEnd: _spanEnd,
        spanStatus: _spanStatus,
        parentId: widget.parentId,
        moodJson: encodeMood(_mood),
      ));
      return saved.id;
    }
    return null;
  }

  Future<void> _save() async {
    await _persist();
    if (mounted) {
      ref.refreshRiver();
      Navigator.pop(context);
    }
  }

  /// Keep this thought as it is and start the next link of its thread.
  Future<void> _continueThread() async {
    final id = await _persist();
    if (id == null || !mounted) return;
    ref.refreshRiver();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ThoughtEditorScreen(parentId: id),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _discard() async {
    final dirty = _controller.text.trim() != (widget.existing?.text ?? '') ||
        _titleController.text.trim() != (widget.existing?.title ?? '');
    if (dirty) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: RiverColors.surfaceRaised,
          title: const Text('Let it evaporate?'),
          content: const Text('This thought hasn’t joined the river yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep writing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final when = widget.existing?.createdAt ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: RiverColors.textSecondary),
          onPressed: _discard,
        ),
        title: Text(
          DateFormat('EEE d MMM · HH:mm').format(when).toUpperCase(),
          style: const TextStyle(
            letterSpacing: 2.5,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: RiverColors.textSecondary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: RiverColors.cyan),
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.parentId != null || widget.existing?.parentId != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '⟩ CONTINUES AN EARLIER THOUGHT',
                  style: TextStyle(
                    color: RiverColors.purple,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: RiverColors.purple,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: RiverColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Title (optional)',
                hintStyle: TextStyle(color: RiverColors.textFaint),
                border: InputBorder.none,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: RiverColors.cyan,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.7,
                  color: RiverColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Let it out. #tags and @people find their color.',
                  hintStyle: TextStyle(color: RiverColors.textFaint),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _suggestions.map((tag) {
                  final color = tag.kind == '@'
                      ? RiverColors.purple
                      : RiverColors.cyan;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _applySuggestion(tag),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          tag.display,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (_related.isNotEmpty)
            _RelatedWhisper(_relatedTagDisplay, _related),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                if (_spanStart != null && _spanEnd != null) ...[
                  GestureDetector(
                    onTap: _pickSpan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                RiverColors.cyan.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '⏱ ${DateFormat('HH:mm').format(_spanStart!)} – '
                        '${DateFormat('HH:mm').format(_spanEnd!)}',
                        style: const TextStyle(
                          color: RiverColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: RiverColors.textSecondary),
                    tooltip: 'Remove time-span',
                    onPressed: () => setState(() {
                      _spanStart = null;
                      _spanEnd = null;
                    }),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isPlanned = !_isPlanned),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isPlanned
                              ? RiverColors.flame.withValues(alpha: 0.6)
                              : const Color(0xFF39FF88)
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _isPlanned ? '◇ planned' : '✔ done',
                        style: TextStyle(
                          color: _isPlanned
                              ? RiverColors.flame
                              : const Color(0xFF39FF88),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else
                  IconButton(
                    onPressed: _pickSpan,
                    tooltip: 'This took time (add a span)',
                    icon: const Icon(Icons.schedule_rounded,
                        size: 20, color: RiverColors.textSecondary),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _pickMood,
                  child: dominantEmotions(_mood).isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.theater_comedy_outlined,
                              size: 20, color: RiverColors.textSecondary),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: dominantEmotions(_mood)
                                    .first
                                    .color
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            dominantEmotions(_mood)
                                .map((e) => e.emoji)
                                .join(' '),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                ),
                const Spacer(),
                if (widget.existing != null) ...[
                  IconButton(
                    icon: const Icon(Icons.sensors_rounded,
                        size: 20, color: RiverColors.purple),
                    tooltip: 'Ask Mako about this thought',
                    onPressed: () async {
                      final id = await _persist();
                      if (id == null || !context.mounted) return;
                      ref.refreshRiver();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MakoChatScreen(
                            about: Entry(
                              id: id,
                              createdAt: widget.existing!.createdAt,
                              text: _controller.text.trim(),
                              title: _titleController.text.trim().isEmpty
                                  ? null
                                  : _titleController.text.trim(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: _continueThread,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                RiverColors.purple.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'continue ⟩',
                        style: TextStyle(
                          color: RiverColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedWhisper extends StatelessWidget {
  final String tagDisplay;
  final List<EntryWithTags> related;
  const _RelatedWhisper(this.tagDisplay, this.related);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RiverColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RiverColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOU’VE THOUGHT ABOUT $tagDisplay BEFORE',
            style: const TextStyle(
              color: RiverColors.textFaint,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...related.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  r.entry.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RiverColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
