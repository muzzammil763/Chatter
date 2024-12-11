import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return FirebaseOptions(
      apiKey: dotenv.env['ANDROID_API_KEY'] ?? '',
      appId: dotenv.env['ANDROID_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['ANDROID_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['ANDROID_PROJECT_ID'] ?? '',
      storageBucket: dotenv.env['ANDROID_STORAGE_BUCKET'] ?? '',
    );
  }
}
