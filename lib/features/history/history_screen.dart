import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import '../../core/database/db_provider.dart';
import '../../core/database/thought.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: All, 1: Recent

  Future<List<Thought>> _fetchThoughts() async {
    final isar = await ref.read(isarProvider.future);

    return await isar.thoughts
        .filter()
        // 1. Conditionally apply the search filter
        .optional(
          _searchQuery.isNotEmpty,
          (q) => q.group((q) => q
              .titleContains(_searchQuery, caseSensitive: false)
              .or()
              .contentContains(_searchQuery, caseSensitive: false)),
        )
        // 2. Conditionally apply the "Recent" filter
        .optional(
          _selectedFilterIndex == 1,
          (q) => q.timestampGreaterThan(
            DateTime.now().subtract(const Duration(days: 3)),
          ),
        )
        // 3. Sort and execute (Types are preserved!)
        .sortByTimestampDesc()
        .findAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Sleek Collapsing Header
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            backgroundColor:
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: const Text(
                'Your Flow',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search and Filters Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  // Glass-like Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search your mind...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.3)),
                        prefixIcon: Icon(Icons.search,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Premium Toggles
                  Row(
                    children: [
                      _buildFilterChip(0, 'All Thoughts'),
                      const SizedBox(width: 12),
                      _buildFilterChip(1, 'Recent'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // The List of Thoughts
          FutureBuilder<List<Thought>>(
            future: _fetchThoughts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final thoughts = snapshot.data ?? [];

              if (thoughts.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.waves,
                            size: 64, color: Colors.white.withOpacity(0.05)),
                        const SizedBox(height: 16),
                        Text('Your flow is empty.',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final thought = thoughts[index];
                      return _buildThoughtCard(context, thought);
                    },
                    childCount: thoughts.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Custom UI Components ---

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilterIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? primaryColor.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryColor : Colors.white.withOpacity(0.5),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildThoughtCard(BuildContext context, Thought thought) {
    final timeStr = DateFormat('h:mm a').format(thought.timestamp);
    final dateStr = DateFormat('MMM d').format(thought.timestamp);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dismissible(
      key: ValueKey(thought.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 32.0),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child:
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
      ),
      onDismissed: (direction) async {
        final isar = await ref.read(isarProvider.future);
        await isar.writeTxn(() async => await isar.thoughts.delete(thought.id));
        setState(() {}); // Refresh view
        HapticFeedback.mediumImpact();
      },
      child: GestureDetector(
        onTap: () {
          context.push('/edit/${thought.id}').then((_) => setState(() {}));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.03)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Date & Time
              SizedBox(
                width: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Subtle Divider line
              Container(
                width: 1,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withOpacity(0.1),
              ),

              // Right Column: Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thought.title != null && thought.title!.isNotEmpty) ...[
                      Text(
                        thought.title!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      thought.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
