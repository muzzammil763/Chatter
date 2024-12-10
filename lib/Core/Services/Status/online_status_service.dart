import 'package:firebase_database/firebase_database.dart';

class OnlineStatusService {
  final String userId;
  final DatabaseReference _userStatusRef;

  OnlineStatusService(this.userId)
      : _userStatusRef = FirebaseDatabase.instance.ref('status/$userId');

  void setOnlineStatus() {
    _userStatusRef.set({
      'state': 'online',
      'lastChanged': ServerValue.timestamp,
    });

    _userStatusRef.onDisconnect().set({
      'state': 'offline',
      'lastChanged': ServerValue.timestamp,
    });
  }

  void setOfflineStatus() {
    _userStatusRef.set({
      'state': 'offline',
      'lastChanged': ServerValue.timestamp,
    });
  }
}
