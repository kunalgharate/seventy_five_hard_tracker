import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/app_user.dart';

/// Bottom sheet to create a new task from the Squad screen.
/// Reviewer assignment is optional — tasks without reviewers
/// complete normally without proof review.
class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateTaskSheet(),
    );
  }

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _taskType = 'hard'; // 'hard' or 'regular'
  AppUser? _selectedReviewer;
  bool _lookingUp = false;
  bool _creating = false;
  String? _emailError;
  String? _titleError;

  final _svc = AccountabilityService();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupReviewer() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _selectedReviewer = null);
      return;
    }
    if (!email.contains('@')) {
      setState(() => _emailError = 'Enter a valid email');
      return;
    }
    setState(() {
      _lookingUp = true;
      _emailError = null;
    });
    try {
      final user = await _svc.findUserByEmail(email);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _lookingUp = false;
          _emailError = 'No user found. They need to join DailyMettle first.';
        });
      } else {
        setState(() {
          _lookingUp = false;
          _selectedReviewer = user;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lookingUp = false;
          _emailError = 'Lookup failed. Try again.';
        });
      }
    }
  }

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || title.length < 3) {
      setState(() => _titleError = 'Task name must be at least 3 characters');
      return;
    }
    setState(() {
      _titleError = null;
      _creating = true;
    });

    try {
      String? partnershipId;
      String accountableUid = _svc.currentUid ?? '';
      String accountableName = _svc.currentUserDisplayName;

      // If reviewer selected, create partnership + task with reviewer
      if (_selectedReviewer != null) {
        partnershipId = await _svc.ensurePartnership(
          _selectedReviewer!.uid,
          _selectedReviewer!.displayName,
        );
        accountableUid = _selectedReviewer!.uid;
        accountableName = _selectedReviewer!.displayName;
      }

      final task = await _svc.createAccountabilityTask(
        accountableUid: accountableUid,
        accountableName: accountableName,
        partnershipId: partnershipId ?? '',
        title: title,
        description: _descCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _creating = false);

      if (task != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedReviewer != null
                ? 'Task created! ${_selectedReviewer!.displayName} '
                    'will be asked to review.'
                : 'Task created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create task. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.grey[850]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey[900]!;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create Task',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a new task to your challenge. Reviewer is optional.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),

            // ── Task type selector ──
            Text(
              'Task Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeChip('hard', '75 Hard', Colors.deepOrange),
                const SizedBox(width: 10),
                _buildTypeChip('regular', 'Routine', Colors.purple),
              ],
            ),
            const SizedBox(height: 16),

            // ── Task name ──
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Task name *',
                hintText: 'e.g. 45 minute workout',
                errorText: _titleError,
                prefixIcon: const Icon(Icons.task_alt),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: TextStyle(color: textColor),
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: 12),

            // ── Description (optional) ──
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What does this task involve?',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 16),

            // ── Reviewer (optional) ──
            Text(
              'Add a Reviewer (optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tasks without a reviewer complete normally.',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),

            if (_selectedReviewer != null)
              _buildSelectedReviewer()
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'reviewer@email.com',
                        errorText: _emailError,
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      style: TextStyle(color: textColor, fontSize: 14),
                      onSubmitted: (_) => _lookupReviewer(),
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _lookingUp ? null : _lookupReviewer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _lookingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Find'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // ── Create button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _creating ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _selectedReviewer != null
                            ? 'Create & Invite Reviewer'
                            : 'Create Task',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, Color color) {
    final selected = _taskType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _taskType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey[300]!,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? color : Colors.grey[500],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedReviewer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.green.withValues(alpha: 0.15),
            child: Text(
              _selectedReviewer!.displayName.isNotEmpty
                  ? _selectedReviewer!.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedReviewer!.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _selectedReviewer!.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _selectedReviewer = null;
              _emailCtrl.clear();
            }),
            icon: const Icon(Icons.close, size: 18),
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }
}
