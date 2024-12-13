import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  bool _isInitializing = false;

  final _initializationCompleter = Completer<void>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _fcmEndpoint =
      'https://fcm.googleapis.com/v1/projects/chatter-android-763/messages:send';

  Map<String, dynamic> get _serviceAccount => {
        "type": "service_account",
        "project_id": dotenv.env['ANDROID_PROJECT_ID'],
        "private_key_id": dotenv.env['SERVICE_ACCOUNT_PRIVATE_KEY_ID'],
        "private_key": (dotenv.env['SERVICE_ACCOUNT_PRIVATE_KEY'] ?? '')
            .replaceAll('"', ''),
        "client_email": dotenv.env['SERVICE_ACCOUNT_CLIENT_EMAIL'],
        "client_id": dotenv.env['SERVICE_ACCOUNT_CLIENT_ID'],
        "auth_uri": dotenv.env['SERVICE_ACCOUNT_AUTH_URI'],
        "token_uri": dotenv.env['SERVICE_ACCOUNT_TOKEN_URI'],
        "auth_provider_x509_cert_url":
            dotenv.env['SERVICE_ACCOUNT_AUTH_PROVIDER_CERT_URL'],
        "client_x509_cert_url": dotenv.env['SERVICE_ACCOUNT_CLIENT_CERT_URL'],
        "universe_domain": "googleapis.com"
      };

  Future<void> initialize(GlobalKey<NavigatorState> navigationKey) async {
    if (_isInitialized) return;
    if (_isInitializing) {
      await _initializationCompleter.future;
      return;
    }

    _isInitializing = true;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _setupNotifications();
        await _setupFCMToken();
        _setupMessageHandlers();
        _isInitialized = true;
      }

      _initializationCompleter.complete();
    } catch (e) {
      _initializationCompleter.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<bool> checkPermissions() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }

  Future<String?> getFCMToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  Future<void> _setupNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    const AndroidNotificationChannel adminChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      enableVibration: true,
      showBadge: true,
      playSound: true,
      enableLights: true,
    );

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            json.decode(details.payload!);
          } catch (e) {
            return;
          }
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(adminChannel);
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  Future<void> _setupFCMToken() async {
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }
    _messaging.onTokenRefresh.listen(_saveFCMToken);
  }

  Future<void> _saveFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance.ref('users/${user.uid}').update({
        'fcmToken': token,
        'tokenLastUpdated': ServerValue.timestamp,
      });
    }
  }

  Future<String> downloadAndSaveImage(String url) async {
    try {
      final response = await dio.Dio()
          .get(url, options: dio.Options(responseType: dio.ResponseType.bytes));
      final directory = (await getApplicationDocumentsDirectory()).path;
      final filePath = '$directory/${url.split('/').last}';
      final File file = File(filePath);

      await file.writeAsBytes(response.data);
      return filePath;
    } catch (e) {
      debugPrint('Error downloading image: $e');
      return '';
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print("Received foreground message: ${message.data}");
    }

    final notification = message.notification;
    if (notification != null) {
      final imagePath =
          await downloadAndSaveImage(message.data['imageUrl'] ?? '');

      var androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath), // Use downloaded image path
          contentTitle: notification.title,
          summaryText: notification.body,
        ),
      );

      var notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: json.encode({
          'type': message.data['type'],
          'title': message.data['title'],
          'body': message.data['body'],
          'imageUrl': message.data['imageUrl'],
        }),
      );
    }
  }

  Future<String> _getAccessToken() async {
    final credentials = ServiceAccountCredentials.fromJson(_serviceAccount);
    final client = await clientViaServiceAccount(
      credentials,
      ['https://www.googleapis.com/auth/firebase.messaging'],
    );
    final accessToken = client.credentials.accessToken.data;
    client.close();
    return accessToken;
  }

  Future<void> sendNotificationToToken({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final accessToken = await _getAccessToken();

      final payload = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data,
          'android': {
            'notification': {
              'channel_id': 'high_importance_channel',
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(payload),
      );

      if (response.statusCode != 200) {
        throw 'FCM request failed with status: ${response.statusCode}, body: ${response.body}';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification: $e');
      }
      rethrow;
    }
  }
}

class FirebaseMessagingService {
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'pending_notification',
        json.encode({
          'type': 'chat_message',
          'chatId': message.data['chatId'],
          'senderId': message.data['senderId'],
          'senderName': message.data['senderName'],
          'messageData': message.data,
        }));
  }

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(backgroundHandler);
  }
}
