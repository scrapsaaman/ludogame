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

  Color topColor; // <- fill color of the marker
  Color sideColor; // <- outline/border color of the marker

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
    required this.sideColor,
  }) : super(position: position, size: size);

  bool isInBase() => state == TokenState.inBase;
  bool isOnBoard() => state == TokenState.onBoard;
  bool isInHome() => state == TokenState.inHome;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final w = size.x;
    final h = size.y;
    final cx = w / 2;
    final cy = h * 0.45; // center of the circular “head” of the pin
    final r = min(w, h) * 0.3; // radius of the “head”
    final tipY = h * 0.94; // y position of the pin tip

    // Build the location-pin shape
    final pinPath = _buildMarkerPath(cx, cy, r, tipY);

    // Soft drop shadow
    // (last param 'true' considers the shape as transparent for nicer shadow at overlaps)
    canvas.drawShadow(pinPath, Colors.black.withOpacity(0.6), 6.0, true);

    // Fill
    final fillPaint = Paint()
      ..color = topColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = sideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, min(w, h) * 0.05)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(pinPath, borderPaint);

    // Inner “hole”/dot on the head (classic map pin look)
    final innerR = r * 0.6;
    final innerCenter = Offset(cx, cy);
    // Slight inner shadow for depth
    canvas.drawCircle(
      innerCenter.translate(0, innerR * 0.5),
      innerR * 0.92,
      Paint()..color = Colors.black.withOpacity(0.10),
    );
    canvas.drawCircle(innerCenter, innerR, Paint()..color = Colors.white);

    // Optional highlight at top-left of the head
    canvas.drawCircle(
      innerCenter.translate(-r * 0.25, -r * 0.25),
      r * 0.18,
      Paint()..color = Colors.white.withOpacity(0.18),
    );

    // Selection ring animation (reusing your pulse)
    if (_shouldDrawCircle) {
      _renderCircleAroundToken(canvas, Offset(cx, cy + (tipY - cy) * 0.25));
    }
  }

  /// Creates a smooth teardrop location pin:
  /// - top is a rounded “head” (approximated with beziers),
  /// - sides taper to a point at [tipY].
  Path _buildMarkerPath(double cx, double cy, double r, double tipY) {
    final Path path = Path();

    // Start at top of the head
    path.moveTo(cx, cy - r);

    // Top-right curve down to the equator
    path.quadraticBezierTo(cx + r, cy - r, cx + r, cy);

    // Right side down to the tip
    path.quadraticBezierTo(cx + r, cy + r * 1.25, cx, tipY);

    // Left side back up
    path.quadraticBezierTo(cx - r, cy + r * 1.25, cx - r, cy);

    // Top-left curve back to start
    path.quadraticBezierTo(cx - r, cy - r, cx, cy - r);

    path.close();
    return path;
  }

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
