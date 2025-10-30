import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flame/components.dart';

import '../component/ui_components/token.dart';
import '../state/game_state.dart';
import '../state/token_manager.dart';
import 'token_service.dart';

class TokenSyncManager {
  TokenSyncManager._({TokenService? service})
      : _service = service ?? TokenService();

  static final TokenSyncManager _instance = TokenSyncManager._();

  factory TokenSyncManager() => _instance;

  final TokenService _service;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _activeGameId;
  String? _currentUserId;
  bool _isApplyingRemote = false;

  final Map<String, int> _latestNonceByToken = {};
  final Map<String, Token> _pendingRemoteTokens = {};

  Future<void> start({required String gameId}) async {
    if (_activeGameId == gameId && _subscription != null) return;

    await _subscription?.cancel();

    _activeGameId = gameId;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _subscription = _service.watchTokens(gameId).listen(_handleSnapshot);
  }

  Future<void> ensureInitialTokens() async {
    final gameId = _activeGameId ?? GameState().gameId;
    if (gameId.isEmpty) return;

    final userId = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _service.seedTokensIfMissing(
      gameId: gameId,
      tokens: TokenManager().allTokens,
      updatedBy: userId,
    );

    _applyPendingRemoteTokens();
  }

  Future<void> syncTokensFromLocal() async {
    if (_isApplyingRemote) return;

    final gameId = _activeGameId ?? GameState().gameId;
    if (gameId.isEmpty) return;

    final userId = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _service.writeAllTokens(
      gameId: gameId,
      tokens: TokenManager().allTokens,
      updatedBy: userId,
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _activeGameId = null;
    _latestNonceByToken.clear();
    _isApplyingRemote = false;
  }

  void _handleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (snapshot.docs.isEmpty) return;

    final userId = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;

    _isApplyingRemote = true;
    try {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final tokenId = (data['tokenId'] as String?) ?? doc.id;
        final updatedBy = data['updatedBy'] as String?;

        if (updatedBy != null && updatedBy == userId) {
          _latestNonceByToken[tokenId] =
              (data['nonce'] as num?)?.toInt() ?? _latestNonceByToken[tokenId] ?? 0;
          continue;
        }

        final nonce = (data['nonce'] as num?)?.toInt();
        final lastNonce = _latestNonceByToken[tokenId];
        if (nonce != null) {
          if (lastNonce != null && nonce <= lastNonce) {
            continue;
          }
          _latestNonceByToken[tokenId] = nonce;
        }

        final remoteToken = Token.fromJson({
          ...data,
          'tokenId': tokenId,
        });

        final localToken = _findLocalToken(tokenId);
        if (localToken == null) {
          _pendingRemoteTokens[tokenId] = remoteToken;
          continue;
        }

        _applyRemoteState(localToken, remoteToken);
        _pendingRemoteTokens.remove(tokenId);
      }
    } finally {
      _isApplyingRemote = false;
    }
  }

  Token? _findLocalToken(String tokenId) {
    for (final token in TokenManager().allTokens) {
      if (token.tokenId == tokenId) {
        return token;
      }
    }
    return null;
  }

  void _applyRemoteState(Token local, Token remote) {
    local.playerId = remote.playerId;
    local.enableToken = remote.enableToken;
    local.positionId = remote.positionId;
    local.state = remote.state;
    local.topColor = remote.topColor;
    local.sideColor = remote.sideColor;

    _setVector(local.position, remote.position);
    _setVector(local.size, remote.size);
  }

  void _setVector(Vector2 target, Vector2 source) {
    target.setValues(source.x, source.y);
  }

  void _applyPendingRemoteTokens() {
    if (_pendingRemoteTokens.isEmpty) return;

    final pendingEntries = Map<String, Token>.from(_pendingRemoteTokens);
    for (final entry in pendingEntries.entries) {
      final localToken = _findLocalToken(entry.key);
      if (localToken == null) continue;
      _applyRemoteState(localToken, entry.value);
      _pendingRemoteTokens.remove(entry.key);
    }
  }
}
