import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/night_sky.dart';
import 'entry_card.dart';
import 'thought_editor_screen.dart';

/// A thread read whole: one idea evolving over days or weeks,
/// oldest link first so it reads like a story.
class ThreadScreen extends ConsumerWidget {
  final int entryId;
  const ThreadScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(threadProvider(entryId));

    return NightSkyBackground(
      seed: entryId,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('THE THREAD')),
        body: thread.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: RiverColors.purple)),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) => ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text(
                    '${items.length} ${items.length == 1 ? "link" : "links"} in this chain',
                    style: const TextStyle(
                        color: RiverColors.textSecondary, fontSize: 12),
                  ),
                ),
              ),
              ...items.map((item) => EntryCard(
                    item: item,
                    showFullDate: true,
                    onTap: item.entry.isCheckIn
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ThoughtEditorScreen(existing: item.entry),
                                fullscreenDialog: true,
                              ),
                            ),
                  )),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(52, 4, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ThoughtEditorScreen(
                              parentId: items.last.entry.id),
                          fullscreenDialog: true,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  RiverColors.purple.withValues(alpha: 0.5)),
                          boxShadow:
                              RiverColors.glow(RiverColors.purple, strength: 0.2),
                        ),
                        child: const Text(
                          '+ continue this thread',
                          style: TextStyle(
                            color: RiverColors.purple,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
