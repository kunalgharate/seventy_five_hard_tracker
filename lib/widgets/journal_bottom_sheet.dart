import 'package:flutter/material.dart';
import 'package:seventy_five_hard_tracker/widgets/voice_input.dart';

class JournalBottomSheet extends StatefulWidget {
  final DateTime date;
  final String? existingNote;
  final Function(String) onSave;
  final Function()? onDelete;

  const JournalBottomSheet({
    super.key,
    required this.date,
    this.existingNote,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<JournalBottomSheet> createState() => _JournalBottomSheetState();
}

class _JournalBottomSheetState extends State<JournalBottomSheet> {
  late TextEditingController _controller;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingNote ?? '');
    _controller.addListener(() {
      setState(() {
        _hasChanges = _controller.text != (widget.existingNote ?? '');
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Journal Entry?'),
        content: const Text(
          'This action cannot be undone. Your journal entry will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              widget.onDelete!();
              Navigator.pop(context); // close bottom sheet
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingNote =
        widget.existingNote != null && widget.existingNote!.isNotEmpty;

    return SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.book, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Daily Journal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasExistingNote && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(context),
                      tooltip: 'Delete',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _controller.text.isEmpty
                          ? 'Write or dictate your thoughts…'
                          : 'Edit your entry',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TronPolishButton(controller: _controller),
                  MicDictationButton(controller: _controller),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLines: 8,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'How was your day? Write or dictate…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (hasExistingNote)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _hasChanges = true;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                  if (hasExistingNote) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _hasChanges || !hasExistingNote
                          ? () {
                              widget.onSave(_controller.text);
                              Navigator.pop(context);
                            }
                          : null,
                      child: Text(hasExistingNote ? 'Update' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
  }
}
