import 'dart:ui' as ui; // <-- ADD THIS IMPORT for gradients
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:ludogame/state/game_state.dart';
import '../ui_components/spot.dart'; // Replace with the actual path to your Spot component
import '../ui_components/arrow_icon_component.dart'; // Replace with the actual path to ArrowIconComponent
import '../ui_components/star_component.dart'; // Replace with the actual path to StarComponent

// Renamed the class
class GoldGridComponent extends PositionComponent {
  final bool showId;

  GoldGridComponent({required double size, this.showId = false})
    : super(size: Vector2.all(size)) {
    _createGrid();
  }

  // Function to create the grid of rectangles
  void _createGrid() {
    double spacing = 0; // Vertical spacing between rectangles
    double columnSpacing = 0; // Horizontal spacing between columns

    int numberOfRows = 6;
    int numberOfColumns = 3;

    // Pre-calculate values used in the loop
    double sizeX = size.x;
    double halfSizeX = sizeX / 2;
    double textSize = sizeX * 0.4;
    double strokeWidth = sizeX * 0.025;
    double arrowSize = sizeX * 0.50;
    Vector2 arrowPosition = Vector2(sizeX * 0.25, sizeX * 0.2);

    // --- NEW GRADIENT PAINT ---
    // Define a gradient paint for the gold spots
    final goldGradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0), // Start from top-left
        Offset(size.x, size.y), // Go to bottom-right
        [
          const Color(0xFFFEEB8A), // Light gold
          const Color(0xFFE0A100), // Darker gold
        ],
      );

    // Define a simple white paint
    final whitePaint = Paint()..color = Colors.white;

    // Define a flat gold color for the arrow
    final goldColor = Colors.yellow.shade700;
    // --- END NEW PAINTS ---

    // Loop to create 3 columns of 6 squares each
    for (int col = 0; col < numberOfColumns; col++) {
      double colPosition = col * (sizeX + columnSpacing);
      for (int row = 0; row < numberOfRows; row++) {
        double rowPosition = row * (sizeX + spacing);

        // Check if this spot should be gold
        bool isGoldSpot = (col == 0 && row == 4 || col == 1 && row < 5);

        // Create the unique ID for this block
        String uniqueId = 'Y$col$row'; // Changed from 'B' to 'Y' for Yellow

        var rectangle = Spot(
          uniqueId: uniqueId,
          position: Vector2(colPosition, rowPosition),
          size: size,
          // Use the gradient paint if it's a gold spot, otherwise white
          paint: isGoldSpot ? goldGradientPaint : whitePaint,
          children: [
            // Border Rectangle
            RectangleComponent(
              size: size,
              paint: Paint()
                ..color = Colors
                    .transparent // Keep interior transparent
                ..style = PaintingStyle
                    .stroke // Set style to stroke
                ..strokeWidth =
                    strokeWidth // Set border width
                ..color = const Color(0xFF606676), // Set border color to black
              children: [
                if (col == 2 && row == 3)
                  StarComponent(
                    size: size * 0.90,
                    position: Vector2(size.x * 0.05, size.x * 0.05),
                  ),
                if (col == 1 && row == 5)
                  ArrowIconComponent(
                    point: 'north', // Set direction
                    size: arrowSize, // Set the desired size
                    position: arrowPosition, // Set the desired position
                    // Use the flat gold color for the arrow
                    fillColor: goldColor,
                  ),
                // Add the unique ID as a text label at the center
                if (showId)
                  TextComponent(
                    text: uniqueId,
                    position: Vector2(halfSizeX, halfSizeX),
                    anchor: Anchor.center,
                    textRenderer: TextPaint(
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: textSize, // Adjust font size as needed
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
        add(rectangle);
      }
    }
  }
}
