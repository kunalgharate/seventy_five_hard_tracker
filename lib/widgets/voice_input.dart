import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:seventy_five_hard_tracker/features/ai_accountability/data/services/tron_ai_service.dart';

/// Preferred dictation locales, in order. The mic uses the device locale
/// when available, else the first available entry here, else en-US.
const _preferredLocales = [
  'en-IN',
  'hi-IN',
  'mr-IN',
  'en-US',
  'hi',
  'mr',
  'en',
];

/// Mic button that dictates into [controller].
///
/// Tap to start/stop. Long-press to pick the recognition language
/// (Marathi, Hindi, English, … — whatever the OS offers).
class MicDictationButton extends StatefulWidget {
  final TextEditingController controller;
  final Color activeColor;

  const MicDictationButton({
    super.key,
    required this.controller,
    this.activeColor = Colors.red,
  });

  @override
  State<MicDictationButton> createState() => _MicDictationButtonState();
}

class _MicDictationButtonState extends State<MicDictationButton> {
  final SpeechToText _stt = SpeechToText();
  bool _listening = false;
  bool _busy = false;
  String _baseText = '';
  String? _localeId;

  Future<void> _toggle() async {
    if (_listening) {
      await _stop();
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final available = await _stt.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (kDebugMode) debugPrint('[Mic] error: $error');
          if (mounted) {
            setState(() => _listening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Microphone unavailable — allow mic access and try again.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Speech recognition unavailable on this device/language.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      _localeId ??= await _pickLocale();
      _baseText = widget.controller.text;
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
      if (mounted) setState(() => _listening = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Device locale when supported, else first preferred match, else en-US.
  Future<String?> _pickLocale() async {
    try {
      final system = await _stt.systemLocale();
      final locales = await _stt.locales();
      final ids = locales.map((l) => l.localeId).toList();
      if (system != null && ids.contains(system.localeId)) {
        return system.localeId;
      }
      if (system != null) {
        final lang = system.localeId.split(RegExp(r'[-_]')).first;
        final match = ids.firstWhere(
          (id) => id.split(RegExp(r'[-_]')).first == lang,
          orElse: () => '',
        );
        if (match.isNotEmpty) return match;
      }
      for (final pref in _preferredLocales) {
        if (ids.contains(pref)) return pref;
      }
      if (ids.contains('en-US')) return 'en-US';
      return ids.isNotEmpty ? ids.first : null;
    } catch (_) {
      return null;
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final spoken = result.recognizedWords.trim();
    final combined =
        spoken.isEmpty ? _baseText : '${_baseText.trim()} $spoken'.trimLeft();
    widget.controller.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
    if (result.finalResult) _baseText = combined;
  }

  Future<void> _stop() async {
    await _stt.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _pickLanguage() async {
    try {
      final locales = await _stt.locales();
      if (locales.isEmpty || !mounted) return;
      final ids = locales.map((l) => l.localeId).toSet().toList()..sort();
      final chosen = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Dictation language'),
          children: ids
              .map((id) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, id),
                    child: Text(
                      id,
                      style: TextStyle(
                        fontWeight: id == _localeId
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: id == _localeId ? Colors.orange : null,
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
      if (chosen != null) setState(() => _localeId = chosen);
    } catch (_) {}
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _pickLanguage,
      child: IconButton(
        onPressed: _busy ? null : _toggle,
        tooltip: _listening
            ? 'Stop dictation${_localeId != null ? ' ($_localeId)' : ''}'
            : 'Dictate${_localeId != null ? ' ($_localeId)' : ''} — long-press for language',
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _listening ? Icons.stop_circle_outlined : Icons.mic_outlined,
                color: _listening ? widget.activeColor : Colors.grey[600],
              ),
      ),
    );
  }
}

/// "✨ Tron AI" button: polishes [controller] text (grammar/punctuation,
/// same language) via the Tron AI API. No-op with a hint when empty.
class TronPolishButton extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onPolished;

  const TronPolishButton({
    super.key,
    required this.controller,
    this.onPolished,
  });

  @override
  State<TronPolishButton> createState() => _TronPolishButtonState();
}

class _TronPolishButtonState extends State<TronPolishButton> {
  bool _busy = false;

  Future<void> _polish() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final res = await TronAiService().polishDictation(text);
      if (!mounted) return;
      if (res.isError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.text),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      widget.controller.value = TextEditingValue(
        text: res.text,
        selection: TextSelection.collapsed(offset: res.text.length),
      );
      widget.onPolished?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Polished with Tron AI'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _busy ? null : _polish,
      icon: _busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_fix_high_outlined, size: 16),
      label: const Text('Tron AI', style: TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.deepPurple,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
