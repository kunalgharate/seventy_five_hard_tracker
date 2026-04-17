import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/challenge.dart';

/// Reusable reminder configuration bottom sheet
/// Matches the full-featured reminder UI from daily_task_card
class ReminderBottomSheet extends StatefulWidget {
  final Challenge challenge;
  final Function(Challenge) onSave;

  const ReminderBottomSheet({
    super.key,
    required this.challenge,
    required this.onSave,
  });

  @override
  State<ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<ReminderBottomSheet> {
  late bool _enabled;
  late String _type;
  late String _time;
  late int _intervalMinutes;
  late List<String> _customTimes;

  @override
  void initState() {
    super.initState();
    _enabled = widget.challenge.isReminderEnabled;
    _type = 'once';
    _time = '09:00';
    _intervalMinutes = 120;
    _customTimes = ['09:00', '18:00'];

    if (widget.challenge.reminderTime != null) {
      final data = widget.challenge.reminderTime!;
      _time = _extractDisplayTime(data);

      if (data.startsWith('once:')) {
        _type = 'once';
      } else if (data.startsWith('multiple:')) {
        _type = 'multiple';
        _customTimes = data.substring(9).split(',');
      } else if (data.startsWith('hourly:')) {
        _type = 'hourly';
      } else if (data.startsWith('interval:')) {
        _type = 'interval';
        final parts = data.substring(9).split(':');
        _intervalMinutes = int.parse(parts[0]);
      } else if (data.startsWith('custom:')) {
        _type = 'custom';
        _customTimes = data.substring(7).split(',');
      } else {
        _time = data;
      }
    }
  }

  String _extractDisplayTime(String data) {
    if (data.startsWith('once:')) return data.substring(5);
    if (data.startsWith('multiple:')) return data.substring(9).split(',').first;
    if (data.startsWith('hourly:')) return data.substring(7);
    if (data.startsWith('interval:')) {
      final parts = data.substring(9).split(':');
      return '${parts[1]}:${parts[2]}';
    }
    if (data.startsWith('custom:')) return data.substring(7).split(',').first;
    return data;
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    return DateFormat('h:mm a').format(
      DateTime(2024, 1, 1, int.parse(parts[0]), int.parse(parts[1])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.notifications, color: Colors.orange[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set Reminder',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToggle(),
                  if (_enabled) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Reminder Type',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _buildTypeOption(
                        'once',
                        'Once',
                        'Single reminder at specific time',
                        Icons.schedule_outlined),
                    _buildTypeOption('multiple', 'Multiple Times',
                        'Several reminders throughout the day', Icons.schedule),
                    _buildTypeOption(
                        'hourly',
                        'Every Hour',
                        'Hourly reminders during active hours',
                        Icons.access_time),
                    _buildTypeOption('interval', 'Every X Hours',
                        'Regular intervals (15 min - 12 hours)', Icons.timer),
                    _buildTypeOption('custom', 'Custom Schedule',
                        'Flexible timing for any pattern', Icons.tune),
                    const SizedBox(height: 20),
                    if (_type == 'once')
                      _buildTimeSelector('Reminder Time', _time,
                          (t) => setState(() => _time = t)),
                    if (_type == 'multiple')
                      _buildMultipleTimeSelector('Reminder Times', _customTimes,
                          (t) => setState(() => _customTimes = t)),
                    if (_type == 'hourly') _buildHourlyConfig(),
                    if (_type == 'interval') _buildIntervalConfig(),
                    if (_type == 'custom')
                      _buildMultipleTimeSelector('Custom Times', _customTimes,
                          (t) => setState(() => _customTimes = t)),
                  ] else ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Enable reminders to configure settings',
                            style: GoogleFonts.inter(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _enabled ? 'Save Reminder Settings' : 'Disable Reminder',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications, color: Colors.orange[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Reminders',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Get notified for this task',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (v) => setState(() {
              _enabled = v;
              if (v && _time.isEmpty) _time = '09:00';
            }),
            activeThumbColor: Colors.orange[600],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
      String value, String title, String subtitle, IconData icon) {
    final isSelected = _type == value;
    return GestureDetector(
      onTap: () => setState(() {
        _type = value;
        if (value == 'multiple' && _customTimes.length < 2) {
          _customTimes = ['09:00', '18:00'];
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.orange[300]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? Colors.orange[600] : Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.orange[700] : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.orange[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(
      String title, String currentTime, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: () async {
            final parts = currentTime.split(':');
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                  hour: int.parse(parts[0]), minute: int.parse(parts[1])),
            );
            if (picked != null) {
              onChanged(
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.orange[600]),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                  _formatTime(currentTime),
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500),
                )),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.grey[400], size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleTimeSelector(
      String title, List<String> times, Function(List<String>) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                    context: context, initialTime: TimeOfDay.now());
                if (picked != null) {
                  final t =
                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                  if (!times.contains(t)) onChanged([...times, t]..sort());
                }
              },
              icon: Icon(Icons.add, size: 16, color: Colors.orange[600]),
              label: Text('Add Time',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.orange[600],
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...times.map((timeStr) {
          final parts = timeStr.split(':');
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  _formatTime(timeStr),
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500),
                )),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1])),
                    );
                    if (picked != null) {
                      final t =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      final newTimes = [...times];
                      newTimes[times.indexOf(timeStr)] = t;
                      onChanged(newTimes..sort());
                    }
                  },
                  child: Icon(Icons.edit, size: 16, color: Colors.orange[600]),
                ),
                if (times.length > 1) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onChanged([...times]..remove(timeStr)),
                    child: Icon(Icons.close, size: 16, color: Colors.red[600]),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHourlyConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeSelector(
            'Start Time', _time, (t) => setState(() => _time = t)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[600], size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Hourly reminders will continue until 10:00 PM or when you mark the task as complete',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[700]),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Interval',
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildIntervalChip('15 min', 15),
            _buildIntervalChip('30 min', 30),
            _buildIntervalChip('1 hour', 60),
            _buildIntervalChip('2 hours', 120),
            _buildIntervalChip('3 hours', 180),
            _buildIntervalChip('4 hours', 240),
            _buildIntervalChip('6 hours', 360),
            _buildIntervalChip('8 hours', 480),
            _buildIntervalChip('12 hours', 720),
          ],
        ),
        const SizedBox(height: 16),
        _buildTimeSelector(
            'Start Time', _time, (t) => setState(() => _time = t)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[600], size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                _intervalMinutes < 60
                    ? 'Reminder every $_intervalMinutes minutes until task is completed'
                    : 'Reminder every ${(_intervalMinutes / 60).round()} hour${_intervalMinutes > 60 ? 's' : ''} until task is completed',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.blue[700]),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalChip(String label, int minutes) {
    final isSelected = _intervalMinutes == minutes;
    return GestureDetector(
      onTap: () => setState(() => _intervalMinutes = minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[600] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected ? Colors.orange[600]! : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _save() {
    String? reminderData;
    if (_enabled) {
      switch (_type) {
        case 'once':
          reminderData = 'once:$_time';
          break;
        case 'multiple':
          reminderData = 'multiple:${_customTimes.join(',')}';
          break;
        case 'hourly':
          reminderData = 'hourly:$_time';
          break;
        case 'interval':
          reminderData = 'interval:$_intervalMinutes:$_time';
          break;
        case 'custom':
          reminderData = 'custom:${_customTimes.join(',')}';
          break;
      }
    }

    final updated = widget.challenge.copyWith(
      isReminderEnabled: _enabled,
      reminderTime: _enabled ? reminderData : null,
    );
    widget.onSave(updated);
    Navigator.pop(context);
  }
}
