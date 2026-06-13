import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/main.dart';
import 'package:seventy_five_hard_tracker/models/collaborator.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';

class CollaboratorDialog extends StatefulWidget {
  final String taskId;
  final String? taskName;

  const CollaboratorDialog({
    super.key,
    required this.taskId,
    this.taskName,
  });

  /// Public facing avatar builder for use in task cards.
  static Widget buildAvatar(Collaborator collaborator,
      {double size = 32}) {
    if (collaborator.photoUrl != null && collaborator.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          collaborator.photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildInitialsAvatar(collaborator, size),
        ),
      );
    }
    return _buildInitialsAvatar(collaborator, size);
  }

  static Widget _buildInitialsAvatar(Collaborator collaborator, double size) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    final colorIndex = collaborator.uid.hashCode.abs() % colors.length;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[colorIndex].withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          collaborator.initials,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: colors[colorIndex],
          ),
        ),
      ),
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required String taskId,
    String? taskName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CollaboratorDialog(
        taskId: taskId,
        taskName: taskName,
      ),
    );
  }

  @override
  State<CollaboratorDialog> createState() => _CollaboratorDialogState();
}

class _CollaboratorDialogState extends State<CollaboratorDialog> {
  final _svc = AccountabilityService();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();

  Collaborator? _owner;
  List<Collaborator> _collaborators = [];
  List<Collaborator> _originalCollaborators = [];
  bool _loading = true;
  bool _saving = false;
  bool _lookingUp = false;
  String? _emailError;
  String? _addError;

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCollaborators() async {
    setState(() => _loading = true);
    final result = await _svc.getTaskCollaborators(widget.taskId);
    if (!mounted) return;
    setState(() {
      if (result != null) {
        _owner = result.owner;
        _collaborators = List.from(result.collaborators);
        _originalCollaborators = List.from(result.collaborators);
      } else {
        final me = _svc.currentUserAsCollaborator;
        _owner = me;
        _collaborators = [];
        _originalCollaborators = [];
      }
      _loading = false;
    });
  }

  bool get _hasChanges {
    if (_collaborators.length != _originalCollaborators.length) return true;
    for (int i = 0; i < _collaborators.length; i++) {
      if (_collaborators[i].uid != _originalCollaborators[i].uid) return true;
    }
    return false;
  }

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return null;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    final myUid = _svc.currentUid;
    if (_owner?.uid == myUid && _owner?.email.toLowerCase() == email.toLowerCase()) {
      return 'You cannot add yourself as a collaborator';
    }
    if (_collaborators.any((c) => c.email.toLowerCase() == email.toLowerCase())) {
      return 'This person is already a collaborator';
    }
    return null;
  }

  Future<void> _addCollaborator() async {
    final email = _emailController.text.trim();
    final error = _validateEmail(email);
    if (error != null) {
      setState(() => _emailError = error);
      return;
    }
    if (email.isEmpty) return;

    setState(() {
      _lookingUp = true;
      _emailError = null;
      _addError = null;
    });

    try {
      final appUser = await _svc.findUserByEmail(email);
      if (!mounted) return;

      if (appUser == null) {
        setState(() {
          _lookingUp = false;
          _addError = 'No user found with this email. They need to sign up first.';
        });
        return;
      }

      if (_collaborators.any((c) => c.uid == appUser.uid)) {
        setState(() {
          _lookingUp = false;
          _emailError = 'This person is already a collaborator';
        });
        return;
      }

      final collaborator = Collaborator(
        uid: appUser.uid,
        email: appUser.email,
        name: appUser.displayName,
        photoUrl: appUser.photoUrl,
      );

      setState(() {
        _collaborators.add(collaborator);
        _emailController.clear();
        _lookingUp = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${collaborator.name} added as collaborator'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookingUp = false;
        _addError = 'Failed to find user. Please try again.';
      });
    }
  }

  void _removeCollaborator(Collaborator collaborator) {
    setState(() {
      _collaborators.removeWhere((c) => c.uid == collaborator.uid);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${collaborator.name} removed'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    if (_owner == null) return;
    setState(() => _saving = true);

    final success = await _svc.saveTaskCollaborators(
      taskId: widget.taskId,
      owner: _owner!,
      collaborators: _collaborators,
    );

    if (!mounted) return;

    // For each collaborator, create an accountability task so they see
    // it in their Partners tab (via myTasksStream → where accountableUid).
    // This is the missing link between collaborator assignment and
    // the accountability system.
    if (success && widget.taskName != null) {
      final myUid = _svc.currentUid;
      debugPrint('[CollaboratorDialog] Creating accountability tasks for ${_collaborators.length} collaborator(s)');
      for (final c in _collaborators) {
        if (c.uid == myUid) continue; // skip self
        try {
          // Ensure an accepted partnership exists (creates one if needed)
          final partnershipId = await _svc.ensurePartnership(c.uid, c.name);
          if (partnershipId != null) {
            debugPrint('[CollaboratorDialog] Using partnership: $partnershipId');
          } else {
            debugPrint('[CollaboratorDialog] Failed to ensure partnership for ${c.uid}');
          }

          // Skip if an active accountability task already exists for this challengeId
          final existing = await _svc.fetchTaskByChallengeId(widget.taskId);
          if (existing != null &&
              existing.status != AccountabilityTaskStatus.declined &&
              existing.status != AccountabilityTaskStatus.completed) {
            debugPrint('[CollaboratorDialog] Active task already exists: ${existing.id} — skipping');
            continue;
          }

          final task = await _svc.createAccountabilityTask(
            accountableUid: c.uid,
            accountableName: c.name,
            partnershipId: partnershipId ?? '',
            title: widget.taskName!,
            description: 'Collaborator task from Daily Mettle',
            challengeId: widget.taskId,
          );
          if (task != null) {
            debugPrint('[CollaboratorDialog] Created accountability task:');
            debugPrint('  collaboratorUid:   ${c.uid}');
            debugPrint('  assignedByUid:     ${task.assignedByUid}');
            debugPrint('  accountableUid:    ${task.accountableUid}');
            debugPrint('  task document ID:  ${task.id}');
          } else {
            debugPrint('[CollaboratorDialog] FAILED to create accountability task for ${c.uid}');
          }
        } catch (e) {
          debugPrint('[CollaboratorDialog] Error creating task for ${c.uid}: $e');
        }
      }
    }

    setState(() => _saving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Collaborators saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save collaborators. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancel() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('You have unsaved changes to collaborators.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep editing'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Discard', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else ...[
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildOwnerSection(),
                    if (_collaborators.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildCollaboratorsList(),
                    ],
                    const SizedBox(height: 16),
                    _buildAddSection(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Collaborators',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.taskName != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                widget.taskName!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          IconButton(
            onPressed: _cancel,
            icon: const Icon(Icons.close),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSection() {
    if (_owner == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          CollaboratorDialog.buildAvatar(_owner!, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _owner!.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _owner!.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Owner',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_collaborators.length} collaborator${_collaborators.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ..._collaborators.map(_buildCollaboratorTile),
      ],
    );
  }

  Widget _buildCollaboratorTile(Collaborator collaborator) {
    final myUid = _svc.currentUid;
    final isOwner = collaborator.uid == _owner?.uid;
    final canRemove = !isOwner && collaborator.uid != myUid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          CollaboratorDialog.buildAvatar(collaborator, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collaborator.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  collaborator.email,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              onPressed: () => _removeCollaborator(collaborator),
              icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 16,
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }

  Widget _buildAddSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          enabled: !_lookingUp,
          decoration: InputDecoration(
            hintText: 'Person or email to share with',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.person_add_outlined,
                color: Colors.grey[400], size: 20),
            suffixIcon: _lookingUp
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            errorText: _emailError,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 14),
          onSubmitted: (_) => _addCollaborator(),
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        if (_addError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red[400]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _addError!,
                    style: TextStyle(fontSize: 12, color: Colors.red[400]),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _lookingUp ? null : _addCollaborator,
            icon: Icon(Icons.person_add_alt_1,
                size: 18, color: AppColors.primary),
            label: Text(
              'Add collaborator',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : _cancel,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: (_saving || _loading) ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

}
