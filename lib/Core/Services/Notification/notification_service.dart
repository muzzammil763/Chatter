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
import 'package:web_chatter_mobile/Config/firebase_config.dart';
import 'package:web_chatter_mobile/Screens/Chat/chat_screen.dart';
import 'package:web_chatter_mobile/Screens/Users/users_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  static NotificationService? _instance;
  late final GlobalKey<NavigatorState> _navigationKey;
  bool _isAppInForeground = true;

  NotificationService._();

  factory NotificationService() {
    _instance ??= NotificationService._();
    return _instance!;
  }

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _fcmEndpoint =
      'https://fcm.googleapis.com/v1/projects/web-chatter-763/messages:send';

  Map<String, dynamic> get _serviceAccount => {
        "type": dotenv.env['SERVICE_ACCOUNT_TYPE'],
        "project_id": dotenv.env['SERVICE_ACCOUNT_PROJECT_ID'],
        "private_key_id": dotenv.env['SERVICE_ACCOUNT_PRIVATE_KEY_ID'],
        "private_key": dotenv.env['SERVICE_ACCOUNT_PRIVATE_KEY'],
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
    _navigationKey = navigationKey;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _requestPermissions();
    await _setupNotifications();
    await _setupFCMToken();
    _setupMessageHandlers();
    _setupAppStateListener();
  }

  void _setupAppStateListener() {
    WidgetsBinding.instance.addObserver(
      _AppLifecycleObserver(
        onResume: () => _isAppInForeground = true,
        onPause: () => _isAppInForeground = false,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
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

    const AndroidNotificationChannelGroup channelGroup =
        AndroidNotificationChannelGroup(
      'chat_messages_group',
      'Chat Messages',
      description: 'Group for chat message notifications',
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.max,
      enableVibration: true,
      showBadge: true,
      playSound: true,
      enableLights: true,
      groupId: 'chat_messages_group',
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
        ?.createNotificationChannelGroup(channelGroup);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
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

      await _sendNotificationToToken(
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
    if (!_isAppInForeground) {
      final notification = message.notification;
      if (notification != null) {
        var androidDetails = AndroidNotificationDetails(
          'chat_messages',
          'Chat Messages',
          channelDescription: 'Notifications for new chat messages',
          importance: Importance.max,
          priority: Priority.high,
          autoCancel: true,
          enableLights: true,
          colorized: true,
          color: const Color(0xff000000),
          channelShowBadge: true,
          groupKey: 'chat_messages_group',
          setAsGroupSummary: true,
          additionalFlags: Int32List.fromList(<int>[0x00002000]),
        );

        var notificationDetails = NotificationDetails(android: androidDetails);

        final payload = json.encode({
          'type': 'chat_message',
          'chatId': message.data['chatId'],
          'senderId': message.data['senderId'],
          'senderName': message.data['senderName'],
        });

        await _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          notificationDetails,
          payload: payload,
        );
      }
    }
  }

  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    try {
      if (data['type'] == 'chat_message') {
        final senderId = data['senderId'];
        if (senderId == null || _navigationKey.currentState == null) return;

        final senderSnapshot =
            await FirebaseDatabase.instance.ref('users/$senderId').get();
        if (!senderSnapshot.exists) return;

        final senderData =
            Map<String, dynamic>.from(senderSnapshot.value as Map);

        await _navigationKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UsersScreen()),
          (route) => false,
        );

        await _navigationKey.currentState!.push(
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

  Future<void> _sendNotificationToToken({
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

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;
  final VoidCallback onPause;

  _AppLifecycleObserver({
    required this.onResume,
    required this.onPause,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResume();
        break;
      case AppLifecycleState.paused:
        onPause();
        break;
      default:
        break;
    }
  }
}

class FirebaseMessagingService {
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: FirebaseConfig.defaultOptions,
    );

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

    if (kDebugMode) {
      print('Handling background message: ${message.messageId}');
    }
  }

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(backgroundHandler);
  }
}
