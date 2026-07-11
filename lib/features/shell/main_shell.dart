import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../habits/new_habit_sheet.dart';
import '../habits/sky_screen.dart';
import '../stream/stream_screen.dart';
import '../stream/thought_editor_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  /// The big button is contextual: River → new thought, Sky → new habit.
  void _onAdd() {
    if (_index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const ThoughtEditorScreen(),
            fullscreenDialog: true),
      );
    } else {
      showNewHabitSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _index == 0 ? RiverColors.cyan : RiverColors.purple;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [
          StreamScreen(),
          SkyScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: GestureDetector(
        onTap: _onAdd,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: RiverColors.bg,
            border: Border.all(color: accent, width: 2),
            boxShadow: RiverColors.glow(accent),
          ),
          child: Icon(Icons.add_rounded, color: accent, size: 34),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: RiverColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.water_rounded,
                label: 'RIVER',
                selected: _index == 0,
                accent: RiverColors.cyan,
                onTap: () => setState(() => _index = 0),
              ),
            ),
            const SizedBox(width: 68), // room for the big button
            Expanded(
              child: _NavItem(
                icon: Icons.auto_awesome_rounded,
                label: 'SKY',
                selected: _index == 1,
                accent: RiverColors.purple,
                onTap: () => setState(() => _index = 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : Colors.white30;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}
