import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DailyJournalWidget extends StatefulWidget {
  final DateTime selectedDate;
  final String? existingNote;
  final Function(String) onNoteSubmitted;
  final bool isEditable;

  const DailyJournalWidget({
    super.key,
    required this.selectedDate,
    this.existingNote,
    required this.onNoteSubmitted,
    this.isEditable = true,
  });

  @override
  State<DailyJournalWidget> createState() => _DailyJournalWidgetState();
}

class _DailyJournalWidgetState extends State<DailyJournalWidget> {
  late TextEditingController _controller;
  bool _isExpanded = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingNote ?? '');
    _controller.addListener(_onTextChanged);
    
    // Always expand all journal entries (both current and previous days)
    _isExpanded = true;
  }

  @override
  void didUpdateWidget(DailyJournalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Keep all journal entries expanded when date changes
    if (widget.selectedDate != oldWidget.selectedDate) {
      _isExpanded = true; // Always expanded for all days
    }
    
    if (widget.existingNote != oldWidget.existingNote) {
      _controller.text = widget.existingNote ?? '';
      _hasUnsavedChanges = false;
    }
  }

  void _onTextChanged() {
    final hasChanges = _controller.text.trim() != (widget.existingNote ?? '').trim();
    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  void _saveNote() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onNoteSubmitted(_controller.text.trim());
      setState(() {
        _hasUnsavedChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Journal entry saved!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearNote() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear Journal Entry',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to clear this journal entry?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _controller.clear();
                _hasUnsavedChanges = true;
              });
            },
            child: Text(
              'Clear',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().day == widget.selectedDate.day &&
        DateTime.now().month == widget.selectedDate.month &&
        DateTime.now().year == widget.selectedDate.year;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFA726).withOpacity(0.1),
                  const Color(0xFFFF7043).withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA726),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Journal',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(widget.selectedDate),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.existingNote?.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Saved',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                // Show edit/view indicator instead of expand/collapse
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isEditable ? Colors.blue[100] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.isEditable ? 'Edit' : 'View',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: widget.isEditable ? Colors.blue[700] : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content - Always visible
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isEditable && widget.existingNote?.isEmpty == true)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'No journal entry for this date',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!widget.isEditable)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      widget.existingNote!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday 
                            ? 'How was your day? What did you learn?'
                            : 'Journal entry for ${DateFormat('MMM d').format(widget.selectedDate)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        maxLines: 5,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: isToday
                              ? 'Reflect on your progress, challenges, and victories...'
                              : 'Add your thoughts for this day...',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFFFA726), width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _hasUnsavedChanges ? _saveNote : null,
                              icon: const Icon(Icons.save, size: 18),
                              label: Text(
                                'Save Entry',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasUnsavedChanges 
                                    ? const Color(0xFFFFA726)
                                    : Colors.grey[300],
                                foregroundColor: _hasUnsavedChanges 
                                    ? Colors.white
                                    : Colors.grey[600],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _controller.text.isNotEmpty ? _clearNote : null,
                            icon: const Icon(Icons.clear, size: 18),
                            label: Text(
                              'Clear',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _controller.text.isNotEmpty 
                                  ? Colors.red[600]
                                  : Colors.grey[400],
                              side: BorderSide(
                                color: _controller.text.isNotEmpty 
                                    ? Colors.red[300]!
                                    : Colors.grey[300]!,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
