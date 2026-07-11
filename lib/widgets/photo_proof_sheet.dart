import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:seventy_five_hard_tracker/core/services/photo_sync_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/main.dart';

class PhotoProofSheet extends StatefulWidget {
  final String taskId;
  final String taskName;
  final DateTime date;

  const PhotoProofSheet({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.date,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String taskId,
    required String taskName,
    required DateTime date,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhotoProofSheet(
        taskId: taskId,
        taskName: taskName,
        date: date,
      ),
    );
  }

  @override
  State<PhotoProofSheet> createState() => _PhotoProofSheetState();
}

class _PhotoProofSheetState extends State<PhotoProofSheet> {
  final _photoService = PhotoSyncService();
  final _svc = AccountabilityService();

  bool _uploading = false;
  String? _proofUrl;
  String? _error;

  Future<void> _pickPhoto(bool fromCamera) async {
    setState(() {
      _error = null;
      _uploading = true;
    });

    if (kDebugMode) {
      debugPrint('[PhotoProofSheet] _pickPhoto: fromCamera=$fromCamera taskId=${widget.taskId}');
    }

    try {
      final file = await _photoService.pickPhoto(fromCamera: fromCamera);
      if (file == null) {
        if (kDebugMode) {
          debugPrint('[PhotoProofSheet] _pickPhoto: no file selected (null)');
        }
        setState(() => _uploading = false);
        return;
      }

      if (kDebugMode) {
        debugPrint('[PhotoProofSheet] _pickPhoto: file path=${file.path}');
        debugPrint('[PhotoProofSheet] _pickPhoto: calling uploadPhoto...');
      }

      final url = await _photoService.uploadPhoto(
        file,
        widget.taskId,
        widget.date,
      );

      if (kDebugMode) {
        debugPrint('[PhotoProofSheet] _pickPhoto: uploadPhoto returned url=$url');
      }

      if (!mounted) return;

      if (url == null) {
        if (kDebugMode) {
          debugPrint('[PhotoProofSheet] _pickPhoto: url is null — upload failed');
        }
        setState(() {
          _uploading = false;
          _error = 'Failed to upload photo. Please try again.';
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('[PhotoProofSheet] _pickPhoto: upload succeeded, url=$url');
      }

      setState(() {
        _proofUrl = url;
        _uploading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PhotoProofSheet] _pickPhoto: exception caught — $e');
      }
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _submitProof() async {
    if (_proofUrl == null) {
      if (kDebugMode) {
        debugPrint('[PhotoProofSheet] _submitProof: _proofUrl is null, aborting');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[PhotoProofSheet] _submitProof: taskId=${widget.taskId} proofUrl=$_proofUrl');
    }

    setState(() => _uploading = true);

    final success = await _svc.submitTaskProof(
      taskId: widget.taskId,
      proofUrl: _proofUrl!,
    );

    if (kDebugMode) {
      debugPrint('[PhotoProofSheet] _submitProof: submitTaskProof returned $success');
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof submitted for review'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _uploading = false;
        _error = 'Failed to submit proof. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Submit Photo Proof',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.taskName,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),

          if (_proofUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _proofUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
                      const SizedBox(height: 8),
                      Text('Failed to load image',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                const SizedBox(width: 6),
                Text(
                  'Photo uploaded successfully',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Image picker buttons
            Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: _uploading ? null : () => _pickPhoto(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: _uploading ? null : () => _pickPhoto(false),
                  ),
                ),
              ],
            ),
          ],

          if (_uploading && _proofUrl == null) ...[
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Uploading photo...',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _uploading ? null : () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.grey[600])),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_proofUrl != null && !_uploading)
                      ? _submitProof
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Proof',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
