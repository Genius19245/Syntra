import 'package:flutter/material.dart';

import '../theme/syntra_palette.dart';

class SyntraMark extends StatelessWidget {
  const SyntraMark({
    super.key,
    this.size = 44,
    this.color = SyntraPalette.rust,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'S',
        style: TextStyle(
          color: SyntraPalette.onAccent,
          fontSize: size * 0.46,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -0.8,
        ),
      ),
    );
  }
}
