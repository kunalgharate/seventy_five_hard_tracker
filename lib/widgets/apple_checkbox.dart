import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppleCheckbox extends StatefulWidget {
  final bool isChecked;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;
  final double size;

  const AppleCheckbox({
    super.key,
    required this.isChecked,
    required this.isEnabled,
    required this.onChanged,
    this.size = 28.0,
  });

  @override
  State<AppleCheckbox> createState() => _AppleCheckboxState();
}

class _AppleCheckboxState extends State<AppleCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.isChecked) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AppleCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecked != oldWidget.isChecked) {
      if (widget.isChecked) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isEnabled) return;
    HapticFeedback.lightImpact();
    widget.onChanged(!widget.isChecked);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.isChecked ? 'Checked' : 'Unchecked',
      enabled: widget.isEnabled,
      toggled: widget.isChecked,
      child: GestureDetector(
        onTap: widget.isEnabled ? _handleTap : null,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _AppleCheckboxPainter(
                progress: _animation.value,
                isEnabled: widget.isEnabled,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AppleCheckboxPainter extends CustomPainter {
  final double progress;
  final bool isEnabled;

  _AppleCheckboxPainter({
    required this.progress,
    required this.isEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final double opacity = isEnabled ? 1.0 : 0.4;

    // Draw the circle border (unchecked state)
    final borderPaint = Paint()
      ..color = Color.lerp(
        Colors.grey[400]!.withValues(alpha: opacity),
        Colors.green[600]!.withValues(alpha: opacity),
        progress,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius - 1, borderPaint);

    // Draw the filled circle (checked state)
    if (progress > 0) {
      final fillPaint = Paint()
        ..color = Colors.green[600]!.withValues(alpha: progress * opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, (radius - 1) * progress, fillPaint);

      // Draw the white checkmark
      final checkPaint = Paint()
        ..color = Colors.white.withValues(alpha: progress * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      // Checkmark proportions relative to size
      final checkLeft = size.width * 0.28;
      final checkMid = size.width * 0.45;
      final checkRight = size.width * 0.72;
      final checkTop = size.height * 0.35;
      final checkBottom = size.height * 0.55;
      final checkMiddleY = size.height * 0.62;

      path.moveTo(checkLeft, checkBottom);
      path.lineTo(checkMid, checkMiddleY);
      path.lineTo(checkRight, checkTop);

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_AppleCheckboxPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isEnabled != isEnabled;
  }
}
