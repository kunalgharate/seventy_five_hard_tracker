import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/core/services/connectivity_service.dart';
import 'package:seventy_five_hard_tracker/core/services/offline_task_outbox.dart';
import 'package:seventy_five_hard_tracker/core/utils/text_helpers.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/app_user.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/presentation/bloc/regular_task_event.dart';
import 'package:seventy_five_hard_tracker/widgets/regular_tasks/regular_task_sheet_helpers.dart';

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

class _CreateTaskSheetState extends State<CreateTaskSheet>
    with RegularTaskSheetHelpers {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _taskType = 'hard'; // 'hard' or 'regular'
  AppUser? _selectedReviewer;
  String? _selectedPartnershipId;
  bool _lookingUp = false;
  bool _creating = false;
  String? _emailError;
  String? _titleError;

  /// Recipient is not registered yet — assign the task by email and send
  /// them a partnership invitation in the same step.
  bool _emailInviteOnly = false;
  String? _emailInfo;

  /// Existing partners, shown first so a task can be assigned to a friend
  /// without typing anything.
  List<AccountabilityPartner> _partners = [];
  bool _loadingPartners = true;

  /// Draft holding the 75-Hard reminder choice. Squad-created 75-Hard tasks
  /// require a reminder (same rule as ChallengeTaskSheet); routine tasks
  /// keep reminders optional so this stays untouched for 'regular'.
  Challenge _hardReminder = const Challenge(
    id: 'squad-draft',
    title: '',
    taskType: 'hard',
    category: 'general',
  );

  @override
  Challenge get sheetChallenge => _hardReminder;
  @override
  set sheetChallenge(Challenge value) => _hardReminder = value;

  bool get _hasHardReminder =>
      _hardReminder.isReminderEnabled && _hardReminder.reminderTime != null;

  final _svc = AccountabilityService();

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    try {
      final all = await _svc.fetchMyPartnerships();
      if (!mounted) return;
      setState(() {
        // Accepted partners first, then pending invites (still assignable —
        // the task waits for them to accept). Declined are hidden.
        _partners = all
            .where((p) =>
                p.status != PartnershipStatus.declined &&
                (p.uidOf(_svc.currentUid) ?? '').isNotEmpty)
            .toList()
          ..sort((a, b) {
            final ra = a.status == PartnershipStatus.accepted ? 0 : 1;
            final rb = b.status == PartnershipStatus.accepted ? 0 : 1;
            if (ra != rb) return ra - rb;
            return b.createdAt.compareTo(a.createdAt);
          });
        _loadingPartners = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPartners = false);
    }
  }

  void _selectPartner(AccountabilityPartner p) {
    final uid = p.uidOf(_svc.currentUid) ?? '';
    if (uid.isEmpty) return;
    setState(() {
      _selectedReviewer = AppUser(
        uid: uid,
        email: p.emailOf(_svc.currentUid) ?? '',
        displayName: p.displayName,
        createdAt: p.acceptedAt ?? p.createdAt,
      );
      _selectedPartnershipId = p.id;
      _emailInviteOnly = false;
      _emailInfo = null;
      _emailError = null;
    });
  }

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
      setState(() {
        _selectedReviewer = null;
        _selectedPartnershipId = null;
      });
      return;
    }
    if (!email.contains('@')) {
      setState(() => _emailError = 'Enter a valid email');
      return;
    }
    setState(() {
      _lookingUp = true;
      _emailError = null;
      _emailInfo = null;
      _emailInviteOnly = false;
    });
    try {
      // Partners I already added resolve from my partnerships even when their
      // `users` doc is missing; unknown emails fall back to the users lookup.
      final user = await _svc.findPartnerByEmail(email);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _lookingUp = false;
          _emailInviteOnly = true;
          _emailInfo = 'Not on DailyMettle yet — we\'ll invite them and assign '
              'this task to that email. They\'ll see it after they join.';
        });
      } else {
        setState(() {
          _lookingUp = false;
          _emailInviteOnly = false;
          _selectedReviewer = user;
          _selectedPartnershipId = null;
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
    final title = sanitizeTaskName(_titleCtrl.text);
    final validationError = validateTaskName(title);
    if (validationError != null) {
      setState(() => _titleError = validationError);
      return;
    }
    // 75-Hard tasks require a reminder before saving (mirrors the
    // ChallengeTaskSheet gate). Routine-task reminders stay optional.
    if (_taskType == 'hard' && !_hasHardReminder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a reminder before saving this task'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _titleError = null;
      _creating = true;
    });
    final senderUid = _svc.currentUid;

    try {
      // Connectivity snapshot: drives the offline fallback paths below.
      final offline = !await ConnectivityService().hasInternet();
      if (!mounted) return;
      if (offline && _emailInviteOnly) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'You\'re offline — assigning a task by email needs internet. Try again when reconnected.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String? partnershipId;
      String accountableUid = _svc.currentUid ?? '';
      String accountableName = _svc.currentUserDisplayName;
      String? reviewerUid;
      String? accountableEmail;
      var queuedOffline = false;

      // If reviewer selected, create partnership + task with reviewer
      if (_selectedReviewer != null) {
        if (offline) {
          partnershipId = _selectedPartnershipId;
          queuedOffline = true;
        } else {
          _assertSenderUnchanged(senderUid);
          try {
            partnershipId = await _svc.ensurePartnership(
              _selectedReviewer!.uid,
              _selectedReviewer!.displayName,
            );
          } catch (e) {
            if (await ConnectivityService().hasInternet()) rethrow;
            partnershipId = _selectedPartnershipId;
            queuedOffline = true;
          }
          _assertSenderUnchanged(senderUid);
        }
        reviewerUid = _selectedReviewer!.uid;
      } else if (_emailInviteOnly) {
        // ── Direct assignment by email (teacher / manager / coach) ──
        // Invite them and address the task to that email in one step. They
        // will see "invited you to review this task" once they join.
        final email = _emailCtrl.text.trim().toLowerCase();
        if (!email.contains('@')) {
          setState(() {
            _creating = false;
            _emailError = 'Enter a valid email';
          });
          return;
        }
        final invite = await _svc.sendEmailInvite(
          toEmail: email,
          role: PartnerRole.mentorCoach,
        );
        partnershipId = invite.partnershipId;
        accountableUid = '';
        accountableName = email;
        accountableEmail = email;
      }

      // ── Routine tasks must appear in the Habits tab ──
      // Create a local RegularTask so it shows up under "Your habits",
      // not only as an accountability task.
      if (_taskType == 'regular') {
        final regularTask = RegularTask(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          category: 'general',
          reminderType: 'once',
          isReminderEnabled: false,
          createdAt: DateTime.now(),
        );
        if (mounted) {
          context.read<RegularTaskBloc>().add(AddRegularTask(regularTask));
        }
      }

      // ── 75 Hard tasks must appear on Today's screen ──
      // Register the task as a real challenge in the active session so it
      // shows up immediately on the home screen (and on the partner's side
      // once the accountability task is accepted).
      String? challengeId;
      if (_taskType == 'hard') {
        if (!mounted) return;
        // Check the repository directly: AddChallengeToSession silently does
        // nothing when there is no active session, and the bloc's state may
        // not have loaded yet even though a session exists.
        final session =
            await context.read<ChallengeBloc>().repository.getActiveSession();
        if (!mounted) return;
        if (session == null) {
          setState(() => _creating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Start your 75 Hard challenge first, then add the task.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        challengeId = DateTime.now().millisecondsSinceEpoch.toString();
        context.read<ChallengeBloc>().add(
              AddChallengeToSession(
                Challenge(
                  id: challengeId,
                  title: title,
                  taskType: 'hard',
                  category: 'general',
                  // Reminder was gated above, so scheduling (in the bloc)
                  // picks this task up exactly like ChallengeSheet tasks.
                  // Only today's DailyProgress is touched — past days are
                  // never backfilled, so mid-challenge adds don't mark
                  // earlier days missed.
                  reminderTime: _hardReminder.reminderTime,
                  isReminderEnabled: true,
                  reminderType: _hardReminder.reminderType,
                  reminderStartHour: _hardReminder.reminderStartHour,
                  reminderEndHour: _hardReminder.reminderEndHour,
                  allowNightReminders: _hardReminder.allowNightReminders,
                  reminderIntervalMinutes:
                      _hardReminder.reminderIntervalMinutes,
                ),
              ),
            );
      }

      // Create an accountability task only when a reviewer was chosen.
      // A self-assigned task is invisible in the Squad and would show up
      // as a bogus "request for you", so a plain personal task is just the
      // challenge (75 Hard) or the habit (Routine) created above.
      bool ok = true;
      final hasReviewer = _selectedReviewer != null || _emailInviteOnly;
      Future<void> enqueueOfflineTask() async {
        _assertSenderUnchanged(senderUid);
        await OfflineTaskOutbox.instance.enqueue({
          'senderUid': senderUid,
          'accountableUid': accountableUid,
          'accountableName': accountableName,
          'partnershipId': partnershipId ?? '',
          'title': title,
          'description': _descCtrl.text.trim(),
          'challengeId': challengeId,
          'partnerUid': reviewerUid,
          'taskType': _taskType == 'regular' ? 'regular' : 'hard',
        });
      }

      if (hasReviewer) {
        if (queuedOffline && _selectedReviewer != null) {
          await enqueueOfflineTask();
          queuedOffline = true;
          ok = true;
        } else {
          _assertSenderUnchanged(senderUid);
          final created = await _svc.createAccountabilityTask(
            accountableUid: accountableUid,
            accountableName: accountableName,
            accountableEmail: accountableEmail,
            partnershipId: partnershipId ?? '',
            title: title,
            description: _descCtrl.text.trim(),
            challengeId: challengeId,
            partnerUid: reviewerUid,
            // taskType is persisted as 'hard' unless this is a routine task
            taskType: _taskType == 'regular' ? 'regular' : null,
          );
          _assertSenderUnchanged(senderUid);
          if (created == null &&
              _selectedReviewer != null &&
              !await ConnectivityService().hasInternet()) {
            await enqueueOfflineTask();
            queuedOffline = true;
            ok = true;
          } else {
            ok = created != null;
          }
        }
      }

      if (!mounted) return;
      setState(() => _creating = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(queuedOffline
                ? 'Saved offline — "${_selectedReviewer!.displayName}" '
                    'will be asked to review when you\'re back online.'
                : _emailInviteOnly
                    ? 'Task assigned to ${_emailCtrl.text.trim()} — '
                        'they\'ll accept it after they join.'
                    : _selectedReviewer != null
                        ? 'Task created! ${_selectedReviewer!.displayName} '
                            'will be asked to review.'
                        : _taskType == 'regular'
                            ? 'Routine task added to your Habits!'
                            : 'Task added to today\'s challenge!'),
            backgroundColor: queuedOffline ? Colors.orange : Colors.green,
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

  void _assertSenderUnchanged(String? senderUid) {
    if (senderUid == null ||
        senderUid.isEmpty ||
        _svc.currentUid != senderUid) {
      throw StateError(
          'Your signed-in account changed while creating the task.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // All colors come from the active Theme so the sheet stays readable in
    // both light and dark mode — never hard-code white/black text here.
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cardBg = scheme.surface;
    final textColor = scheme.onSurface;
    final fieldFill = theme.inputDecorationTheme.fillColor ?? scheme.surface;

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
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
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
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // ── Task type selector ──
            Text(
              'Task Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
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

            // ── Reminder (required for 75 Hard, optional for Routine) ──
            if (_taskType == 'hard') ...[
              GestureDetector(
                onTap: showReminderSetup,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _hasHardReminder
                        ? Colors.orange.withValues(alpha: 0.08)
                        : Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasHardReminder
                          ? Colors.orange.withValues(alpha: 0.4)
                          : Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasHardReminder ? Icons.alarm_on : Icons.alarm_add,
                        size: 18,
                        color: _hasHardReminder
                            ? Colors.orange[700]
                            : Colors.red[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hasHardReminder
                              ? 'Reminder Set'
                              : 'Set Reminder (Required)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _hasHardReminder
                                ? Colors.orange[800]
                                : Colors.red[700],
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 18,
                          color: _hasHardReminder
                              ? Colors.orange[400]
                              : Colors.red[400]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Task name ──
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Task name *',
                hintText: 'e.g. 45 minute workout',
                errorText: _titleError,
                prefixIcon: const Icon(Icons.task_alt),
                filled: true,
                fillColor: fieldFill,
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                prefixIconColor: scheme.onSurfaceVariant,
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
                filled: true,
                fillColor: fieldFill,
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                prefixIconColor: scheme.onSurfaceVariant,
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
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tasks without a reviewer complete normally.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),

            if (_selectedReviewer != null)
              _buildSelectedReviewer()
            else ...[
              // ── Existing partners first ──
              if (!_loadingPartners && _partners.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.group_outlined,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No partners yet — invite one below, or share your '
                          'invite code from the Squad screen.',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_loadingPartners && _partners.isNotEmpty) ...[
                Text(
                  'Your partners',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ..._partners.map(_buildPartnerTile),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Divider(color: scheme.outline)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'or invite someone new',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Expanded(child: Divider(color: scheme.outline)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
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
                        filled: true,
                        fillColor: fieldFill,
                        hintStyle: TextStyle(
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        prefixIconColor: scheme.onSurfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      style: TextStyle(color: textColor, fontSize: 14),
                      onSubmitted: (_) => _lookupReviewer(),
                      onChanged: (_) {
                        if (_emailError != null || _emailInviteOnly) {
                          setState(() {
                            _emailError = null;
                            _emailInfo = null;
                            _emailInviteOnly = false;
                          });
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
            ],
            if (_emailInviteOnly && _emailInfo != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mail_lock_outlined,
                        size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _emailInfo!,
                        style: TextStyle(fontSize: 12, color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                        _emailInviteOnly
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
    final scheme = Theme.of(context).colorScheme;
    final selected = _taskType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _taskType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : scheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedReviewer() {
    final scheme = Theme.of(context).colorScheme;
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
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _selectedReviewer = null;
              _selectedPartnershipId = null;
              _emailCtrl.clear();
            }),
            icon: const Icon(Icons.close, size: 18),
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerTile(AccountabilityPartner p) {
    final scheme = Theme.of(context).colorScheme;
    final name = p.displayName;
    final email = p.emailOf(_svc.currentUid) ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _selectPartner(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.withValues(alpha: 0.12),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (p.status == PartnershipStatus.pending)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
