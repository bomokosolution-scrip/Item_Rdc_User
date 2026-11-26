import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:item_rdc/core/app_config.dart';
import 'package:item_rdc/core/push_service.dart';

/// Instance unique utilisée dans toute l'application.
final AuthService authService = AuthService();

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) => _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) => _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() async {
    // Marque l'utilisateur hors ligne tant qu'il est encore authentifié.
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await PushService.stop(uid);
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()});
      } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> updateDisplayName(String name) async {
    await currentUser?.updateDisplayName(name);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: oldPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Création du profil à l'inscription : offre l'essai Premium.
  Future<void> createUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) {
    return FirebaseFirestore.instance.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'profileImage': '',
      'createdAt': FieldValue.serverTimestamp(),
      'premiumBoughtTime': FieldValue.serverTimestamp(),
      'premiumExpiryTime': Timestamp.fromDate(
        DateTime.now().add(AppConfig.signupTrial),
      ),
    }, SetOptions(merge: true));
  }

  /// Mise à jour du profil. Ne touche JAMAIS aux champs Premium
  /// (avant, chaque sauvegarde du profil offrait 7 jours de Premium).
  Future<void> updateProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String phone,
  }) {
    return FirebaseFirestore.instance.collection('users').doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
    }, SetOptions(merge: true));
  }
}

/// Messages d'erreur d'authentification en français.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return "Adresse e-mail invalide.";
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return "E-mail ou mot de passe incorrect.";
      case 'email-already-in-use':
        return "Cette adresse e-mail est déjà utilisée.";
      case 'weak-password':
        return "Mot de passe trop faible (6 caractères minimum).";
      case 'network-request-failed':
        return "Pas de connexion internet. Réessayez.";
      case 'too-many-requests':
        return "Trop de tentatives. Patientez un instant.";
      case 'requires-recent-login':
        return "Reconnectez-vous puis réessayez.";
      case 'user-disabled':
        return "Ce compte a été désactivé.";
      default:
        return error.message ?? "Erreur d'authentification.";
    }
  }
  return "Une erreur inattendue est survenue.";
}
