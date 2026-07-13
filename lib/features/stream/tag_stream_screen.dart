import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/night_sky.dart';
import 'entry_card.dart';
import 'thought_editor_screen.dart';
import 'thread_screen.dart';

/// One tag's whole history: every thought that ever touched it.
class TagStreamScreen extends ConsumerWidget {
  final String kind; // '#', '@', or '~'
  final String name;
  const TagStreamScreen({super.key, required this.kind, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(tagEntriesProvider('$kind$name'));
    final continuedIds =
        ref.watch(continuedIdsProvider).asData?.value ?? const <int>{};
    final accent = RiverColors.forKind(kind);

    return NightSkyBackground(
      seed: name.hashCode,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '$kind$name',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 16,
            ),
          ),
        ),
        body: entries.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: accent)),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${items.length} ${items.length == 1 ? "thought" : "thoughts"} across time',
                  style: const TextStyle(
                      color: RiverColors.textSecondary, fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 40),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return EntryCard(
                      item: item,
                      showFullDate: true,
                      isContinued: continuedIds.contains(item.entry.id),
                      onThreadTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ThreadScreen(entryId: item.entry.id!),
                        ),
                      ),
                      onTap: item.entry.isCheckIn
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ThoughtEditorScreen(
                                      existing: item.entry),
                                  fullscreenDialog: true,
                                ),
                              ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
