import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/db_provider.dart';
import '../../core/database/thought.dart';

class EditScreen extends ConsumerStatefulWidget {
  final int thoughtId;
  const EditScreen({super.key, required this.thoughtId});

  @override
  ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  Thought? _thought;

  @override
  void initState() {
    super.initState();
    _loadThought();
  }

  Future<void> _loadThought() async {
    final isar = await ref.read(isarProvider.future);
    _thought = await isar.thoughts.get(widget.thoughtId);
    if (_thought != null) {
      setState(() {
        _titleController.text = _thought!.title ?? '';
        _contentController.text = _thought!.content;
      });
    }
  }

  Future<void> _updateThought() async {
    if (_thought == null || _contentController.text.trim().isEmpty) return;

    final isar = await ref.read(isarProvider.future);

    await isar.writeTxn(() async {
      _thought!.title = _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim();
      _thought!.content = _contentController.text.trim();
      await isar.thoughts.put(_thought!); // .put updates if ID exists
    });

    if (mounted) {
      context.pop(); // Go back to history screen
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thought == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Flow'),
        actions: [
          TextButton(
            onPressed: _updateThought,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Update',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Title (Optional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  border: InputBorder.none,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                      fontSize: 18, height: 1.8, color: Colors.white),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
