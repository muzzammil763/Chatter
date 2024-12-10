import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance {
    if (_prefs == null) {
      throw Exception('SharedPrefsService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  static Future<void> cacheUsers(Map<dynamic, dynamic> users) async {
    await instance.setString('usersCache', json.encode(users));
  }

  static Map<dynamic, dynamic> getCachedUsers() {
    final cachedData = instance.getString('usersCache');
    if (cachedData != null) {
      return json.decode(cachedData);
    }
    return {};
  }

  static Future<void> cacheLastMessage(
      String chatId, Map<String, dynamic> message) async {
    final messages = getCachedLastMessages();
    messages[chatId] = message;
    await instance.setString('lastMessagesCache', json.encode(messages));
  }

  static Map<String, Map<String, dynamic>> getCachedLastMessages() {
    final cachedMessages = instance.getString('lastMessagesCache');
    if (cachedMessages != null) {
      final decoded = json.decode(cachedMessages);
      return Map<String, Map<String, dynamic>>.from(
        decoded.map((key, value) => MapEntry(
              key.toString(),
              Map<String, dynamic>.from(value),
            )),
      );
    }
    return {};
  }

  static Future<void> clearAll() async {
    await instance.clear();
  }

  static Future<void> clearUserCache() async {
    await instance.remove('usersCache');
  }

  static Future<void> clearMessageCache() async {
    await instance.remove('lastMessagesCache');
  }

  static Future<void> clearChatCache(String chatId) async {
    await instance.remove('chat_$chatId');
  }

  static Future<void> clearAllChatCaches() async {
    final keys = instance.getKeys();
    for (final key in keys) {
      if (key.startsWith('chat_')) {
        await instance.remove(key);
      }
    }
  }
}
