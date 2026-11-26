import 'package:cloud_firestore/cloud_firestore.dart';

/// Réglage « Publications ouvertes » (interrupteur dans l'application admin)
/// et collection `publications` (ouvrages envoyés par les utilisateurs).
class Publishing {
  Publishing._();

  static DocumentReference<Map<String, dynamic>> get settingsDoc =>
      FirebaseFirestore.instance.collection('settings').doc('publishing');

  static CollectionReference<Map<String, dynamic>> get collection =>
      FirebaseFirestore.instance.collection('publications');

  /// Vrai quand l'administrateur a activé les publications.
  static Stream<bool> enabledStream() =>
      settingsDoc.snapshots().map((s) => s.data()?['enabled'] == true);

  /// Nombre maximum d'ouvrages « en attente » par utilisateur.
  static const int maxPending = 3;
}
