import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvatarManager {
  static final Map<String, String?> _avatarCache = {};
  static final Map<String, bool> _simpleAvatarCache = {};

  static Future<String?> getAvatarSeed(String email) async {
    if (_avatarCache.containsKey(email)) {
      return _avatarCache[email];
    }
    final prefs = await SharedPreferences.getInstance();
    final seed = prefs.getString('avatar_$email');
    _avatarCache[email] = seed;
    return seed;
  }

  static Future<bool> getUseSimpleAvatar(String email) async {
    if (_simpleAvatarCache.containsKey(email)) {
      return _simpleAvatarCache[email]!;
    }
    final prefs = await SharedPreferences.getInstance();
    final isSimple = prefs.getBool('useSimpleAvatar_$email') ?? false;
    _simpleAvatarCache[email] = isSimple;
    return isSimple;
  }

  static Widget buildAvatar(String email, [double size = 50]) {
    Widget defaultAvatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * 0.16),
      ),
      child: Center(
        child: Text(
          email[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontFamily: 'Consola',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        getAvatarSeed(email),
        getUseSimpleAvatar(email),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return defaultAvatar;
        }

        final avatarSeed = snapshot.data![0] as String?;
        final useSimpleAvatar = snapshot.data![1] as bool;

        if (useSimpleAvatar || avatarSeed == null || avatarSeed.isEmpty) {
          return defaultAvatar;
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(size * 0.16),
          ),
          child: Center(
            child: RandomAvatar(
              avatarSeed,
              height: size * 0.8,
              width: size * 0.8,
            ),
          ),
        );
      },
    );
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith('avatar_') || key.startsWith('useSimpleAvatar_')) {
        await prefs.remove(key);
      }
    }
  }

  static void updateCache(String email, String? seed, bool isSimple) {
    _avatarCache[email] = seed;
    _simpleAvatarCache[email] = isSimple;
  }
}
