import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the dice roll data synced through Firestore.
class DiceState {
  const DiceState({
    required this.value,
    required this.nonce,
    this.rolledBy,
    this.rolledAt,
  });

  final int value;
  final int nonce;
  final String? rolledBy;
  final DateTime? rolledAt;

  factory DiceState.fromJson(Map<String, dynamic> json) {
    final timestamp = json['rolledAt'];
    return DiceState(
      value: (json['value'] as num?)?.toInt() ?? 1,
      nonce: (json['nonce'] as num?)?.toInt() ?? 0,
      rolledBy: json['rolledBy'] as String?,
      rolledAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'nonce': nonce,
        'rolledBy': rolledBy,
        'rolledAt': rolledAt,
      };
}
