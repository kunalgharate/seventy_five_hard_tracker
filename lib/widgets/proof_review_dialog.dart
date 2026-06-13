import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/main.dart';

class ProofReviewDialog extends StatefulWidget {
  final AccountabilityTask task;

  const ProofReviewDialog({super.key, required this.task});

  static Future<bool?> show(BuildContext context, AccountabilityTask task) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ProofReviewDialog(task: task),
    );
  }

  @override
  State<ProofReviewDialog> createState() => _ProofReviewDialogState();
}

class _ProofReviewDialogState extends State<ProofReviewDialog> {
  final _svc = AccountabilityService();
  bool _processing = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _review({required bool approved}) async {
    setState(() => _processing = true);
    final success = await _svc.reviewTaskProof(
      taskId: widget.task.id,
      approved: approved,
      comment:
          _commentController.text.isNotEmpty ? _commentController.text : null,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Proof approved — task completed'
                : 'Proof rejected — task reopened',
          ),
          backgroundColor: approved ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit review. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review Photo Proof',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.task.title.isNotEmpty ? widget.task.title : 'Untitled Task',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),

            if (widget.task.proofUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.task.proofUrl!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 220,
                      color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    color: Colors.grey[100],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Failed to load image',
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle: TextStyle(color: Colors.grey[400]),
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
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : () => _review(approved: false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[600],
                      side: BorderSide(color: Colors.red[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : () => _review(approved: true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
