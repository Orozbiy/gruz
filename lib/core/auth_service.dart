import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'prefs.dart';
import 'tracking_service.dart';

/// Google (Gmail) аккаунту менен кирүү.
/// Демо режимде (Firebase жок) аккаунт талап кылынбайт.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool get _live => TrackingService.instance.live;

  User? get user => _live ? FirebaseAuth.instance.currentUser : null;

  /// true — кирди, false — колдонуучу терезени жаап салды.
  Future<bool> signInWithGoogle() async {
    final google = await GoogleSignIn().signIn();
    if (google == null) return false;
    final auth = await google.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final res = await FirebaseAuth.instance.signInWithCredential(cred);
    await _saveProfile(res.user);
    return true;
  }

  /// Админ панелде көрүнүшү үчүн колдонуучунун маалыматы жазылат.
  Future<void> _saveProfile(User? u) async {
    if (u == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'name': u.displayName ?? '',
        'email': u.email ?? '',
        'photo': u.photoURL ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Ташуучунун иш экраны ачыкпы (паролду киргизгенден кийин, сессия бою).
  bool driverUnlocked = false;

  /// Бир жолу номер+пароль менен кирсе, ошол аккаунт үчүн телефондо эстеп калат
  /// (паролдун өзү сакталбайт, аккаунттун белгиси гана). Чыгып кетмейинче кайра сурабайт.
  Future<void> rememberDriver() async {
    driverUnlocked = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await Prefs.setDriverUnlockedUid(uid);
  }

  /// Телефондо эстелгенби — тиркеме кайра ачылганда да.
  Future<void> loadDriverUnlocked() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    driverUnlocked = uid != null && await Prefs.driverUnlockedUid() == uid;
  }

  /// Телефон номерин санга айландырат (996XXXXXXXXX).
  static String normPhone(String phone) {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10 && d.startsWith('0')) d = '996${d.substring(1)}';
    if (d.length == 9) d = '996$d';
    return d;
  }

  /// Телефон номери Firebase'те ички email катары сакталат (колдонуучу көрбөйт).
  static String phoneEmail(String phone) => '${normPhone(phone)}@driver.gruz.app';

  /// Ташуучу каттоодо: телефон + пароль учурдагы аккаунтка байланат
  /// (пароль Firebase'те коопсуз сакталат, тиркемеде жана телефондо эмес).
  Future<void> setPassword(String phone, String password) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('Аккаунт менен кирүү керек');
    final cred = EmailAuthProvider.credential(email: phoneEmail(phone), password: password);
    try {
      await u.linkWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        await u.unlink('password');
        await u.linkWithCredential(cred);
      } else {
        rethrow;
      }
    }
  }

  /// Телефон + пароль менен кирүү. true — кирди, false — номер же пароль туура эмес.
  Future<bool> signInWithPhone(String phone, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: phoneEmail(phone), password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      const wrong = {
        'wrong-password',
        'invalid-credential',
        'invalid-login-credentials',
        'user-not-found',
        'invalid-email',
      };
      if (wrong.contains(e.code)) return false;
      rethrow;
    }
  }

  Future<void> signOut() async {
    driverUnlocked = false;
    await Prefs.setDriverUnlockedUid(null);
    await TrackingService.instance.reset();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }
}
