import 'dart:async';

import '../state/dice_state.dart';
import '../state/game_state.dart';
import 'dice_service.dart';

class DiceSyncManager {
  DiceSyncManager._({DiceService? service})
      : _service = service ?? DiceService();

  static final DiceSyncManager _instance = DiceSyncManager._();

  factory DiceSyncManager() => _instance;

  final DiceService _service;
  final StreamController<DiceState> _diceStreamController =
      StreamController<DiceState>.broadcast();

  Stream<DiceState> get diceStream => _diceStreamController.stream;

  StreamSubscription<DiceState?>? _diceSubscription;
  String? _activeGameId;
  int? _lastNonce;

  Future<void> start({required String gameId}) async {
    if (_activeGameId == gameId && _diceSubscription != null) return;

    await _diceSubscription?.cancel();
    _lastNonce = null;
    _activeGameId = gameId;

    await _service.ensureDiceDocument(gameId);

    _diceSubscription = _service.watchDice(gameId).listen((state) {
      if (state == null) return;
      if (_lastNonce == state.nonce) return;
      _lastNonce = state.nonce;
      GameState().diceNumber = state.value;
      _diceStreamController.add(state);
    });
  }

  Future<void> publishRoll({
    required String rolledBy,
    required int value,
  }) async {
    final gameId = _activeGameId ?? GameState().gameId;
    if (gameId == null || gameId.isEmpty) {
      throw StateError('Game ID not configured for dice sync.');
    }

    await _service.updateRoll(
      gameId: gameId,
      value: value,
      rolledBy: rolledBy,
    );
  }

  Future<void> stop() async {
    await _diceSubscription?.cancel();
    _diceSubscription = null;
    _activeGameId = null;
    _lastNonce = null;
  }
}
