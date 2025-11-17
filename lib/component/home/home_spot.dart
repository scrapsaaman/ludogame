import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class HomeSpot extends PositionComponent {
  final String uniqueId;
  final double radius;
  final Paint
  paint; // This is the paint with the spot's main color (e.g., blue)

  HomeSpot({
    required this.radius,
    required Vector2 position,
    required this.paint, // This is the paint (e.g., solid blue) from HomeSpotContainer
    required this.uniqueId,
  }) : super(
         position: position,
         size: Vector2.all(
           radius * 2,
         ), // Set the component size to match the diameter
       ) {
    // 1. Create the white inner circle
    final whitePaint = Paint()..color = Colors.white;
    add(
      CircleComponent(
        radius: radius,
        paint: whitePaint,
        position: Vector2(0, 0), // Position at the component's 0,0
      ),
    );

    // 2. Create the colored border circle
    // We use the passed-in paint's color but force it to be a "stroke" (a line)
    final borderPaint = Paint()
      ..color = paint
          .color // Use the color from the passed-in paint
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          radius * 0.2; // Adjust thickness as needed (e.g., 20% of radius)

    add(
      CircleComponent(
        radius: radius,
        paint: borderPaint,
        position: Vector2(0, 0), // Position at the component's 0,0
      ),
    );
  }
}
