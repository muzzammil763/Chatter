import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_chatter_mobile/Core/Services/Chat/chat_service.dart';
import 'package:web_chatter_mobile/Core/Services/Storage/shared_prefs_service.dart';

class InitializationService {
  static Future<void> initialize() async {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        ChatService().initialize(user.uid);
      }
    });

    await SharedPreferences.getInstance();
    await SharedPrefsService.init();
  }
}
