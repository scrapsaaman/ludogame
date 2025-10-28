import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class StarComponent extends PositionComponent {
  final Paint borderPaint;
  final int points;

  StarComponent({
    required Vector2 position,
    required Vector2 size,
    Color borderColor = const Color(0xffD3DEDC),
    this.points = 5, // Default: 5-pointed star
  })  : borderPaint = Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
        super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);
    final outerRadius = size.x / 2;
    final innerRadius = outerRadius / 2.5;
    final path = Path();

    // Draw star shape
    for (int i = 0; i <= points * 2; i++) {
      final isEven = i.isEven;
      final radius = isEven ? outerRadius : innerRadius;
      final angle = (pi / points) * i - pi / 2; // Rotate start to top
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Draw outlined star
    canvas.drawPath(path, borderPaint);
  }
}
