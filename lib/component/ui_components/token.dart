import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:ludogame/ludo.dart';
import 'dart:math';

import 'package:ludogame/state/game_state.dart';
import 'package:ludogame/state/token_manager.dart';

enum TokenState { inBase, onBoard, inHome }

class Token extends PositionComponent with TapCallbacks {
  final String tokenId;
  String playerId;
  bool enableToken;
  String positionId;
  TokenState state;

  Color topColor; // <- This will be the color of the token's BORDER
  Color sideColor; // <- This is no longer used, but we leave it in the constructor

  bool _shouldDrawCircle = false;
  double _circleScale = 1.0;
  Timer? _circleAnimationTimer;

  Token({
    required this.tokenId,
    required this.positionId,
    required Vector2 position,
    required Vector2 size,
    required this.playerId,
    this.enableToken = false,
    this.state = TokenState.inBase,
    required this.topColor,
    required this.sideColor, // Still required by constructor, but not used in render
  }) : super(position: position, size: size);

  bool isInBase() => state == TokenState.inBase;
  bool isOnBoard() => state == TokenState.onBoard;
  bool isInHome() => state == TokenState.inHome;

  // --- NEW, SIMPLIFIED RENDER METHOD ---
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Define dimensions
    final w = size.x;
    final h = size.y;
    // Center of the component
    final cx = w / 2;
    final cy = h / 2;
    final center = Offset(cx, cy);
    // Radius of the token. Made slightly smaller to leave room for shadow
    final r = min(w, h) * 0.4;

    // 2. Create the path for the shadow
    final circlePath = Path()..addOval(Rect.fromCircle(center: center, radius: r));

    // 3. Draw the Shadow (re-using your old logic)
    // You can adjust opacity and blur (4.0) as you like
    canvas.drawShadow(circlePath, Colors.black.withOpacity(0.5), 4.0, true);

    // 4. Draw the white inner circle (the fill)
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, r, whitePaint);

    // 5. Draw the colored border
    // We use the `topColor` as the main player color
    final borderPaint = Paint()
      ..color = topColor // This is the player's color (blue, red, etc.)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.25; // Make the border 25% of the radius (adjust as needed)
    canvas.drawCircle(center, r, borderPaint);

    // 6. Keep the selection ring animation
    // We just need to update its center position to the new center
    if (_shouldDrawCircle) {
      _renderCircleAroundToken(canvas, center);
    }
  }

  // --- DELETED ---
  // The _buildMarkerPath method is no longer needed and has been removed.
  // ---

  void _renderCircleAroundToken(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // Pulse ring radius relative to width
    final scaledRadius = (size.x * 0.55) * _circleScale;
    canvas.drawCircle(center, scaledRadius, paint);
  }

  // Enable circle rendering and animation
  void enableCircleAnimation() {
    if (_shouldDrawCircle) return;
    _shouldDrawCircle = true;

    _circleAnimationTimer = Timer(
      0.070,
      onTick: () {
        _circleScale += 0.05;
        if (_circleScale >= 2) _circleScale = 1.0;
      },
      repeat: true,
    )..start();
  }

  // Disable circle rendering and animation
  void disableCircleAnimation() {
    _shouldDrawCircle = false;
    _circleAnimationTimer?.stop();
    _circleAnimationTimer = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _circleAnimationTimer?.update(dt);
  }

  @override
  void onTapDown(TapDownEvent event) async {
    super.onTapDown(event);
    final world = parent?.parent;

    if (!spaceToMove() ||
        !enableToken ||
        world is! World ||
        (isInBase() && GameState().diceNumber != 6) ||
        isInHome())
      return;

    enableToken = false;
    if (GameState().currentPlayer.playerId != playerId) return;

    final tokens = TokenManager().allTokens;
    for (var token in tokens) {
      token.disableCircleAnimation();
      token.enableToken = false;
    }

    if (GameState().diceNumber == 6) {
      if (state == TokenState.inBase && GameState().canMoveTokenFromBase) {
        moveOutOfBase(
          world: world,
          token: this,
          tokenPath: GameState().getTokenPath(playerId),
        );
      } else if (state == TokenState.onBoard &&
          GameState().canMoveTokenOnBoard) {
        moveForward(
          world: world,
          token: this,
          tokenPath: GameState().getTokenPath(playerId),
          diceNumber: GameState().diceNumber,
        );
      }
      return;
    }

    if (state == TokenState.onBoard && GameState().canMoveTokenOnBoard) {
      moveForward(
        world: world,
        token: this,
        tokenPath: GameState().getTokenPath(playerId),
        diceNumber: GameState().diceNumber,
      );
    }
  }

  bool spaceToMove() {
    final tokenPath = GameState().getTokenPath(playerId);
    final index = tokenPath.indexOf(positionId);
    final newIndex = index + GameState().diceNumber;
    return newIndex < tokenPath.length;
  }
}
