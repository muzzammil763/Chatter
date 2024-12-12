import 'dart:async';
import 'dart:convert';

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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_chatter_mobile/Screens/Chat/chat_screen.dart';
import 'package:web_chatter_mobile/Screens/Users/users_screen.dart';

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

  GlobalKey<NavigatorState>? _navigationKey;
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
      _navigationKey = navigationKey;
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
        await printFCMToken();
      }

      _initializationCompleter.complete();
    } catch (e) {
      _initializationCompleter.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> sendFeedbackResponseNotification({
    required String userId,
    required String response,
    required String feedbackId,
  }) async {
    try {
      final userSnapshot =
          await FirebaseDatabase.instance.ref('users/$userId/fcmToken').get();

      final fcmToken = userSnapshot.value as String?;
      if (fcmToken == null) return;

      await sendNotificationToToken(
        token: fcmToken,
        title: 'Feedback Response',
        body: 'Admin has responded to your feedback',
        data: {
          'type': 'feedback_response',
          'feedbackId': feedbackId,
          'response': response,
        },
      );
    } catch (e) {
      debugPrint('Error sending feedback response notification: $e');
    }
  }

  Future<void> printFCMToken() async {
    String? token = await _messaging.getToken();
    if (kDebugMode) {
      print('FCM Token: $token');
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

  // void _setupAppStateListener() {
  //   WidgetsBinding.instance.addObserver(
  //     _AppLifecycleObserver(
  //       onResume: () => _isAppInForeground = true,
  //       onPause: () => _isAppInForeground = false,
  //     ),
  //   );
  // }

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
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      enableVibration: true,
      showBadge: true,
      playSound: true,
    );

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(adminChannel);
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
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

  Future<void> sendChatMessage({
    required String recipientUserId,
    required String senderName,
    required String messageText,
    required String chatId,
  }) async {
    try {
      final tokenSnapshot = await FirebaseDatabase.instance
          .ref('users/$recipientUserId/fcmToken')
          .get();

      final fcmToken = tokenSnapshot.value as String?;
      if (fcmToken == null) return;

      await sendNotificationToToken(
        token: fcmToken,
        title: 'New message from $senderName',
        body: messageText,
        data: {
          'type': 'chat_message',
          'chatId': chatId,
          'senderId': FirebaseAuth.instance.currentUser?.uid,
          'senderName': senderName,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending chat notification: $e');
      }
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    await _handleNotificationNavigation(message.data);
  }

  Future<void> _handleNotificationTap(NotificationResponse response) async {
    if (response.payload == null) return;

    try {
      final data = json.decode(response.payload!);
      await _handleNotificationNavigation(data);
    } catch (e) {
      if (kDebugMode) {
        print('Error handling notification tap: $e');
      }
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print("Received foreground message: ${message.notification?.title}");
      print("Received foreground message: ${message.notification?.body}");
      print("Received foreground message: ${message.data}");
    }

    final notification = message.notification;
    if (notification != null) {
      var androidDetails = const AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      var notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
      );
    }
  }

  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    try {
      if (data['type'] == 'chat_message') {
        final senderId = data['senderId'];
        if (senderId == null || _navigationKey!.currentState == null) return;

        final senderSnapshot =
            await FirebaseDatabase.instance.ref('users/$senderId').get();
        if (!senderSnapshot.exists) return;

        final senderData =
            Map<String, dynamic>.from(senderSnapshot.value as Map);

        await _navigationKey!.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UsersScreen()),
          (route) => false,
        );

        await _navigationKey!.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              otherUser: senderData,
              otherUserId: senderId,
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in navigation: $e');
      }
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
              'channel_id': 'chat_messages',
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
