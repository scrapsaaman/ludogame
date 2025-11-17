import 'dart:ui';
import 'dart:ui' as ui;

goldGradientPaint(Offset offset) =>
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), offset, [
        const Color(0xFFFEEB8A), // Light gold
        const Color(0xFFE0A100), // Darker gold
      ]);
