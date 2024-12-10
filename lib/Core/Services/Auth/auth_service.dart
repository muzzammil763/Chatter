import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:web_chatter_mobile/Core/Services/Notification/notification_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  AuthService() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _auth.authStateChanges().listen((User? user) async {
      notifyListeners();
      if (user != null) {
        _setupOnlineStatus(user.uid);
        String? token = await _notificationService.getFCMToken();
        if (token != null) {
          await _database.child('users/${user.uid}').update({
            'fcmToken': token,
            'tokenLastUpdated': ServerValue.timestamp,
          });
        }
      }
    });
  }

  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? fcmToken = await _notificationService.getFCMToken();

      await _database.child('users/${userCredential.user!.uid}').set({
        'email': email,
        'name': name,
        'uid': userCredential.user!.uid,
        'createdAt': ServerValue.timestamp,
        'isAdmin': false,
        'disabled': false,
        'useSimpleAvatar': true,
        'avatarSeed': '',
        'fcmToken': fcmToken,
        'tokenLastUpdated': ServerValue.timestamp,
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getReadableErrorMessage(e.code);
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userSnapshot =
          await _database.child('users/${userCredential.user!.uid}').get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        if (userData['disabled'] == true) {
          await _auth.signOut();
          throw 'This account has been disabled. Please contact support.';
        }

        String? fcmToken = await _notificationService.getFCMToken();
        if (fcmToken != null) {
          await _database.child('users/${userCredential.user!.uid}').update({
            'fcmToken': fcmToken,
            'tokenLastUpdated': ServerValue.timestamp,
          });
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getReadableErrorMessage(e.code);
    }
  }

  String _getReadableErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters long.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  void _setupOnlineStatus(String userId) {
    final userStatusRef = _database.child('status/$userId');

    _database.child('.info/connected').onValue.listen((event) {
      if (event.snapshot.value == false) {
        return;
      }

      userStatusRef.onDisconnect().set({
        'state': 'offline',
        'lastChanged': ServerValue.timestamp,
      }).then((_) {
        userStatusRef.set({
          'state': 'online',
          'lastChanged': ServerValue.timestamp,
        });
      });
    });
  }

  Future<void> signOut() async {
    final userId = currentUser?.uid;
    if (userId != null) {
      await _database.child('status/$userId').set({
        'state': 'offline',
        'lastChanged': ServerValue.timestamp,
      });

      await _database.child('users/$userId/fcmToken').remove();
      await _database.child('status/$userId').onDisconnect().cancel();
      await _auth.signOut();
    }
  }
}
