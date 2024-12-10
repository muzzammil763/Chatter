import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_chatter_mobile/Config/firebase_config.dart';

import '../Chat/chat_service.dart';
import '../Storage/shared_prefs_service.dart';

class InitializationService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: FirebaseConfig.defaultOptions,
    );

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        ChatService().initialize(user.uid);
      }
    });

    await SharedPreferences.getInstance();
    await SharedPrefsService.init();
  }
}
