import 'dart:convert';

/// One journal entry inside a day.
///
/// Storage: a day's `journalNote` holds all of its entries — each entry is
/// JSON-encoded and entries are joined with ␞ (`\u241E`, record separator).
/// Legacy notes without ␞ decode to a single entry using the old
/// `mood|text` + optional `␟proud` format, so old data keeps working.
class JournalEntry {
  /// Unique id (milliseconds-since-epoch string by default).
  final String id;
  final DateTime createdAt;
  final String? mood;
  final String text;
  final String proud;

  const JournalEntry({
    required this.id,
    required this.createdAt,
    this.mood,
    required this.text,
    this.proud = '',
  });

  /// Fresh entry with a unique id for "now".
  factory JournalEntry.now(
      {String? mood, String text = '', String proud = ''}) {
    final at = DateTime.now();
    return JournalEntry(
      id: '${at.millisecondsSinceEpoch}',
      createdAt: at,
      mood: mood,
      text: text,
      proud: proud,
    );
  }

  bool get isEmpty =>
      text.trim().isEmpty && proud.trim().isEmpty && (mood ?? '').isEmpty;

  JournalEntry copyWith({String? mood, String? text, String? proud}) {
    return JournalEntry(
      id: id,
      createdAt: createdAt,
      mood: mood ?? this.mood,
      text: text ?? this.text,
      proud: proud ?? this.proud,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        't': createdAt.millisecondsSinceEpoch,
        'm': mood,
        'x': text,
        'p': proud,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final t = json['t'] as int?;
    return JournalEntry(
      id: json['id'] as String? ??
          '${t ?? DateTime.now().millisecondsSinceEpoch}',
      createdAt:
          t != null ? DateTime.fromMillisecondsSinceEpoch(t) : DateTime.now(),
      mood: json['m'] as String?,
      text: json['x'] as String? ?? '',
      proud: json['p'] as String? ?? '',
    );
  }

  /// Record separator joining encoded entries. Never typed by users.
  static const String sep = '\u241E';

  /// Decode a stored day-note into its entries (newest last).
  /// Empty/blank notes decode to []. Legacy single notes decode to one entry
  /// stamped with [fallbackDate].
  static List<JournalEntry> decode(String? note,
      {required DateTime fallbackDate}) {
    if (note == null || note.trim().isEmpty) return [];
    if (!note.contains(sep)) {
      final single = _parseSingle(note);
      if (single != null) return single.isEmpty ? [] : [single];
      final legacy = _parseLegacy(note);
      final legacyEmpty = legacy.text.trim().isEmpty &&
          (legacy.mood ?? '').isEmpty &&
          legacy.proud.trim().isEmpty;
      if (legacyEmpty) return [];
      return [
        JournalEntry(
          id: 'legacy-${fallbackDate.millisecondsSinceEpoch}',
          createdAt: fallbackDate,
          mood: legacy.mood,
          text: legacy.text,
          proud: legacy.proud,
        )
      ];
    }
    final entries = <JournalEntry>[];
    for (final part in note.split(sep)) {
      if (part.trim().isEmpty) continue;
      try {
        final map = jsonDecode(part) as Map<String, dynamic>;
        final entry = JournalEntry.fromJson(map);
        if (!entry.isEmpty) entries.add(entry);
      } catch (_) {
        // One corrupt entry must never kill the whole day.
      }
    }
    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  /// Encode entries for storage. Empty list encodes to ''.
  static String encode(List<JournalEntry> entries) {
    final kept = entries.where((e) => !e.isEmpty).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return kept.map((e) => jsonEncode(e.toJson())).join(sep);
  }

  /// Parse a standalone JSON-encoded entry, or null if [note] isn't one.
  static JournalEntry? _parseSingle(String note) {
    try {
      final map = jsonDecode(note);
      if (map is! Map<String, dynamic> || !map.containsKey('id')) return null;
      return JournalEntry.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse the legacy `mood|text` + optional `␟proud` format.
  static ({String? mood, String text, String proud}) _parseLegacy(String note) {
    String proud = '';
    var rest = note;
    final sepIndex = note.indexOf('\u241F');
    if (sepIndex != -1) {
      proud = note.substring(sepIndex + 1);
      rest = note.substring(0, sepIndex);
    }
    final parts = rest.split('|');
    if (parts.length >= 2 && parts[0].length <= 2) {
      return (mood: parts[0], text: parts.sublist(1).join('|'), proud: proud);
    }
    return (mood: null, text: rest, proud: proud);
  }
}
