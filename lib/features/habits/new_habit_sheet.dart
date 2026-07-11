import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/habit.dart';
import '../../providers.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

/// Pass [existing] to edit a habit instead of creating one.
Future<void> showNewHabitSheet(BuildContext context, {Habit? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _NewHabitSheet(existing: existing),
  );
}

class _NewHabitSheet extends ConsumerStatefulWidget {
  final Habit? existing;
  const _NewHabitSheet({this.existing});

  @override
  ConsumerState<_NewHabitSheet> createState() => _NewHabitSheetState();
}

class _NewHabitSheetState extends ConsumerState<_NewHabitSheet> {
  late final _tagController =
      TextEditingController(text: widget.existing?.tagName ?? '');
  late final _identityController =
      TextEditingController(text: widget.existing?.identityName ?? '');
  late int _colorIndex = _initialColorIndex();
  late bool _isDaily = widget.existing?.isDaily ?? true;
  late int _timesPerWeek =
      widget.existing?.isDaily ?? true ? 3 : widget.existing!.timesPerWeek;
  late TimeOfDay? _reminder = widget.existing?.reminderMinutes != null
      ? TimeOfDay(
          hour: widget.existing!.reminderMinutes! ~/ 60,
          minute: widget.existing!.reminderMinutes! % 60)
      : null;
  late int _dailyTarget = widget.existing?.dailyTarget ?? 1;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  int _initialColorIndex() {
    final val = widget.existing?.colorVal;
    if (val == null) return 0;
    final i = RiverColors.tagPalette.indexWhere((c) => c.toARGB32() == val);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _tagController.dispose();
    _identityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tagName = _tagController.text
        .trim()
        .replaceAll('#', '')
        .replaceAll(' ', '_')
        .toLowerCase();
    if (tagName.isEmpty || _saving) return;
    setState(() => _saving = true);

    final identity = _identityController.text.trim();

    final repo = ref.read(repositoryProvider);
    final colorVal = RiverColors.tagPalette[_colorIndex].toARGB32();
    final reminderMinutes =
        _reminder == null ? null : _reminder!.hour * 60 + _reminder!.minute;

    final Habit habit;
    if (_isEdit) {
      final old = widget.existing!;
      habit = Habit(
        id: old.id,
        tagId: old.tagId,
        tagName: old.tagName, // the tag is the habit's identity — unchangeable
        identityName: identity,
        frequencyType: _isDaily ? 'daily' : 'weekly',
        timesPerWeek: _isDaily ? 7 : _timesPerWeek,
        dailyTarget: _isDaily ? _dailyTarget : 1,
        reminderMinutes: reminderMinutes,
        createdAt: old.createdAt,
        isArchived: old.isArchived,
        colorVal: colorVal,
      );
      await repo.updateHabit(habit);
      await repo.setTagColor(old.tagId, colorVal);
    } else {
      habit = await repo.createHabit(
        tagName: tagName,
        identityName: identity,
        colorVal: colorVal,
        frequencyType: _isDaily ? 'daily' : 'weekly',
        timesPerWeek: _isDaily ? 7 : _timesPerWeek,
        dailyTarget: _isDaily ? _dailyTarget : 1,
        reminderMinutes: reminderMinutes,
      );
    }
    await NotificationService.instance.scheduleHabitReminder(habit);

    if (mounted) {
      ref.refreshRiver();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            _isEdit ? 'RESHAPE THE PROMISE' : 'A NEW PROMISE',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 14,
              color: RiverColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tagController,
            enabled: !_isEdit, // the tag anchors all history — locked on edit
            autofocus: !_isEdit,
            style: const TextStyle(
                color: RiverColors.cyan, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              prefixText: '# ',
              prefixStyle: TextStyle(
                  color: RiverColors.cyan, fontWeight: FontWeight.bold),
              hintText: 'meditation',
              hintStyle: TextStyle(color: RiverColors.textFaint),
              labelText: 'The habit (becomes a tag)',
              labelStyle: TextStyle(color: RiverColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _identityController,
            decoration: const InputDecoration(
              hintText: 'e.g. “Calm You” — every star becomes a vote for them',
              hintStyle:
                  TextStyle(color: RiverColors.textFaint, fontSize: 13),
              labelText: 'A name for who you’re becoming (optional)',
              labelStyle: TextStyle(color: RiverColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Every day'),
                selected: _isDaily,
                onSelected: (_) => setState(() => _isDaily = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(_isDaily ? 'x / week' : '$_timesPerWeek× / week'),
                selected: !_isDaily,
                onSelected: (_) => setState(() => _isDaily = false),
              ),
              if (!_isDaily) ...[
                Expanded(
                  child: Slider(
                    value: _timesPerWeek.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,
                    activeColor: RiverColors.purple,
                    onChanged: (v) =>
                        setState(() => _timesPerWeek = v.round()),
                  ),
                ),
              ],
            ],
          ),
          if (_isDaily) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Times per day',
                  style: TextStyle(
                      color: RiverColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: RiverColors.textSecondary, size: 20),
                  onPressed: _dailyTarget > 1
                      ? () => setState(() => _dailyTarget--)
                      : null,
                ),
                Text(
                  '$_dailyTarget',
                  style: const TextStyle(
                    color: RiverColors.cyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: RiverColors.textSecondary, size: 20),
                  onPressed: _dailyTarget < 8
                      ? () => setState(() => _dailyTarget++)
                      : null,
                ),
                if (_dailyTarget > 1)
                  const Expanded(
                    child: Text(
                      'one habit, many taps — like 3 good meals',
                      style: TextStyle(
                          color: RiverColors.textFaint, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: List.generate(RiverColors.tagPalette.length, (i) {
              final color = RiverColors.tagPalette[i];
              return GestureDetector(
                onTap: () => setState(() => _colorIndex = i),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: _colorIndex == i ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: RiverColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime:
                        _reminder ?? const TimeOfDay(hour: 20, minute: 0),
                  );
                  if (picked != null) setState(() => _reminder = picked);
                },
                child: Text(
                  _reminder == null
                      ? 'Add a reminder'
                      : 'Remind at ${_reminder!.format(context)}',
                  style: const TextStyle(color: RiverColors.cyan),
                ),
              ),
              if (_reminder != null)
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: RiverColors.textSecondary),
                  onPressed: () => setState(() => _reminder = null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: RiverColors.purple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _save,
              child: Text(_isEdit ? 'Keep the promise' : 'Light the first star'),
            ),
          ),
        ],
      ),
    );
  }
}
