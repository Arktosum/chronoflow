import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/mood.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

/// One tap = one feeling. You're sad? You hit Sad. The sliders only exist
/// inside the preset editor, where friction is fine.
/// Returns the chosen mood map ({} to clear), or null if dismissed.
Future<Map<String, double>?> showMoodSheet(
    BuildContext context, Map<String, double> current) {
  return showModalBottomSheet<Map<String, double>>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MoodSheet(current: current),
  );
}

class _MoodSheet extends ConsumerWidget {
  final Map<String, double> current;
  const _MoodSheet({required this.current});

  Future<void> _deletePreset(
      BuildContext context, WidgetRef ref, Map<String, dynamic> preset) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RiverColors.surfaceRaised,
        title: Text('Forget "${preset['name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Forget',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (sure == true) {
      await ref
          .read(repositoryProvider)
          .deleteMoodPreset(preset['id'] as int);
      ref.invalidate(moodPresetsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(moodPresetsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HOW DOES IT FEEL?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 13,
                  color: RiverColors.textSecondary,
                ),
              ),
              if (current.values.any((v) => v > 0))
                TextButton(
                  onPressed: () => Navigator.pop(context, <String, double>{}),
                  child: const Text('Unstamp',
                      style: TextStyle(
                          color: RiverColors.textFaint, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          presets.when(
            loading: () => const SizedBox(height: 60),
            error: (e, _) => Text('$e'),
            data: (list) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...list.map((p) {
                  final mood = decodeMood(p['mood_json'] as String);
                  final dominant = dominantEmotions(mood, limit: 1);
                  final color = dominant.isEmpty
                      ? RiverColors.textSecondary
                      : dominant.first.color;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, mood),
                    onLongPress: () => _deletePreset(context, ref, p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${p['emoji']} ${p['name']}',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
                // Sculpt a new feeling (sliders live in there).
                GestureDetector(
                  onTap: () async {
                    final made = await showDialog<Map<String, double>>(
                      context: context,
                      builder: (context) => const _PresetEditorDialog(),
                    );
                    if (made != null && context.mounted) {
                      Navigator.pop(context, made);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Text(
                      '+ new feeling',
                      style: TextStyle(
                          color: RiverColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'long-press a feeling to forget it',
            style: TextStyle(color: RiverColors.textFaint, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Where feelings are sculpted: name, emoji, and the eight sliders.
/// Saves the preset and returns its vector for immediate stamping.
class _PresetEditorDialog extends ConsumerStatefulWidget {
  const _PresetEditorDialog();

  @override
  ConsumerState<_PresetEditorDialog> createState() =>
      _PresetEditorDialogState();
}

class _PresetEditorDialogState extends ConsumerState<_PresetEditorDialog> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final Map<String, double> _mood = {for (final e in emotions) e.key: 0.0};

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final emoji =
        _emojiController.text.trim().isEmpty ? '🌊' : _emojiController.text.trim();
    final json = encodeMood(_mood) ?? '{}';

    await ref.read(repositoryProvider).saveMoodPreset(name, emoji, json);
    ref.invalidate(moodPresetsProvider);
    if (mounted) Navigator.pop(context, _mood);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RiverColors.surfaceRaised,
      title: const Text('SCULPT A FEELING',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: RiverColors.textSecondary)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: _emojiController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(
                          hintText: '🌊',
                          hintStyle: TextStyle(fontSize: 20),
                          border: InputBorder.none),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Name it (e.g. Homesick)',
                        hintStyle: TextStyle(color: RiverColors.textFaint),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...emotions.map((e) {
                final value = _mood[e.key]!;
                return Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        '${e.emoji} ${e.label}',
                        style: TextStyle(
                          color:
                              value > 0 ? e.color : RiverColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: value,
                        activeColor: e.color,
                        inactiveColor: Colors.white10,
                        onChanged: (v) => setState(() => _mood[e.key] = v),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: RiverColors.textSecondary))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: RiverColors.purple),
          onPressed: _save,
          child: const Text('Save feeling'),
        ),
      ],
    );
  }
}
