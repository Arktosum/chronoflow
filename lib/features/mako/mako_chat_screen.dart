import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/entry.dart';
import '../../data/models/mako_message.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/night_sky.dart';

/// A whole page for talking to Mako. Conversations persist here — they are
/// deliberately NOT part of the river; the river is for your own thoughts.
class MakoChatScreen extends ConsumerStatefulWidget {
  /// When set, the first question is about this specific thought.
  final Entry? about;

  const MakoChatScreen({super.key, this.about});

  @override
  ConsumerState<MakoChatScreen> createState() => _MakoChatScreenState();
}

class _MakoChatScreenState extends ConsumerState<MakoChatScreen> {
  final _controller = TextEditingController();

  /// The thought under discussion; cleared after it's asked about once.
  late Entry? _about = widget.about;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    ref.read(makoProvider.notifier).ask(q, about: _about);
    setState(() => _about = null);
    _controller.clear();
  }

  Future<void> _editToken() async {
    final repo = ref.read(repositoryProvider);
    final controller =
        TextEditingController(text: await repo.getMeta('mako_token') ?? '');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RiverColors.surfaceRaised,
        title: const Text('ONLY FOR YOU',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: RiverColors.textSecondary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the token that matches MAKO_DASH_TOKEN on her server. '
              'Without it, anyone with this app could talk to her.',
              style:
                  TextStyle(color: RiverColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              style: const TextStyle(color: RiverColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'token',
                hintStyle: TextStyle(color: RiverColors.textFaint),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: RiverColors.textSecondary))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: RiverColors.purple),
            onPressed: () async {
              await repo.setMeta('mako_token', controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(makoChatProvider);
    final mako = ref.watch(makoProvider);

    return NightSkyBackground(
      seed: 7,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('MAKO',
              style: TextStyle(
                color: RiverColors.purple,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                fontSize: 15,
              )),
          actions: [
            IconButton(
              icon: const Icon(Icons.key_rounded,
                  size: 18, color: RiverColors.textSecondary),
              tooltip: 'Her token — only for you',
              onPressed: _editToken,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: chat.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: RiverColors.purple)),
                error: (e, _) => Center(child: Text('$e')),
                data: (messages) {
                  if (messages.isEmpty && !mako.thinking) {
                    return const _EmptyChat();
                  }
                  // Reversed list: newest at the bottom, like a conversation.
                  final reversed = messages.reversed.toList();
                  final extra = mako.thinking ? 1 : 0;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: reversed.length + extra,
                    itemBuilder: (context, index) {
                      if (mako.thinking && index == 0) {
                        return const _ThinkingBubble();
                      }
                      return _ChatBubble(message: reversed[index - extra]);
                    },
                  );
                },
              ),
            ),
            if (mako.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        color: RiverColors.textFaint, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mako.error!,
                        style: const TextStyle(
                            color: RiverColors.textFaint,
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(makoProvider.notifier).clearError(),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            color: RiverColors.textFaint, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (_about != null) _AboutChip(entry: _about!),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      autofocus: widget.about != null,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: RiverColors.purple,
                      style: const TextStyle(
                          color: RiverColors.textPrimary, fontSize: 15),
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText:
                            _about != null ? 'ask about it…' : 'hey mako…',
                        hintStyle:
                            const TextStyle(color: RiverColors.textFaint),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color:
                                  RiverColors.purple.withValues(alpha: 0.35)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color:
                                  RiverColors.purple.withValues(alpha: 0.7)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: mako.thinking ? null : _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: mako.thinking
                                ? Colors.white24
                                : RiverColors.purple,
                            width: 1.5),
                        boxShadow: mako.thinking
                            ? null
                            : RiverColors.glow(RiverColors.purple,
                                strength: 0.4),
                      ),
                      child: Icon(Icons.arrow_upward_rounded,
                          color: mako.thinking
                              ? Colors.white24
                              : RiverColors.purple,
                          size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final MakoMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMako = message.isMako;
    final accent = isMako ? RiverColors.purple : RiverColors.cyan;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isMako ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            '${isMako ? 'MAKO' : 'YOU'} · '
            '${DateFormat('d MMM HH:mm').format(message.createdAt).toUpperCase()}',
            style: TextStyle(
              color: accent.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 4),
          if (message.quote != null) ...[
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: RiverColors.hairline),
              ),
              child: Text(
                '“${message.quote}”',
                style: const TextStyle(
                  color: RiverColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMako ? 3 : 14),
                bottomRight: Radius.circular(isMako ? 14 : 3),
              ),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              color: isMako
                  ? RiverColors.purple.withValues(alpha: 0.07)
                  : Colors.transparent,
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: RiverColors.textPrimary,
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FadeTransition(
          opacity: Tween(begin: 0.35, end: 1.0).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors_rounded,
                  color: RiverColors.purple, size: 15),
              SizedBox(width: 8),
              Text(
                'mako is thinking…',
                style: TextStyle(
                  color: RiverColors.purple,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutChip extends StatelessWidget {
  final Entry entry;
  const _AboutChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    var text = entry.title ?? entry.text.replaceAll('\n', ' ');
    if (text.length > 80) text = '${text.substring(0, 80)}…';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.format_quote_rounded,
              color: RiverColors.purple, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'about: $text',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RiverColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_rounded, color: Colors.white12, size: 56),
            SizedBox(height: 16),
            Text(
              'She can see the whole river.\nAsk her anything.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RiverColors.textSecondary, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
