import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/river_repository.dart';
import '../../logic/mood.dart';
import '../../logic/tag_parser.dart';
import '../../theme/app_theme.dart';
import 'tag_stream_screen.dart';

/// One thought as a node on the neon thread: a dot of light on the lifeline,
/// title and text flowing beside it. No bubbles — this is a log, not a chat.
class EntryCard extends StatelessWidget {
  final EntryWithTags item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Show the full date instead of just the time (for tag pages etc.).
  final bool showFullDate;

  /// True when some later thought continues this one (a thread head/link).
  final bool isContinued;

  /// Opens the thread view; the marker shows when this or [isContinued] is set.
  final VoidCallback? onThreadTap;

  const EntryCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.showFullDate = false,
    this.isContinued = false,
    this.onThreadTap,
  });

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final time = showFullDate
        ? DateFormat('d MMM yyyy · HH:mm').format(entry.createdAt)
        : DateFormat('HH:mm').format(entry.createdAt);
    final isCheckIn = entry.isCheckIn;

    final tag = item.tags.isNotEmpty ? item.tags.first : null;
    final starColor =
        tag?.colorVal != null ? Color(tag!.colorVal!) : RiverColors.cyan;
    final isSilentCheckIn =
        isCheckIn && tag != null && entry.text == tag.display;
    final mood = dominantEmotions(decodeMood(entry.moodJson));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The thread: node + continuing line.
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  const SizedBox(
                      height: 4, child: VerticalDivider(width: 1.2)),
                  isCheckIn
                      ? Icon(Icons.star_rounded, color: starColor, size: 16)
                      : Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: entry.isMako
                                ? RiverColors.purple
                                : RiverColors.cyan,
                            boxShadow: RiverColors.glow(
                                entry.isMako
                                    ? RiverColors.purple
                                    : RiverColors.cyan,
                                strength: 0.5),
                          ),
                        ),
                  const Expanded(child: VerticalDivider(width: 1.2)),
                ],
              ),
            ),
            // The thought itself.
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: 20, bottom: isCheckIn ? 18 : 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.isMako ? 'MAKO · $time' : time,
                      style: TextStyle(
                        color: entry.isMako
                            ? RiverColors.purple.withValues(alpha: 0.85)
                            : RiverColors.textFaint,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    if (isCheckIn) ...[
                      const SizedBox(height: 4),
                      isSilentCheckIn
                          ? Text(
                              'A star for ${tag.display}',
                              style: TextStyle(
                                  color: starColor.withValues(alpha: 0.9),
                                  fontSize: 13),
                            )
                          : InkText(entry.text, fontSize: 13),
                    ] else ...[
                      if (entry.spanStart != null &&
                          entry.spanEnd != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${entry.isPlanned ? "◇" : "⏱"} '
                          '${DateFormat('HH:mm').format(entry.spanStart!)} – '
                          '${DateFormat('HH:mm').format(entry.spanEnd!)}'
                          '${entry.isPlanned ? " · planned" : ""}',
                          style: TextStyle(
                            color: entry.isPlanned
                                ? RiverColors.flame.withValues(alpha: 0.9)
                                : starColor.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                      if (entry.title != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          entry.title!,
                          style: const TextStyle(
                            color: RiverColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (entry.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkText(entry.text, maxLines: 8),
                      ],
                      if (mood.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          mood.map((e) => e.emoji).join(' '),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                      if (onThreadTap != null &&
                          (isContinued || entry.parentId != null)) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onThreadTap,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            '⟩ PART OF A THREAD',
                            style: TextStyle(
                              color:
                                  RiverColors.purple.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text with living tags: colored, and tappable into their tag pages.
class InkText extends StatefulWidget {
  final String text;
  final double fontSize;
  final int? maxLines;
  const InkText(this.text, {super.key, this.fontSize = 15, this.maxLines});

  @override
  State<InkText> createState() => _InkTextState();
}

class _InkTextState extends State<InkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final base = TextStyle(
        color: RiverColors.textPrimary,
        fontSize: widget.fontSize,
        height: 1.55);
    final spans = <TextSpan>[];

    widget.text.splitMapJoin(
      tagRegex,
      onMatch: (m) {
        final word = m.group(0)!;
        final kind = m.group(1)!;
        final name = m.group(2)!.toLowerCase();
        final recognizer = TapGestureRecognizer()
          ..onTap = () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TagStreamScreen(kind: kind, name: name),
                ),
              );
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: word,
          recognizer: recognizer,
          style: base.copyWith(
            color: kind == '@' ? RiverColors.purple : RiverColors.cyan,
            fontWeight: FontWeight.bold,
          ),
        ));
        return word;
      },
      onNonMatch: (t) {
        spans.add(TextSpan(text: t, style: base));
        return t;
      },
    );

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.maxLines != null
          ? TextOverflow.ellipsis
          : TextOverflow.visible,
    );
  }
}
