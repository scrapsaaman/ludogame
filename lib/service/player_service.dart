import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ludogame/state/player.dart';
import '../component/ui_components/token.dart';

/// If your Token serialization method names differ, change these two lines.
typedef TokenToJson = Map<String, dynamic> Function(Token t);
typedef TokenFromJson = Token Function(Map<String, dynamic> json);

class PlayerService {
  PlayerService({this.tokenToJson, this.tokenFromJson})
    : _db = FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final TokenToJson? tokenToJson;
  final TokenFromJson? tokenFromJson;

  /// Collection reference: games/{gameId}/players
  CollectionReference<Map<String, dynamic>> _playersCol(String gameId) =>
      _db.collection('games').doc(gameId).collection('players');

  /// Doc reference: games/{gameId}/players/{playerId}
  DocumentReference<Map<String, dynamic>> _playerDoc(
    String gameId,
    String playerId,
  ) => _playersCol(gameId).doc(playerId);

  // ---------------------------
  // CONVERTERS
  // ---------------------------
  Map<String, dynamic> _playerToJson(Player p) {
    final _toJson = tokenToJson ?? (Token t) => t.toJson();
    return {
      'playerId': p.playerId,
      'tokens': p.tokens.map(_toJson).toList(),
      'isCurrentTurn': p.isCurrentTurn,
      'rank': p.rank,
      'totalTokensInHome': p.totalTokensInHome,
      'hasWon': p.hasWon,
      'extraTurns': p.extraTurns,
      'enableDice': p.enableDice,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Player _playerFromJson(Map<String, dynamic> json) {
    final _fromJson =
        tokenFromJson ?? (Map<String, dynamic> j) => Token.fromJson(j);

    final tokenList = (json['tokens'] as List? ?? [])
        .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return Player(
      playerId: json['playerId'] as String,
      tokens: tokenList,
      isCurrentTurn: (json['isCurrentTurn'] as bool?) ?? false,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      totalTokensInHome: (json['totalTokensInHome'] as num?)?.toInt() ?? 0,
      hasWon: (json['hasWon'] as bool?) ?? false,
      extraTurns: (json['extraTurns'] as num?)?.toInt() ?? 0,
      enableDice: (json['enableDice'] as bool?) ?? false,
    );
  }

  // ---------------------------
  // CREATE / UPSERT
  // ---------------------------

  /// Create or overwrite a player document.
  Future<void> upsertPlayer(String gameId, Player player) async {
    await _playerDoc(
      gameId,
      player.playerId,
    ).set(_playerToJson(player), SetOptions(merge: true));
  }

  /// Create a new player doc only if it doesn't exist.
  Future<void> createPlayerIfAbsent(String gameId, Player player) async {
    final doc = await _playerDoc(gameId, player.playerId).get();
    if (!doc.exists) {
      await upsertPlayer(gameId, player);
    }
  }

  // ---------------------------
  // READ / STREAM
  // ---------------------------

  /// Live stream of a single player.
  Stream<Player?> watchPlayer(String gameId, String playerId) {
    return _playerDoc(gameId, playerId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return _playerFromJson(snap.data()!);
    });
  }

  /// Live stream of all players in a game (ordered by rank ascending, then id).
  Stream<List<Player>> watchPlayers(String gameId) {
    return _playersCol(gameId)
        .orderBy('rank')
        .orderBy('playerId')
        .snapshots()
        .map((qs) => qs.docs.map((d) => _playerFromJson(d.data())).toList());
  }

  /// One-time fetch of a player.
  Future<Player?> getPlayer(String gameId, String playerId) async {
    final snap = await _playerDoc(gameId, playerId).get();
    if (!snap.exists || snap.data() == null) return null;
    return _playerFromJson(snap.data()!);
  }

  // ---------------------------
  // MUTATIONS (SAFE)
  // ---------------------------

  /// Replace all tokens atomically.
  Future<void> setTokens(
    String gameId,
    String playerId,
    List<Token> tokens,
  ) async {
    final _toJson = tokenToJson ?? (Token t) => t.toJson();
    await _playerDoc(gameId, playerId).update({
      'tokens': tokens.map(_toJson).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Increment or decrement total tokens in home (never below 0).
  Future<void> bumpTokensInHome(
    String gameId,
    String playerId, {
    int by = 1,
  }) async {
    await _db.runTransaction((tx) async {
      final ref = _playerDoc(gameId, playerId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Player not found');
      final data = Map<String, dynamic>.from(snap.data()!);
      final current = (data['totalTokensInHome'] as num?)?.toInt() ?? 0;
      final next = (current + by).clamp(0, 1 << 30);
      tx.update(ref, {
        'totalTokensInHome': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Toggle current turn.
  Future<void> setCurrentTurn(
    String gameId,
    String playerId, {
    required bool isCurrentTurn,
  }) async {
    await _playerDoc(gameId, playerId).update({
      'isCurrentTurn': isCurrentTurn,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Enable/disable dice for the player.
  Future<void> setDiceEnabled(
    String gameId,
    String playerId, {
    required bool enabled,
  }) async {
    await _playerDoc(gameId, playerId).update({
      'enableDice': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Grant an extra turn (atomic increment).
  Future<void> grantAnotherTurn(String gameId, String playerId) async {
    await _playerDoc(gameId, playerId).update({
      'extraTurns': FieldValue.increment(1),
      'enableDice': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reset extra turns back to 0 (transaction-safe).
  Future<void> resetExtraTurns(String gameId, String playerId) async {
    await _playerDoc(
      gameId,
      playerId,
    ).update({'extraTurns': 0, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Mark the player as won and set rank in a single transaction.
  Future<void> markWonWithRank(
    String gameId,
    String playerId, {
    required int rank,
  }) async {
    await _db.runTransaction((tx) async {
      final ref = _playerDoc(gameId, playerId);
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Player not found');
      tx.update(ref, {
        'hasWon': true,
        'rank': rank,
        'enableDice': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Arbitrary partial update (keep it small & flat).
  Future<void> updateFields(
    String gameId,
    String playerId,
    Map<String, dynamic> patch,
  ) async {
    patch['updatedAt'] = FieldValue.serverTimestamp();
    await _playerDoc(gameId, playerId).update(patch);
  }

  /// Delete player (if you need to).
  Future<void> deletePlayer(String gameId, String playerId) async {
    await _playerDoc(gameId, playerId).delete();
  }
}
