import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() => _instance;

  ChatService._internal();

  String? _currentUserId;
  String? _activeChatId;
  bool _isAppActive = true;
  final Map<String, StreamSubscription> _chatSubscriptions = {};

  void initialize(String userId) {
    _currentUserId = userId;
    _setupAppLifecycleListener();
  }

  void _setupAppLifecycleListener() {}

  Future<void> enterChat(String otherUserId) async {
    if (_currentUserId == null) return;

    final chatId = getChatId(_currentUserId!, otherUserId);
    _activeChatId = chatId;

    await FirebaseDatabase.instance
        .ref('users/$_currentUserId/activeChat')
        .set({
      'chatId': chatId,
      'timestamp': ServerValue.timestamp,
      'isActive': true,
    });

    _listenToMessages(chatId);

    notifyListeners();
  }

  Future<void> exitChat() async {
    if (_currentUserId == null || _activeChatId == null) return;

    await FirebaseDatabase.instance
        .ref('users/$_currentUserId/activeChat')
        .set({
      'chatId': null,
      'timestamp': ServerValue.timestamp,
      'isActive': false,
    });

    _chatSubscriptions[_activeChatId]?.cancel();
    _chatSubscriptions.remove(_activeChatId);
    _activeChatId = null;

    notifyListeners();
  }

  void _listenToMessages(String chatId) {
    final subscription =
        FirebaseDatabase.instance.ref('chats/$chatId').onValue.listen((event) {
      if (!_isAppActive || _activeChatId != chatId) return;

      final messages = event.snapshot.value as Map<dynamic, dynamic>?;
      if (messages == null) return;

      _markMessagesAsRead(chatId, messages);
    });

    _chatSubscriptions[chatId] = subscription;
  }

  Future<void> _markMessagesAsRead(
      String chatId, Map<dynamic, dynamic> messages) async {
    if (_currentUserId == null) return;

    final batch = <Future>[];
    messages.forEach((key, value) {
      if (value['senderId'] != _currentUserId && !(value['read'] ?? false)) {
        batch.add(
          FirebaseDatabase.instance
              .ref('chats/$chatId/$key')
              .update({'read': true}),
        );
      }
    });

    await Future.wait(batch);
  }

  void onAppResume() {
    _isAppActive = true;
    if (_activeChatId != null) {
      _listenToMessages(_activeChatId!);
    }
  }

  void onAppPause() {
    _isAppActive = false;
    for (var sub in _chatSubscriptions.values) {
      sub.cancel();
    }
    _chatSubscriptions.clear();
  }

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '$uid1-$uid2' : '$uid2-$uid1';
  }

  @override
  void dispose() {
    super.dispose();
    for (var sub in _chatSubscriptions.values) {
      sub.cancel();
    }
    _chatSubscriptions.clear();
    _currentUserId = null;
    _activeChatId = null;
  }
}
