import 'package:cloud_firestore/cloud_firestore.dart';
import '../state/dice_state.dart';

class DiceService {
  DiceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _diceDoc(String gameId) =>
      _firestore.collection('games').doc(gameId).collection('state').doc('dice');

  Future<void> ensureDiceDocument(String gameId) async {
    final doc = await _diceDoc(gameId).get();
    if (doc.exists) return;
    await _diceDoc(gameId).set({
      'value': 6,
      'rolledBy': null,
      'nonce': 0,
      'rolledAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DiceState?> watchDice(String gameId) {
    return _diceDoc(gameId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return DiceState.fromJson(data);
    });
  }

  Future<void> updateRoll({
    required String gameId,
    required int value,
    required String rolledBy,
  }) async {
    await _diceDoc(gameId).set({
      'value': value,
      'rolledBy': rolledBy,
      'rolledAt': FieldValue.serverTimestamp(),
      'nonce': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}
