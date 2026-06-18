import 'package:flutter/material.dart';
import '../../features/capture/capture_screen.dart';
import '../../features/history/history_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const CaptureScreen(),
    const HistoryScreen(), // We will build this next
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_timeline_outlined),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
