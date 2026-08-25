import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';

class MeshBackground extends StatefulWidget {
  const MeshBackground({
    super.key,
    required this.accent,
    this.secondary,
    this.child,
  });

  final Color accent;
  final Color? secondary;
  final Widget? child;

  @override
  State<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<MeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _MeshPainter(
              t: _controller.value,
              accent: widget.accent,
              secondary: widget.secondary ?? SyntraPalette.peach,
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.t,
    required this.accent,
    required this.secondary,
  });

  final double t;
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = SyntraPalette.voidColor,
    );

    final blobs = <_Blob>[
      _Blob(
        Offset(
          size.width * (0.08 + 0.03 * math.sin(t * math.pi * 2)),
          size.height * (0.04 + 0.02 * math.cos(t * math.pi * 2)),
        ),
        size.shortestSide * 0.9,
        accent.withValues(alpha: 0.10),
      ),
      _Blob(
        Offset(
          size.width * (0.92 + 0.02 * math.cos(t * math.pi * 2 + 1.1)),
          size.height * (0.22 + 0.04 * math.sin(t * math.pi * 2 + 0.5)),
        ),
        size.shortestSide * 0.72,
        SyntraPalette.navy.withValues(alpha: 0.05),
      ),
      _Blob(
        Offset(
          size.width * (0.55 + 0.04 * math.sin(t * math.pi * 2 + 2.0)),
          size.height * (0.92 + 0.02 * math.cos(t * math.pi * 2 + 1.4)),
        ),
        size.shortestSide * 0.95,
        SyntraPalette.peach.withValues(alpha: 0.42),
      ),
    ];

    for (final blob in blobs) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [blob.color, blob.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: blob.center, radius: blob.radius));
      canvas.drawCircle(blob.center, blob.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary;
  }
}

class _Blob {
  const _Blob(this.center, this.radius, this.color);
  final Offset center;
  final double radius;
  final Color color;
}
