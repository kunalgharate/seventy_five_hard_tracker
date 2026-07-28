import 'dart:math' as math;
import 'package:flutter/material.dart';

class LiquidWaveIndicator extends StatefulWidget {
  final double value;
  final Color valueColor;
  final Color backgroundColor;

  const LiquidWaveIndicator({
    super.key,
    required this.value,
    this.valueColor = Colors.blue,
    this.backgroundColor = const Color(0xFFE3F2FD),
  });

  @override
  State<LiquidWaveIndicator> createState() => _LiquidWaveIndicatorState();
}

class _LiquidWaveIndicatorState extends State<LiquidWaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _WavePainter(
              animationValue: _controller.value,
              fillValue: widget.value,
              color: widget.valueColor,
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final double fillValue;
  final Color color;

  _WavePainter({
    required this.animationValue,
    required this.fillValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillValue <= 0.0) return;
    if (fillValue >= 1.0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = color,
      );
      return;
    }

    final path = Path();
    final yOffset = size.height - (size.height * fillValue);
    
    path.moveTo(0, size.height);
    path.lineTo(0, yOffset);

    // Draw wave
    for (double i = 0; i <= size.width; i++) {
      // Sine wave formula: y = A * sin(B * x + C) + D
      // A = amplitude, B = frequency, C = phase shift, D = vertical offset
      path.lineTo(
        i,
        yOffset + math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * 8,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();

    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.fillValue != fillValue ||
           oldDelegate.color != color;
  }
}
