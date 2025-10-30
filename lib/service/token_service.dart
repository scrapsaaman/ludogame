import 'package:cloud_firestore/cloud_firestore.dart';

import '../component/ui_components/token.dart';

class TokenService {
  TokenService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _tokensCol(String gameId) =>
      _firestore.collection('games').doc(gameId).collection('tokens');

  DocumentReference<Map<String, dynamic>> _tokenDoc(
    String gameId,
    String tokenId,
  ) =>
      _tokensCol(gameId).doc(tokenId);

  Future<Set<String>> existingTokenIds(String gameId) async {
    final snapshot = await _tokensCol(gameId).get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> seedTokensIfMissing({
    required String gameId,
    required Iterable<Token> tokens,
    required String updatedBy,
  }) async {
    final existingIds = await existingTokenIds(gameId);
    if (tokens.isEmpty) return;

    final batch = _firestore.batch();
    var writes = 0;

    for (final token in tokens) {
      if (existingIds.contains(token.tokenId)) continue;
      final doc = _tokenDoc(gameId, token.tokenId);
      final data = <String, dynamic>{
        ...token.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        'nonce': 0,
      };
      batch.set(doc, data);
      writes++;
    }

    if (writes > 0) {
      await batch.commit();
    }
  }

  Future<void> writeAllTokens({
    required String gameId,
    required Iterable<Token> tokens,
    required String updatedBy,
  }) async {
    if (tokens.isEmpty) return;

    final batch = _firestore.batch();

    for (final token in tokens) {
      final doc = _tokenDoc(gameId, token.tokenId);
      final data = <String, dynamic>{
        ...token.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
        'nonce': FieldValue.increment(1),
      };
      batch.set(doc, data, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTokens(String gameId) {
    return _tokensCol(gameId).snapshots();
  }
}
